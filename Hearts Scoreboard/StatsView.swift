//
//  StatsView.swift
//  Hearts Scoreboard
//

import SwiftUI
import SwiftData
import GameKit

struct StatsView: View {
    enum Tab: Hashable { case stats, games }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedGame.date, order: .reverse) private var games: [SavedGame]

    @State private var gcPlayerID: String? = GKLocalPlayer.local.isAuthenticated
        ? GKLocalPlayer.local.playerID
        : nil
    @State private var selectedTab: Tab = .stats
    @State private var pendingDelete: SavedGame? = nil
    @State private var selectedGame: SavedGame? = nil

    private var myStats: PlayerStats? {
        guard let id = gcPlayerID else { return nil }
        return StatsViewModel()
            .computeStats(games: games)
            .first { $0.gcPlayerID == id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                feltGreen.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabPicker

                    if selectedTab == .stats {
                        statsTabContent
                    } else {
                        gamesTabContent
                    }
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
            .onAppear { ensureGameCenterAuth() }
            .alert("Delete this game?", isPresented: deleteAlertBinding, presenting: pendingDelete) { game in
                Button("Delete", role: .destructive) {
                    modelContext.delete(game)
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { _ in
                Text("This game will be removed from your history and stats. This can't be undone.")
            }
            .fullScreenCover(item: $selectedGame) { game in
                GameDetailView(game: game)
                    .incomingShareHost()
            }
            .incomingShareHost()
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            Text("Stats").tag(Tab.stats)
            Text("Games").tag(Tab.games)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Stats tab

    @ViewBuilder
    private var statsTabContent: some View {
        if gcPlayerID == nil {
            notAuthenticatedState
        } else if let stats = myStats {
            statsContent(stats)
        } else {
            noGamesState
        }
    }

    // MARK: - Games tab

    @ViewBuilder
    private var gamesTabContent: some View {
        if games.isEmpty {
            noGamesState
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(games) { game in
                        GameHistoryCard(
                            game: game,
                            onTap: { selectedGame = game },
                            onDelete: { pendingDelete = game }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func ensureGameCenterAuth() {
        if GKLocalPlayer.local.isAuthenticated {
            gcPlayerID = GKLocalPlayer.local.playerID
            return
        }
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            DispatchQueue.main.async {
                if GKLocalPlayer.local.isAuthenticated {
                    self.gcPlayerID = GKLocalPlayer.local.playerID
                }
            }
        }
    }

    // MARK: - Empty states

    private var noGamesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 52))
                .foregroundColor(.white.opacity(0.35))
            Text("No games yet")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
            Text("Finish a game with yourself marked (person icon) to see your stats here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }

    private var notAuthenticatedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundColor(.white.opacity(0.35))
            Text("Sign in to Game Center")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
            Text("Stats are tracked using your Game Center identity so they follow you across devices.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }

    // MARK: - Stats content

    private func statsContent(_ stats: PlayerStats) -> some View {
        StatsDetailView(stats: stats, displayName: GKLocalPlayer.local.displayName)
    }
}

// MARK: - Full-screen stats layout

struct StatsDetailView: View {
    let stats: PlayerStats
    var displayName: String? = nil

    private let winGreen = Color(hex: "4CD964")
    private let lossRed  = Color(hex: "FF6B6B")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Name
                Text(displayName ?? stats.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Streaks — most prominent, at the top
                streaksSection

                // Games
                section(title: "Games") {
                    statRow("Games Played", "\(stats.gamesPlayed)")
                    statRow("Wins", "\(stats.wins)")
                    statRow("Losses", "\(stats.losses)")
                    if let pct = stats.winPercentage {
                        statRow("Win Percentage", String(format: "%.0f%%", pct))
                    }
                }

                // Scoring
                section(title: "Scoring") {
                    statRow("Total Points", "\(stats.totalPoints)")
                    if let low = stats.lowestSingleGameScore {
                        statRow("Best Game", "\(low) pts")
                    }
                    if let avg = stats.averageScorePerGame {
                        statRow("Avg per Game", String(format: "%.1f", avg))
                    }
                    if let avg = stats.averageScorePerHand {
                        statRow("Avg per Hand", String(format: "%.1f", avg))
                    }
                }

                // Moon shoots
                section(title: "Moon Shoots") {
                    statRow("Total Shoots", "\(stats.moonShootCount)")
                    if stats.mostMoonsInSingleGame > 0 {
                        statRow("Most in a Single Game", "\(stats.mostMoonsInSingleGame)")
                    }
                }

                // Other
                section(title: "Other") {
                    statRow("Finished Last", stats.timesFinishedLast == 1 ? "1 time" : "\(stats.timesFinishedLast) times")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Streaks

    private var streaksSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                streakTile(
                    title: "Current Streak",
                    value: streakValue(count: stats.currentStreakCount, isWin: stats.currentStreakIsWin),
                    color: stats.currentStreakCount == 0
                        ? .white.opacity(0.5)
                        : (stats.currentStreakIsWin ? winGreen : lossRed)
                )
                streakTile(
                    title: "Longest Win",
                    value: "\(stats.longestWinStreak)",
                    color: stats.longestWinStreak > 0 ? winGreen : .white.opacity(0.5)
                )
                streakTile(
                    title: "Longest Loss",
                    value: "\(stats.longestLosingStreak)",
                    color: stats.longestLosingStreak > 0 ? lossRed : .white.opacity(0.5)
                )
            }
        }
    }

    private func streakValue(count: Int, isWin: Bool) -> String {
        guard count > 0 else { return "—" }
        return "\(isWin ? "W" : "L")\(count)"
    }

    private func streakTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Sections + rows

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.leading, 16)
        }
    }
}

// MARK: - Game history card (Games tab)

struct GameHistoryCard: View {
    let game: SavedGame
    let onTap: () -> Void
    let onDelete: () -> Void

    private static let previewHandLimit = 5

    private var sortedHands: [SavedHand] {
        (game.hands ?? []).sorted { $0.handNumber < $1.handNumber }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {

                // Header — date + trash
                HStack {
                    Text(game.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.leading, 8)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .tutorialAnchor(.gameCardDelete)
                }

                Divider().background(Color.white.opacity(0.18))

                // Player names + final scores
                HStack(spacing: 4) {
                    ForEach(0..<game.playerNames.count, id: \.self) { i in
                        VStack(spacing: 2) {
                            Text(game.playerNames[i])
                                .font(.caption)
                                .fontWeight(i == game.winnerIndex ? .bold : .regular)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text("\(game.finalScores.indices.contains(i) ? game.finalScores[i] : 0)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(i == game.winnerIndex ? Color(hex: "4CD964") : .white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                if !sortedHands.isEmpty {
                    Divider().background(Color.white.opacity(0.18))

                    // Hand-by-hand mini grid (capped)
                    let preview = Array(sortedHands.prefix(Self.previewHandLimit))
                    let overflow = sortedHands.count - preview.count

                    VStack(spacing: 3) {
                        ForEach(preview) { hand in
                            HandPreviewRow(hand: hand, showsHandNumber: false)
                        }
                        if overflow > 0 {
                            Text("+\(overflow) more hand\(overflow == 1 ? "" : "s") — tap to view")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - One row of a hand-by-hand grid (shared between preview + detail)

struct HandPreviewRow: View {
    let hand: SavedHand
    var showsHandNumber: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if showsHandNumber {
                Text("\(hand.handNumber + 1)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 22, alignment: .leading)
            }
            ForEach(0..<hand.scores.count, id: \.self) { i in
                Group {
                    if hand.isMoonShoot && hand.moonShooterIndex == i {
                        Text("🌙")
                    } else {
                        Text("\(hand.scores[i])")
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Game detail (full-screen view of one game)

/// How GameDetailView was reached, which changes what Done means.
enum GameDetailMode {
    /// A game already in your history. Done just dismisses; claim edits
    /// persist directly on the record.
    case ownHistory
    /// A game decoded from an incoming share link, not yet persisted.
    /// Done with a claimed player inserts it into history (counting toward
    /// stats); Done unclaimed confirms discarding it entirely.
    case incomingShare
}

struct GameDetailView: View {
    let game: SavedGame
    var mode: GameDetailMode = .ownHistory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDiscardConfirm = false

    private var sortedHands: [SavedHand] {
        (game.hands ?? []).sorted { $0.handNumber < $1.handNumber }
    }

    private func doneTapped() {
        switch mode {
        case .ownHistory:
            dismiss()
        case .incomingShare:
            if game.selfPlayerIndex != nil {
                modelContext.insert(game)
                dismiss()
            } else {
                showDiscardConfirm = true
            }
        }
    }

    /// Pre-v1.3 games have no shareID; assign one the first time the game is
    /// opened for sharing. Once set it is never regenerated (dedupe key).
    private func backfillShareIDIfNeeded() {
        if mode == .ownHistory && game.shareID == nil {
            game.shareID = UUID()
        }
    }

    private func setSelf(to index: Int?) {
        if game.selfPlayerIndex == index {
            // Tapping the already-marked icon clears it
            game.selfPlayerIndex = nil
            game.gameCenterPlayerID = nil
        } else {
            game.selfPlayerIndex = index
            game.gameCenterPlayerID = GKLocalPlayer.local.isAuthenticated
                ? GKLocalPlayer.local.playerID
                : nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                feltGreen.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        Text(game.date.formatted(date: .complete, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Final scores header
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Text("")
                                    .frame(width: 22)
                                ForEach(0..<game.playerNames.count, id: \.self) { i in
                                    VStack(spacing: 4) {
                                        Button {
                                            setSelf(to: i)
                                        } label: {
                                            Image(systemName: game.selfPlayerIndex == i ? "person.fill" : "person")
                                                .font(.subheadline)
                                                .foregroundColor(
                                                    game.selfPlayerIndex == i
                                                        ? .white
                                                        : .white.opacity(0.45)
                                                )
                                                .animation(.easeInOut(duration: 0.15), value: game.selfPlayerIndex)
                                        }
                                        .buttonStyle(.plain)

                                        Text(game.playerNames[i])
                                            .font(.subheadline)
                                            .fontWeight(i == game.winnerIndex ? .bold : .regular)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                        Text("\(game.finalScores.indices.contains(i) ? game.finalScores[i] : 0)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(i == game.winnerIndex ? Color(hex: "4CD964") : .white)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.10))
                        .cornerRadius(10)

                        // All hands
                        if sortedHands.isEmpty {
                            Text("No hands recorded.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 20)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(sortedHands) { hand in
                                    HandPreviewRow(hand: hand)
                                        .padding(.vertical, 4)
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 1)
                                }
                            }
                            .padding(.horizontal, 6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarBackground()
            .toolbar {
                if mode == .ownHistory,
                   let shareURL = SharePayload(game: game)?.shareURL() {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ShareLink(item: shareURL) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { doneTapped() }
                        .foregroundColor(.white)
                }
            }
            .onAppear { backfillShareIDIfNeeded() }
            .alert(
                "Are you sure you don't want to save this game's results?",
                isPresented: $showDiscardConfirm
            ) {
                Button("Don't Save", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please select which player you were.")
            }
        }
        // A swipe-down would silently discard an incoming game; force the
        // Done path so the discard confirmation can run.
        .interactiveDismissDisabled(mode == .incomingShare)
    }
}

// What's next:
// - SharePayload + share-service: variable-count wire format so 3/5/6-player
//   games survive the round trip (share-service redeploys on merge to main).

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
