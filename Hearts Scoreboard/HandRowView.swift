//
//  HandRowView.swift
//  Hearts Scoreboard
//

import SwiftUI

/// A single committed (non-editable) hand row displayed in the scoreboard history.
struct HandRowView: View {
    let hand: [Int]
    let buttonColumnWidth: CGFloat
    let passDirection: String
    let moonShooterIndex: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { i in
                Group {
                    if i == moonShooterIndex {
                        Text("🌙")
                    } else {
                        Text("\(hand[i])")
                            .foregroundColor(.white.opacity(0.78))
                    }
                }
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            Text(passDirection)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.35))
                .frame(width: buttonColumnWidth)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
}

#Preview {
    ZStack {
        feltGreen
        HandRowView(hand: [0, 26, 26, 26], buttonColumnWidth: 44, passDirection: "Left", moonShooterIndex: 0)
    }
}
