//
//  GameViewModel.swift
//  Hearts Scoreboard
//

import Foundation
import SwiftData

// MARK: - Data Model

struct Hand: Identifiable, Codable {
    let id = UUID()
    let values: [Int]           // One score entry per player, same index as playerNames
    let moonShooterIndex: Int?  // Set when a player shot the moon, nil otherwise

    // id is display-only (regenerated on decode); only game data goes to disk.
    private enum CodingKeys: String, CodingKey {
        case values, moonShooterIndex
    }
}

/// Everything belonging to a game in progress, frozen at startGame().
/// The setup screen edits draft state on GameViewModel; once a game starts,
/// nothing outside commitHand/updateHand can touch this snapshot — the home
/// screen's pickers configure the *next* game only.
struct ActiveGame: Codable {
    var playerCount: Int
    var playerNames: [String]
    var targetScore: Int
    var scores: [Int]
    var hands: [Hand]
    var isTieBreaker: Bool
    var selfPlayerIndex: Int?
}

// MARK: - View Model

class GameViewModel: ObservableObject {

    static let allowedPlayerCounts = [3, 4, 5, 6]
    static let defaultPlayerCount  = 4

    /// False for the tutorial's demo instance and previews, which must never
    /// write to UserDefaults or restore the real in-progress game.
    private let persistsState: Bool

    init(persistsState: Bool = true) {
        self.persistsState = persistsState
        if persistsState {
            game = Self.loadActiveGame()
        }
    }

    // Draft state — what the home screen edits for the NEXT game.
    @Published var playerCount: Int = GameViewModel.defaultPlayerCount {
        didSet { syncPlayerSlots() }
    }
    @Published var playerNames: [String] = GameViewModel.loadNames()
    @Published var targetScore: Int = GameViewModel.loadTargetScore()

    // The in-progress game, if any. Persisted to UserDefaults (device-local,
    // never CloudKit) on every mutation so a relaunch can resume it.
    @Published private(set) var game: ActiveGame? = nil {
        didSet { persistActiveGame() }
    }

    // Navigation / win state
    @Published var gameStarted    = false
    @Published var winner: String? = nil
    @Published var showWinAlert    = false

    var hasActiveGame: Bool { game != nil }

    // Self-player identity (set by PlayerSetupView via Game Center or manual tap)
    @Published var selfPlayerIndex: Int? = GameViewModel.loadSelfPlayerIndex() {
        didSet { saveSelfPlayerIndex() }
    }
    @Published var gameCenterPlayerID: String? = nil

    // MARK: Active-game accessors for ScoreboardView
    // Fallbacks cover the one render pass the scoreboard can make after
    // resetGame() clears the game but before it leaves the hierarchy.

    var gamePlayerCount: Int    { game?.playerCount ?? 0 }
    var gamePlayerNames: [String] { game?.playerNames ?? [] }
    var gameScores: [Int]       { game?.scores ?? [] }
    var gameTargetScore: Int    { game?.targetScore ?? 100 }
    var gameHands: [Hand]       { game?.hands ?? [] }
    var gameIsTieBreaker: Bool  { game?.isTieBreaker ?? false }

    // MARK: Actions

    /// Keeps the draft playerNames sized to the draft playerCount and drops a
    /// self designation that points at a removed seat. Draft-only — never
    /// touches the active game.
    private func syncPlayerSlots() {
        if playerNames.count > playerCount {
            playerNames = Array(playerNames.prefix(playerCount))
        } else if playerNames.count < playerCount {
            playerNames.append(contentsOf: Array(repeating: "", count: playerCount - playerNames.count))
        }
        if let selfIdx = selfPlayerIndex, selfIdx >= playerCount {
            selfPlayerIndex = nil
        }
    }

    func startGame() {
        playerNames = playerNames.map { $0.trimmingCharacters(in: .whitespaces) }
        game = ActiveGame(
            playerCount: playerCount,
            playerNames: playerNames,
            targetScore: targetScore,
            scores: Array(repeating: 0, count: playerCount),
            hands: [],
            isTieBreaker: false,
            selfPlayerIndex: selfPlayerIndex
        )
        winner       = nil
        showWinAlert = false
        gameStarted  = true
        savePreferences()
    }

    func goHome() {
        gameStarted = false
    }

    func resumeGame() {
        gameStarted = true
        // If the app was killed after the win threshold was crossed but before
        // the win alert was acted on, re-raise it now.
        checkWinCondition()
    }

    func commitHand(_ values: [Int], moonShooterIndex: Int? = nil) {
        guard var g = game, values.count == g.playerCount else { return }
        for i in 0..<g.playerCount {
            g.scores[i] += values[i]
        }
        g.hands.append(Hand(values: values, moonShooterIndex: moonShooterIndex))
        game = g
        checkWinCondition()
    }

    func updateHand(at index: Int, values: [Int], moonShooterIndex: Int? = nil) {
        guard var g = game, index < g.hands.count, values.count == g.playerCount else { return }
        g.hands[index] = Hand(values: values, moonShooterIndex: moonShooterIndex)
        g.scores = g.hands.reduce(Array(repeating: 0, count: g.playerCount)) { acc, hand in
            zip(acc, hand.values).map(+)
        }
        g.isTieBreaker = false
        game = g
        winner       = nil
        showWinAlert = false
        checkWinCondition()
    }

