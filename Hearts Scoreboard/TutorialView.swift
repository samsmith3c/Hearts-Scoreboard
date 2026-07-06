//
//  TutorialView.swift
//  Hearts Scoreboard
//

import SwiftUI

// MARK: - Anchor plumbing

/// Identifies a real UI element the tutorial can spotlight.
enum TutorialAnchorID: String, Hashable {
    case playerCountPicker
    case selfMarker
    case scoreHeader
    case passIndicator
    case inputRow
    case runningTotal
    case pastHandRow
    case homeButton
    case quitButton
    case statsTabPicker
    case gameCard
    case gameCardDelete
    case helpButton
}

struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialAnchorID: Anchor<CGRect>] = [:]
    static func reduce(
        value: inout [TutorialAnchorID: Anchor<CGRect>],
        nextValue: () -> [TutorialAnchorID: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Tags this view as a tutorial spotlight target. Accepts nil so call
    /// sites can tag conditionally (e.g. only the first row of a list).
    @ViewBuilder
    func tutorialAnchor(_ id: TutorialAnchorID?) -> some View {
        if let id {
            anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [id: $0] }
        } else {
            self
        }
    }
}

// MARK: - Steps

struct TutorialStep {
    /// Which screen must be on-screen behind the overlay for this step.
    enum Screen { case setup, scoreboard, endGame, stats }

    let screen: Screen
    /// Elements to spotlight; multiple anchors are unioned into one cutout.
    /// Empty = no cutout, callout is centered (the end-of-game rule step).
    let anchors: [TutorialAnchorID]
    let text: String
}

// MARK: - Manager

@MainActor
final class TutorialManager: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var stepIndex = 0

    private static let hasSeenKey = "hearts.hasSeenTutorial"

    static var hasSeenTutorial: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenKey) }
    }

    /// Demo state rendered behind the scoreboard/stats steps so the spotlight
    /// has real UI to point at even on a fresh install with no games. The demo
    /// SavedGame is never inserted into the model context, so it cannot leak
    /// into real history or stats.
    private(set) var demoViewModel = GameViewModel(persistsState: false)
    private(set) var demoGame = SavedGame()
    /// Sums to exactly 26 so the running total shows green and "+" is enabled.
    let demoInputValues = ["5", "9", "8", "4"]

    let steps: [TutorialStep] = [
        // Stop 1 — setup screen
        .init(screen: .setup, anchors: [.playerCountPicker],
              text: "Playing with 3 to 6? Pick your player count here — the name fields adjust to match."),
        .init(screen: .setup, anchors: [.selfMarker],
              text: "Tap the person icon to mark which player is you. That's how your lifetime stats find you."),

        // Stop 2 — scoreboard core
        .init(screen: .scoreboard, anchors: [.scoreHeader],
              text: "Every player's total lives up here, always visible. Lowest score is winning!"),
        .init(screen: .scoreboard, anchors: [.passIndicator],
              text: "Before each hand, this shows which way to pass cards — Left, Right, Across, or Keep."),
        .init(screen: .scoreboard, anchors: [.inputRow, .runningTotal],
              text: "After each hand, type everyone's points here. The live counter turns green when they total exactly 26 — then tap + to record the hand."),

        // Stop 3 — scoreboard extras
        .init(screen: .scoreboard, anchors: [.pastHandRow],
              text: "Made a mistake? Tap the pencil on any past hand to fix it — totals recalculate automatically."),
        .init(screen: .scoreboard, anchors: [.homeButton],
              text: "The house takes you back to the home screen without losing your game — resume anytime."),
        .init(screen: .scoreboard, anchors: [.quitButton],
              text: "Done for good? The ✕ quits and discards the current game."),

        // Stop 4 — end-of-game rule
        .init(screen: .endGame, anchors: [],
              text: "When anyone reaches the target score, the game ends — and the LOWEST total wins! 🎉"),

        // Stop 5 — stats & history
        .init(screen: .stats, anchors: [.statsTabPicker],
              text: "Finished games land in Lifetime Stats — the Stats tab tracks your wins, streaks, and moon shoots."),
        .init(screen: .stats, anchors: [.gameCard],
              text: "Tap any saved game for hand-by-hand detail — and a share button to send friends a recap link."),
        .init(screen: .stats, anchors: [.gameCardDelete],
              text: "The trash icon removes a game from your history and stats."),

        // Closing beat — back on the home screen
        .init(screen: .setup, anchors: [.helpButton],
              text: "That's everything! Replay this tour anytime with the ? button. Have fun! ♥️"),
    ]

    var currentStep: TutorialStep { steps[stepIndex] }
    var isLastStep: Bool { stepIndex == steps.count - 1 }

    func start() {
        buildDemoState()
        stepIndex = 0
        isActive = true
    }

    func advance() {
        if isLastStep {
            finish()
        } else {
            stepIndex += 1
        }
    }

    /// Skip and natural completion both count as "seen" — the "?" button is
    /// the deliberate replay path either way.
    func finish() {
        isActive = false
        Self.hasSeenTutorial = true
    }

    private func buildDemoState() {
        // persistsState: false — the demo must never write to UserDefaults or
        // restore (and then overwrite) the user's real in-progress game.
        let vm = GameViewModel(persistsState: false)
        vm.playerNames = ["Sam", "Madi", "Shaun", "Carson"]
        vm.targetScore = 100
        vm.startGame()
        vm.commitHand([3, 7, 10, 6])
        vm.commitHand([0, 26, 26, 26], moonShooterIndex: 0)
        vm.commitHand([13, 5, 2, 6])
        demoViewModel = vm

        let game = SavedGame(
            playerNames: ["Sam", "Madi", "Shaun", "Carson"],
            finalScores: [26, 42, 46, 42],
            winnerIndex: 0
        )
        let handScores: [[Int]] = [
            [3, 7, 10, 6],
            [0, 26, 26, 26],
            [13, 5, 2, 6],
            [10, 4, 8, 4],
        ]
        game.hands = handScores.enumerated().map { i, scores in
            let isMoon = scores.filter { $0 == 26 }.count == scores.count - 1
                      && scores.filter { $0 == 0 }.count == 1
            return SavedHand(
                handNumber: i,
                scores: scores,
                isMoonShoot: isMoon,
                moonShooterIndex: isMoon ? scores.firstIndex(of: 0) : nil,
                game: game
            )
        }
        demoGame = game
    }
}

