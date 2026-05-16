//
//  StatsView.swift
//  Hearts Scoreboard
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedGame.date, order: .reverse) private var games: [SavedGame]

    private var allStats: [PlayerStats] {
        StatsViewModel().computeStats(games: games)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                feltGreen.ignoresSafeArea()

                if games.isEmpty {
                    emptyState
                } else {
                    playerList
                }
            }
            .navigationTitle("Lifetime Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 52))
                .foregroundColor(.white.opacity(0.35))
            Text("No games yet")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
            Text("Finish a game to see lifetime stats here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Player list

    private var playerList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(allStats) { stats in
                    PlayerStatsCard(stats: stats)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Per-player card

struct PlayerStatsCard: View {
    let stats: PlayerStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Text(stats.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if stats.gcPlayerID != nil {
                    Label("iCloud", systemImage: "person.badge.shield.checkmark.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.45))
                        .labelStyle(.iconOnly)
                }
            }

            Divider().background(Color.white.opacity(0.18))

            // Stats grid
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 10
            ) {
                statCell("Games", "\(stats.gamesPlayed)")
                statCell("W – L", "\(stats.wins) – \(stats.losses)")
                if let pct = stats.winPercentage {
                    statCell("Win %", String(format: "%.0f%%", pct))
                }
                statCell("Total Pts", "\(stats.totalPoints)")
                if let low = stats.lowestSingleGameScore {
                    statCell("Best Game", "\(low) pts")
                }
                if let avg = stats.averageScorePerGame {
                    statCell("Avg/Game", String(format: "%.1f", avg))
                }
                if let avg = stats.averageScorePerHand {
                    statCell("Avg/Hand", String(format: "%.1f", avg))
                }
                statCell("🌙 Shoots", "\(stats.moonShootCount)")
                if stats.mostMoonsInSingleGame > 1 {
                    statCell("Most/Game", "\(stats.mostMoonsInSingleGame)")
                }
                statCell("Finished Last", "\(stats.timesFinishedLast)×")
            }

            // Streaks
            Divider().background(Color.white.opacity(0.18))

            HStack(spacing: 20) {
                if stats.currentStreakCount > 0 {
                    streakBadge(
                        label: "Current",
                        value: (stats.currentStreakIsWin ? "W" : "L") + "\(stats.currentStreakCount)",
                        color: stats.currentStreakIsWin ? Color(hex: "4CD964") : Color(hex: "FF6B6B")
                    )
                }
                streakBadge(label: "Win Streak", value: "W\(stats.longestWinStreak)", color: Color(hex: "4CD964"))
                streakBadge(label: "Loss Streak", value: "L\(stats.longestLosingStreak)", color: Color(hex: "FF6B6B"))
                Spacer()
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func streakBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
        }
    }
}

// MARK: - Navigation bar tint helper

private struct NavigationBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Color(hex: "2D5A27"))
                appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
    }
}

private extension View {
    func navigationBarBackground() -> some View {
        modifier(NavigationBarBackground())
    }
}

#Preview {
    StatsView()
}