    func resetGame() {
        game          = nil
        winner        = nil
        showWinAlert  = false
        gameStarted   = false
        // Draft state (playerCount/names/target/selfPlayerIndex) is untouched —
        // it already describes the next game the user wants to set up.
    }

    // MARK: - Save to SwiftData

    @discardableResult
    func saveGame(context: ModelContext) -> SavedGame? {
        guard let g = game,
              let lowestScore = g.scores.min(),
              let winnerIdx   = g.scores.firstIndex(of: lowestScore) else { return nil }

        let saved = SavedGame()
        saved.date              = Date()
        saved.playerNames       = g.playerNames
        saved.finalScores       = g.scores
        saved.selfPlayerIndex   = g.selfPlayerIndex
        saved.gameCenterPlayerID = gameCenterPlayerID
        saved.winnerIndex       = winnerIdx
        // Assigned exactly once here and never regenerated — share-link dedupe
        // depends on this ID staying constant for the life of the record.
        saved.shareID           = UUID()

        var savedHands: [SavedHand] = []
        for (i, hand) in g.hands.enumerated() {
            let savedHand = SavedHand()
            savedHand.handNumber       = i
            savedHand.scores           = hand.values
            savedHand.isMoonShoot      = hand.moonShooterIndex != nil
            savedHand.moonShooterIndex = hand.moonShooterIndex
            savedHand.game             = saved
            savedHands.append(savedHand)
        }
        saved.hands = savedHands

        context.insert(saved)
        return saved
    }

    // MARK: - Persistence

    private static let namesKey           = "hearts.playerNames"
    private static let targetScoreKey     = "hearts.targetScore"
    private static let selfPlayerIndexKey = "hearts.selfPlayerIndex"
    private static let activeGameKey      = "hearts.activeGame"

    private func savePreferences() {
        guard persistsState else { return }
        UserDefaults.standard.set(playerNames, forKey: Self.namesKey)
        UserDefaults.standard.set(targetScore, forKey: Self.targetScoreKey)
    }

    private func saveSelfPlayerIndex() {
        guard persistsState else { return }
        // -1 sentinel = explicitly "no self designated"
        UserDefaults.standard.set(selfPlayerIndex ?? -1, forKey: Self.selfPlayerIndexKey)
    }

    private func persistActiveGame() {
        guard persistsState else { return }
        if let g = game, let data = try? JSONEncoder().encode(g) {
            UserDefaults.standard.set(data, forKey: Self.activeGameKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.activeGameKey)
        }
    }

    /// Restores an in-progress game from a previous launch. Structural checks
    /// guard against a corrupt or hand-edited blob — a game that fails them is
    /// dropped rather than allowed to desync scores from playerCount.
    private static func loadActiveGame() -> ActiveGame? {
        guard let data = UserDefaults.standard.data(forKey: activeGameKey),
              let g = try? JSONDecoder().decode(ActiveGame.self, from: data),
              allowedPlayerCounts.contains(g.playerCount),
              g.playerNames.count == g.playerCount,
              g.scores.count == g.playerCount,
              g.hands.allSatisfy({ $0.values.count == g.playerCount })
        else { return nil }
        return g
    }

    private static func loadNames() -> [String] {
        // The draft always opens at the default count (4), so saved names from
        // a 3/5/6-player game are padded or trimmed to fit the default slots.
        var saved = UserDefaults.standard.stringArray(forKey: namesKey) ?? []
        if saved.count > defaultPlayerCount {
            saved = Array(saved.prefix(defaultPlayerCount))
        } else if saved.count < defaultPlayerCount {
            saved.append(contentsOf: Array(repeating: "", count: defaultPlayerCount - saved.count))
        }
        return saved
    }

    private static func loadTargetScore() -> Int {
        let saved = UserDefaults.standard.integer(forKey: targetScoreKey)
        return [50, 75, 100].contains(saved) ? saved : 100
    }

    private static func loadSelfPlayerIndex() -> Int? {
        // Missing key = first launch → default to Player 1 (index 0)
        guard UserDefaults.standard.object(forKey: selfPlayerIndexKey) != nil else {
            return 0
        }
        let value = UserDefaults.standard.integer(forKey: selfPlayerIndexKey)
        // The draft always opens at the default player count, so a seat saved
        // from a 5/6-player game that no longer exists falls back to "not
        // designated".
        return (0..<defaultPlayerCount).contains(value) ? value : nil
    }

    // MARK: - Win Condition

    private func checkWinCondition() {
        guard var g = game else { return }
        guard g.scores.contains(where: { $0 >= g.targetScore }) else { return }

        let lowestScore  = g.scores.min()!
        let lowestCount  = g.scores.filter { $0 == lowestScore }.count

        // Tie — keep playing until one player stands alone at the bottom
        if lowestCount > 1 {
            if !g.isTieBreaker {
                g.isTieBreaker = true
                game = g
            }
            return
        }

        // Single lowest score — that player wins
        if g.isTieBreaker {
            g.isTieBreaker = false
            game = g
        }
        let winnerIndex = g.scores.firstIndex(of: lowestScore)!
        winner          = g.playerNames[winnerIndex]
        showWinAlert    = true
    }
}
