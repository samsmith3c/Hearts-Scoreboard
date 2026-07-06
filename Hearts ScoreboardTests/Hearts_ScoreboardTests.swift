//
//  Hearts_ScoreboardTests.swift
//  Hearts ScoreboardTests
//

import XCTest
@testable import Hearts_Scoreboard

final class Hearts_ScoreboardTests: XCTestCase {

    // Tests run inside the app host, so UserDefaults.standard is the app's.
    // Snapshot and restore every key the view model touches.
    private let managedKeys = [
        "hearts.playerNames", "hearts.targetScore",
        "hearts.selfPlayerIndex", "hearts.activeGame",
    ]
    private var savedDefaults: [String: Any] = [:]

    override func setUpWithError() throws {
        savedDefaults = [:]
        for key in managedKeys {
            savedDefaults[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDownWithError() throws {
        for key in managedKeys {
            if let value = savedDefaults[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    private func makeStartedGame(players: [String] = ["A", "B", "C", "D"],
                                 target: Int = 100,
                                 persists: Bool = false) -> GameViewModel {
        let vm = GameViewModel(persistsState: persists)
        vm.playerCount = players.count
        vm.playerNames = players
        vm.targetScore = target
        vm.startGame()
        return vm
    }

    // MARK: - Active-game lock (the resume-after-count-change crash)

    func testDraftChangesCannotTouchActiveGame() {
        let vm = makeStartedGame()
        vm.commitHand([5, 9, 8, 4])

        // The exact sequence that used to crash: go home, move the pickers.
        vm.goHome()
        vm.playerCount = 6
        vm.targetScore = 50
        vm.resumeGame()

        XCTAssertEqual(vm.gamePlayerCount, 4)
        XCTAssertEqual(vm.gameTargetScore, 100)
        XCTAssertEqual(vm.gameScores, [5, 9, 8, 4])
        // The invariant whose violation crashed the header render:
        XCTAssertEqual(vm.gameScores.count, vm.gamePlayerCount)
        XCTAssertEqual(vm.gamePlayerNames.count, vm.gamePlayerCount)

        // Hands still commit and edit against the frozen count.
        vm.commitHand([0, 0, 0, 26])
        XCTAssertEqual(vm.gameScores, [5, 9, 8, 30])
        vm.updateHand(at: 1, values: [1, 2, 3, 20])
        XCTAssertEqual(vm.gameScores, [6, 11, 11, 24])
    }

    func testDraftShrinkPreservesLargerActiveGame() {
        let vm = makeStartedGame(players: ["A", "B", "C", "D", "E", "F"])
        vm.commitHand([26, 0, 0, 0, 0, 0])
        vm.goHome()
        vm.playerCount = 3
        vm.resumeGame()

        XCTAssertEqual(vm.gamePlayerCount, 6)
        XCTAssertEqual(vm.gameScores, [26, 0, 0, 0, 0, 0])
        // A 3-value commit must be rejected, a 6-value one accepted.
        vm.commitHand([1, 2, 23])
        XCTAssertEqual(vm.gameHands.count, 1)
        vm.commitHand([1, 2, 3, 4, 5, 11])
        XCTAssertEqual(vm.gameHands.count, 2)
    }

    // MARK: - Persistence across relaunch

    func testActiveGameSurvivesRelaunch() {
        let vm1 = makeStartedGame(target: 75, persists: true)
        vm1.commitHand([5, 9, 8, 4])
        vm1.commitHand([0, 26, 26, 26])

        // A new view model = a fresh app launch.
        let vm2 = GameViewModel(persistsState: true)
        XCTAssertTrue(vm2.hasActiveGame)
        XCTAssertFalse(vm2.gameStarted, "relaunch lands on the home screen with Resume")
        XCTAssertEqual(vm2.gamePlayerCount, 4)
        XCTAssertEqual(vm2.gameTargetScore, 75)
        XCTAssertEqual(vm2.gameScores, [5, 35, 34, 30])
        XCTAssertEqual(vm2.gameHands.count, 2)
        XCTAssertNil(vm2.gameHands[0].moonShooterIndex)

        vm2.resetGame()
        let vm3 = GameViewModel(persistsState: true)
        XCTAssertFalse(vm3.hasActiveGame, "reset clears the persisted game")
    }

    func testNonPersistingViewModelWritesNothing() {
        let vm = makeStartedGame(persists: false)
        vm.commitHand([5, 9, 8, 4])
        for key in managedKeys {
            XCTAssertNil(UserDefaults.standard.object(forKey: key),
                         "demo/preview view model leaked \(key) to UserDefaults")
        }
    }

    func testCorruptOrInvalidPersistedGameIsDropped() {
        // Garbage bytes
        UserDefaults.standard.set(Data([0x00, 0x01, 0x02]), forKey: "hearts.activeGame")
        XCTAssertFalse(GameViewModel(persistsState: true).hasActiveGame)

        // Structurally broken: scores desynced from playerCount — exactly the
        // shape that used to crash the scoreboard header.
        let broken = ActiveGame(playerCount: 6, playerNames: ["A", "B", "C", "D", "E", "F"],
                                targetScore: 100, scores: [0, 0, 0, 0],
                                hands: [], isTieBreaker: false, selfPlayerIndex: nil)
        UserDefaults.standard.set(try! JSONEncoder().encode(broken), forKey: "hearts.activeGame")
        XCTAssertFalse(GameViewModel(persistsState: true).hasActiveGame)
    }

    // MARK: - Win condition / tie-breaker (unchanged logic, regression net)

    func testTieBreakerThenWin() {
        let vm = makeStartedGame(target: 50)
        vm.commitHand([25, 25, 26, 26])
        vm.commitHand([25, 25, 0, 26])   // A=50 B=50 C=26 D=52 → C unique lowest, wins
        XCTAssertFalse(vm.gameIsTieBreaker)
        XCTAssertEqual(vm.winner, "C")

        let vm2 = makeStartedGame(target: 50)
        vm2.commitHand([25, 25, 26, 26]) // A=25 B=25 tie at bottom, D over 50? no — nobody ≥50 yet
        XCTAssertFalse(vm2.gameIsTieBreaker)
        vm2.commitHand([25, 25, 26, 26]) // A=50 B=50 C=52 D=52 — threshold crossed, bottom tied
        XCTAssertTrue(vm2.gameIsTieBreaker)
        XCTAssertNil(vm2.winner)
        vm2.commitHand([0, 26, 0, 0])    // A=50 B=76 → A unique lowest
        XCTAssertFalse(vm2.gameIsTieBreaker)
        XCTAssertEqual(vm2.winner, "A")
        XCTAssertTrue(vm2.showWinAlert)
    }

    func testResumeReRaisesPendingWinAlert() {
        let vm1 = makeStartedGame(target: 50, persists: true)
        vm1.commitHand([50, 0, 10, 20])  // B wins immediately
        XCTAssertTrue(vm1.showWinAlert)

        // Relaunch before the alert was acted on, then resume.
        let vm2 = GameViewModel(persistsState: true)
        XCTAssertFalse(vm2.showWinAlert)
        vm2.resumeGame()
        XCTAssertTrue(vm2.showWinAlert)
        XCTAssertEqual(vm2.winner, "B")
    }

    // MARK: - SharePayload validation

    private func makePayload() -> SharePayload {
        let game = SavedGame(
            playerNames: ["A", "B", "C", "D"],
            finalScores: [10, 20, 30, 40],
            winnerIndex: 0,
            shareID: UUID()
        )
        return SharePayload(game: game)!
    }

    private func roundTrip(_ payload: SharePayload) -> SharePayload? {
        guard let encoded = payload.encodedString() else { return nil }
        return SharePayload(encodedString: encoded)
    }

    func testValidPayloadRoundTrips() {
        var payload = makePayload()
        payload.h = [[5, 9, 8, 4], [0, 26, 26, 26, 0]]  // second hand: moon, shooter 0
        XCTAssertNotNil(roundTrip(payload))
    }

    func testRejectsOutOfRangeWinnerIndex() {
        var payload = makePayload()
        payload.w = 4
        XCTAssertNil(roundTrip(payload))
        payload.w = -1
        XCTAssertNil(roundTrip(payload))
    }

    func testRejectsOutOfRangeMoonShooterIndex() {
        var payload = makePayload()
        payload.h = [[0, 26, 26, 26, 7]]
        XCTAssertNil(roundTrip(payload))
        payload.h = [[0, 26, 26, 26, 3]]
        XCTAssertNotNil(roundTrip(payload))
    }

    func testRejectsNegativeScores() {
        var payload = makePayload()
        payload.s = [10, 20, -5, 40]
        XCTAssertNil(roundTrip(payload))

        payload = makePayload()
        payload.h = [[-1, 27, 0, 0]]
        XCTAssertNil(roundTrip(payload))
    }
}
