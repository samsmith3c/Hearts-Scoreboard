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
    @Relationship(deleteRule: .cascade) var hands: [SavedHand] = []
}
