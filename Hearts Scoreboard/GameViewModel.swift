//
//  GameViewModel.swift
//  Hearts Scoreboard
//

import Foundation
import SwiftData

// MARK: - Data Model

struct Hand: Identifiable {
    let id = UUID()
    let values: [Int]           // One score entry per player, same index as playerNames
    let moonShooterIndex: Int?  // Set when a player shot the moon, nil otherwise
}

// MARK: - View Model

class GameViewModel: ObservableObject {

    // Player info
    @Published var playerNames: [String] = GameViewModel.loadNames()
    @Published var scores: [Int]         = [0, 0, 0, 0]

    // Hand history
    @Published var hands: [Hand] = []

    // Game settings
    @Published var targetScore: Int = GameViewModel.loadTargetScore()

    // Navigation / win state
    @Published var gameStarted    = false
    @Published var hasActiveGame  = false
    @Published var isTieBreaker   = false
    @Published var winner: String? = nil
    @Published var showWinAlert    = false

    // Self-player identity (set by PlayerSetupView via Game Center or manual tap)
    @Published var selfPlayerIndex: Int?    = nil
    @Published var gameCenterPlayerID: String? = nil

    // MARK: Actions

    func startGame() {
        playerNames  = playerNames.map { $0.trimmingCharacters(in: .whitespaces) }
        scores       = [0, 0, 0, 0]
        hands        = []
        winner       = nil
        showWinAlert = false
        isTieBreaker = false
        gameStarted  = true
        hasActiveGame = true
        savePreferences()
    }

    func goHome() {
        gameStarted = false
    }

    func resumeGame() {
        gameStarted = true
    }

    func commitHand(_ values: [Int], moonShooterIndex: Int? = nil) {
        guard values.count == 4 else { return }
        for i in 0..<4 {
            scores[i] += values[i]
        }
        hands.append(Hand(values: values, moonShooterIndex: moonShooterIndex))
        checkWinCondition()
    }

    func updateHand(at index: Int, values: [Int], moonShooterIndex: Int? = nil) {
        guard index < hands.count, values.count == 4 else { return }
        hands[index] = Hand(values: values, moonShooterIndex: moonShooterIndex)
        scores = hands.reduce([0, 0, 0, 0]) { acc, hand in
            zip(acc, hand.values).map(+)
        }
        winner       = nil
        showWinAlert = false
        isTieBreaker = false
        checkWinCondition()
    }

    func resetGame() {
        playerNames   = Self.loadNames()
        targetScore   = Self.loadTargetScore()
        scores        = [0, 0, 0, 0]
        hands         = []
        isTieBreaker  = false
        winner        = nil
        showWinAlert  = false
        gameStarted   = false
        hasActiveGame = false
        selfPlayerIndex = nil
    }

    // MARK: - Save to SwiftData

    func saveGame(context: ModelContext) {
        guard let lowestScore = scores.min(),
              let winnerIdx   = scores.firstIndex(of: lowestScore) else { return }

        let game = SavedGame()
        game.date              = Date()
        game.playerNames       = playerNames
        game.finalScores       = scores
        game.selfPlayerIndex   = selfPlayerIndex
        game.gameCenterPlayerID = gameCenterPlayerID
        game.winnerIndex       = winnerIdx

        var savedHands: [SavedHand] = []
        for (i, hand) in hands.enumerated() {
            let savedHand = SavedHand()
            savedHand.handNumber      = i
            savedHand.scores          = hand.values
            savedHand.isMoonShoot     = hand.moonShooterIndex != nil
            savedHand.moonShooterIndex = hand.moonShooterIndex
            savedHand.game            = game
            savedHands.append(savedHand)
        }
        game.hands = savedHands

        context.insert(game)
    }

    // MARK: - Persistence

    private static let namesKey       = "hearts.playerNames"
    private static let targetScoreKey = "hearts.targetScore"

    private func savePreferences() {
        UserDefaults.standard.set(playerNames, forKey: Self.namesKey)
        UserDefaults.standard.set(targetScore, forKey: Self.targetScoreKey)
    }

    private static func loadNames() -> [String] {
        let saved = UserDefaults.standard.stringArray(forKey: namesKey) ?? []
        return saved.count == 4 ? saved : ["", "", "", ""]
    }

    private static func loadTargetScore() -> Int {
        let saved = UserDefaults.standard.integer(forKey: targetScoreKey)
        return [50, 75, 100].contains(saved) ? saved : 100
    }

    // MARK: - Win Condition

    private func checkWinCondition() {
        guard scores.contains(where: { $0 >= targetScore }) else { return }

        let lowestScore  = scores.min()!
        let lowestCount  = scores.filter { $0 == lowestScore }.count

        // Tie — keep playing until one player stands alone at the bottom
        if lowestCount > 1 {
            isTieBreaker = true
            return
        }

        // Single lowest score — that player wins
        isTieBreaker             = false
        let winnerIndex          = scores.firstIndex(of: lowestScore)!
        winner                   = playerNames[winnerIndex]
        showWinAlert             = true
    }
}
