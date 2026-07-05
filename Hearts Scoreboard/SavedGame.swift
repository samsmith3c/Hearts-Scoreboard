//
//  SavedGame.swift
//  Hearts Scoreboard
//

import Foundation
import SwiftData

@Model
class SavedGame {
    var date: Date = Date()
    var playerNames: [String] = []
    var finalScores: [Int] = []
    var selfPlayerIndex: Int? = nil
    var gameCenterPlayerID: String? = nil
    /// Index of the player with the lowest cumulative score when the game ended.
    var winnerIndex: Int = 0
    /// Stable identity for share links, assigned once when the game is saved
    /// (or lazily on first share for pre-v1.3 games) and never regenerated —
    /// dedupe on the receiving end relies on it staying constant.
    /// Optional because CloudKit requires new fields to be optional or defaulted.
    var shareID: UUID? = nil
    @Relationship(deleteRule: .cascade, inverse: \SavedHand.game) var hands: [SavedHand]? = nil

    init(
        date: Date = Date(),
        playerNames: [String] = [],
        finalScores: [Int] = [],
        selfPlayerIndex: Int? = nil,
        gameCenterPlayerID: String? = nil,
        winnerIndex: Int = 0,
        shareID: UUID? = nil,
        hands: [SavedHand]? = nil
    ) {
        self.date = date
        self.playerNames = playerNames
        self.finalScores = finalScores
        self.selfPlayerIndex = selfPlayerIndex
        self.gameCenterPlayerID = gameCenterPlayerID
        self.winnerIndex = winnerIndex
        self.shareID = shareID
        self.hands = hands
    }
}

// What's next:
// - Assign shareID = UUID() in GameViewModel.saveGame() (step 1, same commit).
// - Lazy backfill for pre-v1.3 games happens at first share (step 10).
// - This is a CloudKit schema change: run a dev build, then promote
//   Development → Production in the CloudKit Dashboard (plan step 13).
