//
//  ScoreboardView.swift
//  Hearts Scoreboard
//

import SwiftUI
import SwiftData

struct ScoreboardView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var inputValues: [String] = ["", "", "", ""]
    @State private var showConfetti      = false
    @State private var showMoonAnimation = false
    @FocusState private var focusedInput: Int?

    // Shoot-the-moon confirmation (auto-detected from score pattern)
    @State private var showMoonConfirmation   = false
    @State private var moonShooterIndex: Int? = nil

    // Quit confirmation
    @State private var showQuitConfirmation = false

    private let buttonColumnWidth: CGFloat = 44

    private var moonAlertTitle: String {
        guard let idx = moonShooterIndex else { return "Shoot the Moon?" }
        return "\(viewModel.playerNames[idx]) shot the moon! 🌙"
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
            Text("The other 3 players will each receive 26 points.")
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

            ForEach(0..<4) { i in
                VStack(spacing: 3) {
                    Text(viewModel.playerNames[i])
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("\(viewModel.scores[i])")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(viewModel.scores[i]))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.4), value: viewModel.scores[i])
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.30))
    }

    private func scoreColor(_ score: Int) -> Color {
        let pct = Double(score) / Double(viewModel.targetScore)
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
                    .padding(.leading, 16)

                    Spacer()

                    if hasAnyInput {
                        Text("\(runningTotal) / 26")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(runningTotalColor)
                            .padding(.trailing, 16)
                            .animation(.easeInOut(duration: 0.15), value: runningTotal)
                    }
                }

                if viewModel.isTieBreaker {
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
                    if viewModel.hands.isEmpty {
                        Text("Completed hands will appear here")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(viewModel.hands.indices.reversed()), id: \.self) { i in
                            HandRowView(
                                hand: viewModel.hands[i].values,
                                buttonColumnWidth: buttonColumnWidth,
                                passDirection: passDirectionLabel(for: i),
                                moonShooterIndex: viewModel.hands[i].moonShooterIndex,
                                onSave: { values, moonIdx in
                                    viewModel.updateHand(at: i, values: values, moonShooterIndex: moonIdx)
                                }
                            )
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button { focusedInput = max(0, (focusedInput ?? 0) - 1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled((focusedInput ?? 0) == 0)

                    Button { focusedInput = min(3, (focusedInput ?? 0) + 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled((focusedInput ?? 0) == 3)

                    Spacer()

                    Button("Done") { focusedInput = nil }
                }
            }
        }
    }

    // MARK: - Passing Info

    private var passingInfo: (icon: String, label: String) {
        switch viewModel.hands.count % 4 {
        case 0: return ("arrow.left",            "Pass Left")
        case 1: return ("arrow.right",           "Pass Right")
        case 2: return ("arrow.left.and.right",  "Pass Across")
        case 3: return ("hand.raised",           "Keep")
        default: return ("", "")
        }
    }

    private func passDirectionLabel(for index: Int) -> String {
        switch index % 4 {
        case 0: return "👈"
        case 1: return "👉"
        case 2: return "👆"
        case 3: return "✋"
        default: return ""
        }
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .hidden()
                .frame(width: buttonColumnWidth)

            ForEach(0..<4) { i in
                TextField("0", text: $inputValues[i])
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
                    .onChange(of: inputValues[i]) { _, newValue in
                        let digitsOnly = newValue.filter { $0.isNumber }
                        if digitsOnly != newValue { inputValues[i] = digitsOnly }
                    }
            }

            Button(action: handleCommitTap) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(canCommit ? .white : .white.opacity(0.25))
            }
            .disabled(!canCommit)
            .frame(width: buttonColumnWidth)
        }
        .padding(.horizontal, 12)
        .onSubmit {
            if canCommit { handleCommitTap() }
        }
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
        guard values.count == 4 else { return }

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
              values.filter({ $0 == 0  }).count == 3 else { return nil }
        return values.firstIndex(of: 26)
    }

    /// Pattern B: exactly three players have 26 and one player has 0.
    private func isAlreadyCorrectMoon(_ values: [Int]) -> Bool {
        values.filter({ $0 == 26 }).count == 3 &&
        values.filter({ $0 == 0  }).count == 1
    }

    /// User confirmed Pattern A — invert scores then animate.
    private func confirmShootTheMoon() {
        guard let idx = moonShooterIndex else { return }
        var adjusted = [Int](repeating: 26, count: 4)
        adjusted[idx] = 0
        doCommit(adjusted, moonShooterIndex: idx)
        moonShooterIndex = nil
        showMoonAnimation = true
    }

    private func doCommit(_ values: [Int], moonShooterIndex: Int? = nil) {
        viewModel.commitHand(values, moonShooterIndex: moonShooterIndex)
        inputValues = ["", "", "", ""]
        focusedInput = nil
    }
}

#Preview {
    let vm = GameViewModel()
    vm.playerNames = ["Alice", "Bob", "Carol", "Dave"]
    vm.startGame()
    vm.commitHand([5, 0, 13, 8])
    vm.commitHand([0, 26, 0, 0])
    return ScoreboardView(viewModel: vm)
        .modelContainer(for: SavedGame.self, inMemory: true)
}
