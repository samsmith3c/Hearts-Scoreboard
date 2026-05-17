//
//  SavedHand.swift
//  Hearts Scoreboard
//

import Foundation
import SwiftData

@Model
class SavedHand {
    var handNumber: Int = 0
    var scores: [Int] = []
    /// Explicitly set at commit time — never inferred from score values after the fact.
    var isMoonShoot: Bool = false
    var moonShooterIndex: Int? = nil
    var game: SavedGame? = nil

    init(
        handNumber: Int = 0,
        scores: [Int] = [],
        isMoonShoot: Bool = false,
        moonShooterIndex: Int? = nil,
        game: SavedGame? = nil
    ) {
        self.handNumber = handNumber
        self.scores = scores
        self.isMoonShoot = isMoonShoot
        self.moonShooterIndex = moonShooterIndex
        self.game = game
    }
}
