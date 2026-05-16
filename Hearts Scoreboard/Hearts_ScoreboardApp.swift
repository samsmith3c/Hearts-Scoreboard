//
//  Hearts_ScoreboardApp.swift
//  Hearts Scoreboard
//

import SwiftUI
import SwiftData

@main
struct Hearts_ScoreboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: SavedGame.self,
            inMemory: false,
            isAutosaveEnabled: true,
            isUndoEnabled: false,
            cloudKitDatabase: .private("iCloud.com.github.samsmith3c.Hearts-Scoreboard")
        )
    }
}