// MARK: - Demo stats screen (Games tab lookalike for the stats stop)

struct TutorialStatsDemo: View {
    let game: SavedGame

    var body: some View {
        ZStack {
            feltGreen.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Lifetime Stats")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)

                Picker("Tab", selection: .constant(1)) {
                    Text("Stats").tag(0)
                    Text("Games").tag(1)
                }
                .pickerStyle(.segmented)
                .tutorialAnchor(.statsTabPicker)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                ScrollView {
                    GameHistoryCard(game: game, onTap: {}, onDelete: {})
                        .tutorialAnchor(.gameCard)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 560)
                }
            }
        }
    }
}

// MARK: - Overlay

struct TutorialOverlayView: View {
    @ObservedObject var manager: TutorialManager
    let anchors: [TutorialAnchorID: Anchor<CGRect>]

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let step = manager.currentStep
                let spotlight = spotlightRect(for: step, in: proxy)

                ZStack {
                    SpotlightDimShape(cutout: spotlight)
                        .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))

                    if step.screen == .endGame {
                        ConfettiView()
                            .allowsHitTesting(false)
                    }

                    callout(step: step, spotlight: spotlight, size: proxy.size)
                }
            }
            .ignoresSafeArea()

            // Skip — pinned to the bottom-trailing corner, always visible
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        manager.finish()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }
                }
            }
            .padding(20)
        }
        .contentShape(Rectangle())
        .onTapGesture { manager.advance() }
    }

    /// Union of every resolved anchor for the step, padded a touch so the
    /// cutout breathes around the element. Nil = centered callout, no cutout.
    private func spotlightRect(for step: TutorialStep, in proxy: GeometryProxy) -> CGRect? {
        let rects = step.anchors.compactMap { id in anchors[id].map { proxy[$0] } }
        guard var rect = rects.first else { return nil }
        for r in rects.dropFirst() { rect = rect.union(r) }
        return rect.insetBy(dx: -6, dy: -6)
    }

    // MARK: Callout bubble + arrow

    @ViewBuilder
    private func callout(step: TutorialStep, spotlight: CGRect?, size: CGSize) -> some View {
        let bubbleWidth = min(size.width - 48, 360)

        if let rect = spotlight {
            let placeBelow = rect.midY < size.height / 2
            let arrowOffset = max(
                -bubbleWidth / 2 + 24,
                min(bubbleWidth / 2 - 24, rect.midX - size.width / 2)
            )

            VStack(spacing: 0) {
                if placeBelow {
                    TutorialArrowShape()
                        .fill(Color.white)
                        .frame(width: 22, height: 11)
                        .offset(x: arrowOffset)
                }
                bubble(step: step)
                    .frame(width: bubbleWidth)
                if !placeBelow {
                    TutorialArrowShape()
                        .fill(Color.white)
                        .frame(width: 22, height: 11)
                        .scaleEffect(y: -1)
                        .offset(x: arrowOffset)
                }
            }
            .padding(.top, placeBelow ? rect.maxY + 10 : 0)
            .padding(.bottom, placeBelow ? 0 : max(0, size.height - rect.minY + 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: placeBelow ? .top : .bottom)
        } else {
            bubble(step: step)
                .frame(width: bubbleWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func bubble(step: TutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(manager.stepIndex + 1) of \(manager.steps.count)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(feltGreen.opacity(0.65))

            Text(step.text)
                .font(.body)
                .foregroundColor(Color(hex: "1F3D1B"))
                .fixedSize(horizontal: false, vertical: true)

            Text(manager.isLastStep ? "Tap anywhere to finish" : "Tap anywhere to continue")
                .font(.caption)
                .foregroundColor(feltGreen.opacity(0.75))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}

// MARK: - Shapes

/// Full-rect fill with a rounded-rect hole punched out (even-odd fill).
private struct SpotlightDimShape: Shape {
    let cutout: CGRect?

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        if let cutout {
            p.addRoundedRect(in: cutout, cornerSize: CGSize(width: 12, height: 12))
        }
        return p
    }
}

/// Upward-pointing triangle; flip with scaleEffect(y: -1) to point down.
private struct TutorialArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// What's next:
// - ContentView: swap in demo screens while the tutorial is active, mount the
//   overlay via overlayPreferenceValue, and auto-start on first launch.
// - PlayerSetupView / ScoreboardView / StatsView: tag spotlight targets with
//   .tutorialAnchor(...) and add the "?" replay button.
