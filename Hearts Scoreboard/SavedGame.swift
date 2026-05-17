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
    @Relationship(deleteRule: .cascade, inverse: \SavedHand.game) var hands: [SavedHand]? = nil

    init(
        date: Date = Date(),
        playerNames: [String] = [],
        finalScores: [Int] = [],
        selfPlayerIndex: Int? = nil,
        gameCenterPlayerID: String? = nil,
        winnerIndex: Int = 0,
        hands: [SavedHand]? = nil
    ) {
        self.date = date
        self.playerNames = playerNames
        self.finalScores = finalScores
        self.selfPlayerIndex = selfPlayerIndex
        self.gameCenterPlayerID = gameCenterPlayerID
        self.winnerIndex = winnerIndex
        self.hands = hands
    }
}
