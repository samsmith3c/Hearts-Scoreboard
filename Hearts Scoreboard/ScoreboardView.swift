//
//  ScoreboardView.swift
//  Hearts Scoreboard
//

import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var inputValues: [String] = ["", "", "", ""]
    @State private var showConfetti      = false
    @State private var showMoonAnimation = false
    @FocusState private var focusedInput: Int?

    // Shoot-the-moon confirmation
    @State private var showMoonConfirmation = false
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
        // Win alert
        .alert("\(viewModel.winner ?? "Someone") wins! 🎉", isPresented: $viewModel.showWinAlert) {
            Button("New Game") {
                showConfetti = false
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
        // Shoot-the-moon confirmation alert
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
            .frame(width: buttonColumnWidth + 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.30))
    }

    private func scoreColor(_ score: Int) -> Color {
        let pct = Double(score) / Double(viewModel.targetScore)
        if pct >= 0.80 { return Color(hex: "FF6B6B") }   // danger — 80% of target
        if pct >= 0.50 { return Color(hex: "FFD93D") }   // warning — 50% of target
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
                                moonShooterIndex: viewModel.hands[i].moonShooterIndex
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

    /// Emoji passing indicator for a committed hand at the given history index.
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
        HStack(spacing: 4) {
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
            return Color(hex: "4CD964")     // green — valid hand or shoot the moon
        }
        if runningTotal > 26 {
            return Color(hex: "FF6B6B")     // red — gone over (and not a moon)
        }
        return .white.opacity(0.5)          // neutral — still typing
    }

    // MARK: - Validation & Commit Logic

    private func handleCommitTap() {
        let values = inputValues.map { Int($0) ?? 0 }
        guard values.count == 4 else { return }

        // Pattern A: shooter entered 26 for themselves, others entered 0.
        // Needs confirmation because we have to invert the scores.
        if let idx = shooterEnteredOwn26(values) {
            moonShooterIndex = idx
            showMoonConfirmation = true
            return
        }

        // Pattern B: user already entered the correct result —
        // shooter has 0, the other 3 each have 26. Commit as-is + animation.
        if isAlreadyCorrectMoon(values) {
            doCommit(values, moonShooterIndex: values.firstIndex(of: 0))
            showMoonAnimation = true
            return
        }

        doCommit(values)
    }

    /// Pattern A: exactly one player entered 26, all others entered 0.
    /// Returns the shooter's index so we can name them in the confirmation.
    private func shooterEnteredOwn26(_ values: [Int]) -> Int? {
        guard values.filter({ $0 == 26 }).count == 1,
              values.filter({ $0 == 0  }).count == 3 else { return nil }
        return values.firstIndex(of: 26)
    }

    /// Pattern B: exactly three players have 26 and one player has 0.
    /// Scores are already correct — no inversion required.
    private func isAlreadyCorrectMoon(_ values: [Int]) -> Bool {
        values.filter({ $0 == 26 }).count == 3 &&
        values.filter({ $0 == 0  }).count == 1
    }

    /// User confirmed Pattern A — invert scores then animate.
    private func confirmShootTheMoon() {
        guard let idx = moonShooterIndex else { return }
        // Input: shooter=26, others=0  →  Commit: shooter=0, others=26
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
}
