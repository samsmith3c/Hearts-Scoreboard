//
//  Hearts_ScoreboardApp.swift
//  Hearts Scoreboard
//

import SwiftUI
import SwiftData

@main
struct Hearts_ScoreboardApp: App {
    let container: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.github.samsmith3c.Hearts-Scoreboard")
            )
            container = try ModelContainer(for: SavedGame.self, configurations: config)
        } catch {
            print("⚠️ CloudKit ModelContainer failed: \(error)")
            print("⚠️ Detailed: \(String(reflecting: error))")
            // Fall back to a local-only store so the app still launches.
            do {
                let localConfig = ModelConfiguration(isStoredInMemoryOnly: false)
                container = try ModelContainer(for: SavedGame.self, configurations: localConfig)
                print("ℹ️ Using local-only store (no iCloud sync)")
            } catch {
                fatalError("Failed to create local ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
