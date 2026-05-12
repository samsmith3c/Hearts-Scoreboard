//
//  ContentView.swift
//  Hearts Scoreboard
//
//  Created by Sammy Smith on 5/8/26.
//

import SwiftUI

// MARK: - App Entry Point

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    }
}

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
