//
//  ScoreboardView.swift
//  Hearts Scoreboard
//

import SwiftUI
import SwiftData

struct ScoreboardView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var inputValues: [String]
    @State private var showConfetti      = false
    @State private var showMoonAnimation = false
    @FocusState private var focusedInput: Int?

    // Shoot-the-moon confirmation (auto-detected from score pattern)
    @State private var showMoonConfirmation   = false
    @State private var moonShooterIndex: Int? = nil

    // Quit confirmation
    @State private var showQuitConfirmation = false

    // Set when the player chooses Share on the win alert; presents the saved
    // game in GameDetailView, whose toolbar has the ShareLink.
    @State private var gameToShare: SavedGame? = nil

    /// initialInputValues is only supplied by the tutorial's demo rendering,
    /// so the running-total counter has something to point at.
    init(viewModel: GameViewModel, initialInputValues: [String]? = nil) {
        self.viewModel = viewModel
        _inputValues = State(
            initialValue: initialInputValues
                ?? Array(repeating: "", count: viewModel.gamePlayerCount)
        )
    }

    private var playerCount: Int { viewModel.gamePlayerCount }

    // Narrower edge buttons at 5–6 players buy the score columns more room.
    private var buttonColumnWidth: CGFloat { playerCount > 4 ? 36 : 44 }

    private var moonAlertTitle: String {
        guard let idx = moonShooterIndex,
              viewModel.gamePlayerNames.indices.contains(idx) else { return "Shoot the Moon?" }
        return "\(viewModel.gamePlayerNames[idx]) shot the moon! 🌙"
    }

    var body: some View {
        ZStack {
            feltGreen.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                handsSection
            }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if showMoonAnimation {
                ShootingMoonView {
                    showMoonAnimation = false
                }
                .allowsHitTesting(false)
            }
        }
        // Win alert — saveGame() is called here, after the alert is dismissed
        .alert("\(viewModel.winner ?? "Someone") wins! 🎉", isPresented: $viewModel.showWinAlert) {
            Button("New Game") {
                showConfetti = false
                viewModel.saveGame(context: modelContext)
                viewModel.resetGame()
            }
            // Alerts can only hold buttons (no ShareLink), so Share opens the
            // saved game in GameDetailView, which has the share icon.
            // resetGame() waits until that cover closes — resetting here would
            // unmount this view and the cover with it.
            Button("Share") {
                showConfetti = false
                gameToShare = viewModel.saveGame(context: modelContext)
            }
        }
        .fullScreenCover(item: $gameToShare, onDismiss: { viewModel.resetGame() }) { game in
            GameDetailView(game: game)
                .incomingShareHost()
        }
        // Quit confirmation alert
        .alert("Quit Game?", isPresented: $showQuitConfirmation) {
            Button("Quit", role: .destructive) { viewModel.resetGame() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your current scores will be lost.")
        }
        // Auto-detected moon shoot confirmation (Pattern A)
        .alert(moonAlertTitle, isPresented: $showMoonConfirmation) {
            Button("Confirm") { confirmShootTheMoon() }
            Button("Cancel", role: .cancel) { moonShooterIndex = nil }
        } message: {
            Text("The other \(playerCount - 1) players will each receive 26 points.")
        }
        .onChange(of: viewModel.showWinAlert) { _, triggered in
            if triggered { showConfetti = true }
        }
    }

    // MARK: - Header (always visible)

    private var headerView: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.goHome()
            } label: {
                Image(systemName: "house.circle")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.45))
            }
            .frame(width: buttonColumnWidth)
            .accessibilityIdentifier("scoreboard.home")
            .tutorialAnchor(.homeButton)

            ForEach(0..<playerCount, id: \.self) { i in
                VStack(spacing: 3) {
                    Text(viewModel.gamePlayerNames[i])
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("\(viewModel.gameScores[i])")
                        .font(playerCount > 4 ? .title2 : .title)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(viewModel.gameScores[i]))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.4), value: viewModel.gameScores[i])
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                showQuitConfirmation = true
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.45))
            }
            .frame(width: buttonColumnWidth)
            .tutorialAnchor(.quitButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.30))
        .tutorialAnchor(.scoreHeader)
    }

    private func scoreColor(_ score: Int) -> Color {
        let pct = Double(score) / Double(viewModel.gameTargetScore)
        if pct >= 0.80 { return Color(hex: "FF6B6B") }
        if pct >= 0.50 { return Color(hex: "FFD93D") }
        return .white
    }

    // MARK: - Hands Section

    private var handsSection: some View {
        VStack(spacing: 0) {

            // ── Row: passing instruction (left) + live score (right) ───────
            ZStack {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: passingInfo.icon)
                        Text(passingInfo.label)
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .tutorialAnchor(.passIndicator)
                    .padding(.leading, 16)

                    Spacer()

                    if hasAnyInput {
                        Text("\(runningTotal) / 26")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(runningTotalColor)
                            .tutorialAnchor(.runningTotal)
                            .padding(.trailing, 16)
                            .animation(.easeInOut(duration: 0.15), value: runningTotal)
                    }
                }

                if viewModel.gameIsTieBreaker {
                    Text("🚨 TIE BREAKER 🚨")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "FFD93D"))
                }
            }
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.18))

            // ── Active input row ────────────────────────────────────────────
            inputRow
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .tutorialAnchor(.inputRow)

            // ── "PAST HANDS" section divider ────────────────────────────────
            HStack {
                Text("PAST HANDS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.8)
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.leading, 16)
                    .padding(.vertical, 6)
                Spacer()
            }
            .background(Color.black.opacity(0.12))

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)

            // ── Scrollable hand history ─────────────────────────────────────
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.gameHands.isEmpty {
                        Text("Completed hands will appear here")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(viewModel.gameHands.indices.reversed()), id: \.self) { i in
                            HandRowView(
                                hand: viewModel.gameHands[i].values,
                                buttonColumnWidth: buttonColumnWidth,
                                passDirection: passDirectionLabel(for: i),
                                moonShooterIndex: viewModel.gameHands[i].moonShooterIndex,
                                onSave: { values, moonIdx in
                                    viewModel.updateHand(at: i, values: values, moonShooterIndex: moonIdx)
                                }
                            )
                            // Spotlight target = the topmost (most recent) row
                            .tutorialAnchor(i == viewModel.gameHands.count - 1 ? .pastHandRow : nil)
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Passing Info

    /// 4 players use the classic Left → Right → Across → Keep cycle; every
    /// other count has no opposite seat, so the cycle is Left → Right → Keep.
    private var passingInfo: (icon: String, label: String) {
        if playerCount == 4 {
            switch viewModel.gameHands.count % 4 {
            case 0: return ("arrow.left",            "Pass Left")
            case 1: return ("arrow.right",           "Pass Right")
            case 2: return ("arrow.left.and.right",  "Pass Across")
            default: return ("hand.raised",          "Keep")
            }
        }
        switch viewModel.gameHands.count % 3 {
        case 0: return ("arrow.left",   "Pass Left")
        case 1: return ("arrow.right",  "Pass Right")
        default: return ("hand.raised", "Keep")
        }
    }

    /// Emoji shorthand for past hands — same cycle as passingInfo.
    private func passDirectionLabel(for index: Int) -> String {
        if playerCount == 4 {
            switch index % 4 {
            case 0: return "👈"
            case 1: return "👉"
            case 2: return "👆"
            default: return "✋"
            }
        }
        switch index % 3 {
        case 0: return "👈"
        case 1: return "👉"
        default: return "✋"
        }
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .hidden()
                .frame(width: buttonColumnWidth)

            ForEach(0..<playerCount, id: \.self) { i in
                TextField("0", text: inputBinding(i))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.13))
                    .cornerRadius(7)
                    .focused($focusedInput, equals: i)
                    .frame(maxWidth: 100)
                    .frame(maxWidth: .infinity)
                    .onChange(of: inputBinding(i).wrappedValue) { _, newValue in
                        let digitsOnly = newValue.filter { $0.isNumber }
                        if digitsOnly != newValue { inputBinding(i).wrappedValue = digitsOnly }
                    }
            }

            Button(action: handleCommitTap) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(canCommit ? .white : .white.opacity(0.25))
            }
            .disabled(!canCommit)
            .accessibilityIdentifier("scoreboard.commit")
            .frame(width: buttonColumnWidth)
        }
        .padding(.horizontal, 12)
        .onSubmit {
            if canCommit { handleCommitTap() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button {
                    DispatchQueue.main.async {
                        focusedInput = max(0, (focusedInput ?? 0) - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled((focusedInput ?? 0) == 0)

                Button {
                    DispatchQueue.main.async {
                        focusedInput = min(playerCount - 1, (focusedInput ?? 0) + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled((focusedInput ?? 0) == playerCount - 1)

                Spacer()

                Button("Done") {
                    DispatchQueue.main.async { focusedInput = nil }
                }
            }
        }
    }

    /// Index-safe binding — resetGame() flips playerCount back to 4 while this
    /// view can still render one last pass against a smaller inputValues.
    private func inputBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { inputValues.indices.contains(i) ? inputValues[i] : "" },
            set: { if inputValues.indices.contains(i) { inputValues[i] = $0 } }
        )
    }

    private var canCommit: Bool {
        runningTotal == 26 || isAlreadyCorrectMoon(inputValues.map { Int($0) ?? 0 })
    }

    // MARK: - Running Total

    private var hasAnyInput: Bool {
        inputValues.contains { !$0.isEmpty }
    }

    private var runningTotal: Int {
        inputValues.map { Int($0) ?? 0 }.reduce(0, +)
    }

    private var runningTotalColor: Color {
        if runningTotal == 26 || isAlreadyCorrectMoon(inputValues.map { Int($0) ?? 0 }) {
            return Color(hex: "4CD964")
        }
        if runningTotal > 26 {
            return Color(hex: "FF6B6B")
        }
        return .white.opacity(0.5)
    }

    // MARK: - Validation & Commit Logic

    private func handleCommitTap() {
        let values = inputValues.map { Int($0) ?? 0 }
        guard values.count == playerCount else { return }

        if let idx = shooterEnteredOwn26(values) {
            moonShooterIndex = idx
            showMoonConfirmation = true
            return
        }

        if isAlreadyCorrectMoon(values) {
            doCommit(values, moonShooterIndex: values.firstIndex(of: 0))
            showMoonAnimation = true
            return
        }

        doCommit(values)
    }

    /// Pattern A: exactly one player entered 26, all others entered 0.
    private func shooterEnteredOwn26(_ values: [Int]) -> Int? {
        guard values.filter({ $0 == 26 }).count == 1,
              values.filter({ $0 == 0  }).count == values.count - 1 else { return nil }
        return values.firstIndex(of: 26)
    }

    /// Pattern B: every player but one has 26 and that one player has 0.
    private func isAlreadyCorrectMoon(_ values: [Int]) -> Bool {
        values.filter({ $0 == 26 }).count == values.count - 1 &&
        values.filter({ $0 == 0  }).count == 1
    }

    /// User confirmed Pattern A — invert scores then animate.
    private func confirmShootTheMoon() {
        guard let idx = moonShooterIndex else { return }
        var adjusted = [Int](repeating: 26, count: playerCount)
        adjusted[idx] = 0
        doCommit(adjusted, moonShooterIndex: idx)
        moonShooterIndex = nil
        showMoonAnimation = true
    }

    private func doCommit(_ values: [Int], moonShooterIndex: Int? = nil) {
        viewModel.commitHand(values, moonShooterIndex: moonShooterIndex)
        inputValues = Array(repeating: "", count: playerCount)
        // Defer focus change to next runloop tick so SwiftUI doesn't drop
        // the @FocusState update during the same render pass that mutates
        // inputValues + commits the hand to the view model.
        DispatchQueue.main.async {
            focusedInput = nil
        }
    }
}

// What's next:
// - HandRowView: derive columns + moon patterns from hand.count.
// - Sanity-check 6-player column widths on the smallest supported iPhone.

#Preview("4 players") {
    let vm = GameViewModel(persistsState: false)
    vm.playerNames = ["Alice", "Bob", "Carol", "Dave"]
    vm.startGame()
    vm.commitHand([5, 0, 13, 8])
    vm.commitHand([0, 26, 0, 0])
    return ScoreboardView(viewModel: vm)
        .modelContainer(for: SavedGame.self, inMemory: true)
}

#Preview("6 players") {
    let vm = GameViewModel(persistsState: false)
    vm.playerCount = 6
    vm.playerNames = ["Alice", "Bob", "Carol", "Dave", "Erin", "Frank"]
    vm.startGame()
    vm.commitHand([5, 0, 13, 8, 0, 0])
    vm.commitHand([0, 26, 0, 0, 0, 0])
    return ScoreboardView(viewModel: vm)
        .modelContainer(for: SavedGame.self, inMemory: true)
}
