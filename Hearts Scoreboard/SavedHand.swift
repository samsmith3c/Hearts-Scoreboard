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
}
