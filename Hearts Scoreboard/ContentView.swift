//
//  ContentView.swift
//  Hearts Scoreboard
//
//  Created by Sammy Smith on 5/8/26.
//

import SwiftUI
import SwiftData
import GameKit

// MARK: - Game Center authentication (single owner)

/// The ONLY place `GKLocalPlayer.authenticateHandler` is assigned. GameKit
/// keeps exactly one handler — when PlayerSetupView and StatsView each set
/// their own, whichever ran last silently disconnected the other, and games
/// could be saved without a Game Center ID (invisible to lifetime stats).
/// Views read the published identity instead of talking to GameKit.
@MainActor
final class GameCenterService: ObservableObject {
    @Published private(set) var playerID: String? = nil
    @Published private(set) var displayName: String? = nil

    private var started = false

    func authenticate() {
        guard !started else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] _, _ in
            DispatchQueue.main.async {
                guard GKLocalPlayer.local.isAuthenticated else { return }
                self?.playerID = GKLocalPlayer.local.playerID
                self?.displayName = GKLocalPlayer.local.displayName
            }
        }
    }
}

// MARK: - App Entry Point

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @StateObject private var shareRouter = ShareRouter()
    @StateObject private var tutorial = TutorialManager()
    @StateObject private var gameCenter = GameCenterService()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext

    /// Why an incoming recap link couldn't be opened — drives the error alert.
    private enum LinkError {
        case unreadable   // payload failed to decode (truncated/corrupt link)
        case fetchFailed  // dedupe lookup threw even after a retry
    }
    @State private var linkError: LinkError? = nil

    var body: some View {
        Group {
            if tutorial.isActive {
                tutorialBase
                    .allowsHitTesting(false)
            } else if viewModel.gameStarted {
                ScoreboardView(viewModel: viewModel)
            } else {
                PlayerSetupView(viewModel: viewModel, onShowTutorial: tutorial.start)
            }
        }
        .environment(
            \.dynamicTypeSize,
            UIDevice.current.userInterfaceIdiom == .pad
                ? dynamicTypeSize.stepped(by: 2)
                : dynamicTypeSize
        )
        .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            if tutorial.isActive {
                TutorialOverlayView(manager: tutorial, anchors: anchors)
            }
        }
        .onOpenURL { handleIncomingURL($0) }
        .incomingShareHost()
        .environmentObject(shareRouter)
        .environmentObject(gameCenter)
        .onAppear {
            gameCenter.authenticate()
            if !TutorialManager.hasSeenTutorial {
                tutorial.start()
            }
        }
        // Keep the view model's GC identity current no matter which screen is
        // up when authentication completes — saveGame() reads it.
        .onChange(of: gameCenter.playerID) { _, newID in
            viewModel.gameCenterPlayerID = newID
        }
        .alert("Couldn't Open Shared Game", isPresented: linkErrorBinding) {
            Button("OK", role: .cancel) { linkError = nil }
        } message: {
            Text(linkError == .unreadable
                 ? "This link couldn't be read. Please ask the sender to reshare the game."
                 : "Something went wrong opening this game. Please try the link again.")
        }
    }

    private var linkErrorBinding: Binding<Bool> {
        Binding(
            get: { linkError != nil },
            set: { if !$0 { linkError = nil } }
        )
    }

    /// What renders behind the tutorial overlay. Setup steps spotlight the
    /// real setup screen; scoreboard/stats steps swap in demo-data renderings
    /// of the real views, since a first launch has no game or history to show.
    @ViewBuilder
    private var tutorialBase: some View {
        switch tutorial.currentStep.screen {
        case .setup:
            PlayerSetupView(viewModel: viewModel, onShowTutorial: tutorial.start)
        case .scoreboard, .endGame:
            ScoreboardView(
                viewModel: tutorial.demoViewModel,
                initialInputValues: tutorial.demoInputValues
            )
        case .stats:
            TutorialStatsDemo(game: tutorial.demoGame)
        }
    }

    /// Handles an incoming recap Universal Link. If a game with the same
    /// shareID is already saved (the link was opened before, or you were the
    /// sharer), open that record directly instead of re-importing — this is
    /// the duplicate-link protection. Otherwise run the claim flow on a
    /// not-yet-persisted copy; it is only inserted if the recipient claims a
    /// player and taps Done.
    private func handleIncomingURL(_ url: URL) {
        // Only /g/<payload> links are ours; anything else is silently ignored.
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == ShareConfig.gamePathPrefix else { return }

        // A recap link that won't decode is a mangled/truncated share — tell
        // the user instead of failing silently.
        guard let payload = SharePayload(encodedString: parts[1]),
              let uuid = UUID(uuidString: payload.id) else {
            linkError = .unreadable
            return
        }

        var descriptor = FetchDescriptor<SavedGame>(
            predicate: #Predicate { $0.shareID == uuid }
        )
        descriptor.fetchLimit = 1

        // A thrown fetch must not fall through to the import path — treating
        // "lookup failed" as "not found" would re-import a duplicate of a game
        // already in history. Retry once, then surface the error and drop the
        // link.
        do {
            let existing: SavedGame?
            do {
                existing = try modelContext.fetch(descriptor).first
            } catch {
                existing = try modelContext.fetch(descriptor).first
            }
            if let existing {
                shareRouter.incomingMode = .ownHistory
                shareRouter.incomingGame = existing
            } else {
                shareRouter.incomingMode = .incomingShare
                shareRouter.incomingGame = payload.makeSavedGame()
            }
        } catch {
            linkError = .fetchFailed
        }
    }
}

// MARK: - Incoming share routing

/// Routes an incoming recap link to whichever screen is currently topmost.
/// A single root-level cover can't present while another sheet/cover is up,
/// so the host modifier is attached at every presentation site that can be
/// on top (app root, the Stats sheet, each game-detail cover); the unblocked
/// one wins and the recap appears above whatever the user was doing.
@MainActor
final class ShareRouter: ObservableObject {
    @Published var incomingGame: SavedGame? = nil
    /// Set before `incomingGame` so the presenting host reads the right mode.
    var incomingMode: GameDetailMode = .incomingShare
}

private struct IncomingShareHost: ViewModifier {
    @EnvironmentObject private var router: ShareRouter

    func body(content: Content) -> some View {
        content.fullScreenCover(item: $router.incomingGame) { game in
            // Deliberately no .incomingShareHost() here — the presented recap
            // hosting another copy of itself would recurse.
            GameDetailView(game: game, mode: router.incomingMode)
        }
    }
}

extension View {
    /// Attach wherever a view can be the topmost presented screen.
    func incomingShareHost() -> some View { modifier(IncomingShareHost()) }
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
