//
//  ContentView.swift
//  Hearts Scoreboard
//
//  Created by Sammy Smith on 5/8/26.
//

import SwiftUI
import SwiftData

// MARK: - App Entry Point

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext

    @State private var incomingGame: SavedGame? = nil
    @State private var incomingMode: GameDetailMode = .incomingShare

    var body: some View {
        Group {
            if viewModel.gameStarted {
                ScoreboardView(viewModel: viewModel)
            } else {
                PlayerSetupView(viewModel: viewModel)
            }
        }
        .environment(
            \.dynamicTypeSize,
            UIDevice.current.userInterfaceIdiom == .pad
                ? dynamicTypeSize.stepped(by: 2)
                : dynamicTypeSize
        )
        .onOpenURL { handleIncomingURL($0) }
        .fullScreenCover(item: $incomingGame) { game in
            GameDetailView(game: game, mode: incomingMode)
        }
    }

    /// Handles an incoming recap Universal Link. If a game with the same
    /// shareID is already saved (the link was opened before, or you were the
    /// sharer), open that record directly instead of re-importing — this is
    /// the duplicate-link protection. Otherwise run the claim flow on a
    /// not-yet-persisted copy; it is only inserted if the recipient claims a
    /// player and taps Done.
    private func handleIncomingURL(_ url: URL) {
        guard let payload = SharePayload(url: url),
              let uuid = UUID(uuidString: payload.id) else { return }

        var descriptor = FetchDescriptor<SavedGame>(
            predicate: #Predicate { $0.shareID == uuid }
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            incomingMode = .ownHistory
            incomingGame = existing
        } else {
            incomingMode = .incomingShare
            incomingGame = payload.makeSavedGame()
        }
    }
}

// What's next:
// - Step 14: end-to-end test — simulator `xcrun simctl openurl` with a real
//   share link to exercise both the new-game and duplicate paths.

// MARK: - DynamicTypeSize Helpers

extension DynamicTypeSize {
    func stepped(by steps: Int) -> DynamicTypeSize {
        let ladder: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
            .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5
        ]
        guard let index = ladder.firstIndex(of: self) else { return self }
        return ladder[min(index + steps, ladder.count - 1)]
    }
}

// MARK: - Color Helpers

/// Felt green card-table background used throughout the app.
let feltGreen = Color(hex: "2D5A27")

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
