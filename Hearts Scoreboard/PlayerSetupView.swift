//
//  PlayerSetupView.swift
//  Hearts Scoreboard
//

import SwiftUI
import GameKit

struct PlayerSetupView: View {
    @ObservedObject var viewModel: GameViewModel
    @EnvironmentObject private var gameCenter: GameCenterService
    /// Re-launches the tutorial ("?" button). Defaults to a no-op so previews
    /// and existing call sites don't need to supply one.
    var onShowTutorial: () -> Void = {}
    @FocusState private var focusedField: Int?
    @State private var showNewGameConfirmation = false
    @State private var showNoSelfWarning = false
    @State private var showCardRemovalPopup = false
    @State private var showStats = false

    private var allFieldsFilled: Bool {
        viewModel.playerNames.allSatisfy {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        ZStack {
            feltGreen.ignoresSafeArea()

            VStack(spacing: 36) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "suit.heart.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                    Text("Hearts Scoreboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                if viewModel.hasActiveGame {
                    Button {
                        viewModel.resumeGame()
                    } label: {
                        Text("Resume Game")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Color(hex: "C0392B"))
                            .cornerRadius(20)
                    }

                    // The form below configures a NEW game only — it can't
                    // touch the game in progress. Make that split explicit.
                    orDivider
                }

                // Form — capped width so it doesn't stretch across an iPad
                VStack(spacing: 24) {
                    // Player name fields
                    VStack(spacing: 8) {
                        Text("Players")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)

                        Picker("Players", selection: $viewModel.playerCount) {
                            ForEach(GameViewModel.allowedPlayerCounts, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tutorialAnchor(.playerCountPicker)
                        .padding(.bottom, 6)

                        VStack(spacing: 14) {
                            ForEach(0..<viewModel.playerCount, id: \.self) { i in
                                playerField(index: i)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.playerCount)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Button {
                                    DispatchQueue.main.async {
                                        focusedField = max(0, (focusedField ?? 0) - 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                                .disabled((focusedField ?? 0) == 0)

                                Button {
                                    DispatchQueue.main.async {
                                        focusedField = min(viewModel.playerCount - 1, (focusedField ?? 0) + 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .disabled((focusedField ?? 0) == viewModel.playerCount - 1)

                                Spacer()

                                Button("Done") {
                                    DispatchQueue.main.async { focusedField = nil }
                                }
                            }
                        }

                        HStack(spacing: 4) {
                            Text("tap")
                            Image(systemName: "person.fill")
                            Text("to mark yourself")
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }

                    // Target score picker
                    VStack(spacing: 8) {
                        Text("Target Score")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)

                        Picker("Target Score", selection: $viewModel.targetScore) {
                            Text("50").tag(50)
                            Text("75").tag(75)
                            Text("100").tag(100)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.top, 16)

                    // Start Game button
                    Button {
                        DispatchQueue.main.async { focusedField = nil }
                        attemptStart()
                    } label: {
                        Text("Start New Game")
                            .font(.headline)
                            .foregroundColor(feltGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(allFieldsFilled ? Color.white : Color.white.opacity(0.3))
                            .cornerRadius(12)
                    }
                    .disabled(!allFieldsFilled)
                    .animation(.easeInOut(duration: 0.2), value: allFieldsFilled)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 480)
            }

            // Tutorial "?" button top-left, stats button top-right
            VStack {
                HStack {
                    Button {
                        onShowTutorial()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(16)
                    }
                    .tutorialAnchor(.helpButton)

                    Spacer()

                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
        .alert("Abandon current game?", isPresented: $showNewGameConfirmation) {
            Button("Start New Game", role: .destructive) { checkTrackingThenStart() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your current game progress will be lost.")
        }
        .alert("Not tracking this game?", isPresented: $showNoSelfWarning) {
            Button("Continue") { confirmDeckThenStart() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You're about to start a game that you're not going to track. Are you sure you'd like to continue?")
        }
        .alert("Prepare the Deck", isPresented: $showCardRemovalPopup) {
            Button("Start Game") { viewModel.startGame() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(cardRemovalMessage(for: viewModel.playerCount))
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .onAppear {
            applyGameCenterName()
        }
        .onChange(of: gameCenter.playerID) { _, _ in
            applyGameCenterName()
        }
    }

    // MARK: - OR divider (shown between Resume and the new-game form)

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 1)
            Text("OR")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.5))
                .fixedSize()
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 1)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 480)
    }

    // MARK: - Start flow

    private func attemptStart() {
        if viewModel.hasActiveGame {
            showNewGameConfirmation = true
        } else {
            checkTrackingThenStart()
        }
    }

    private func checkTrackingThenStart() {
        if viewModel.selfPlayerIndex == nil {
            showNoSelfWarning = true
        } else {
            confirmDeckThenStart()
        }
    }

    /// 4 players use a standard deck — start immediately, no popup. Any other
    /// count needs physical cards pulled first, so show the removal alert.
    private func confirmDeckThenStart() {
        if viewModel.playerCount == 4 {
            viewModel.startGame()
        } else {
            showCardRemovalPopup = true
        }
    }

    /// Which cards to pull so every player is dealt the same number and the
    /// 2♣ lead stays in the deck. Points are unaffected: no hearts or Q♠ are
    /// ever removed, so each hand still totals 26.
    private func cardRemovalMessage(for count: Int) -> String {
        switch count {
        case 3: return "For 3 players, please remove the 2♦. Each player will be dealt 17 cards."
        case 5: return "For 5 players, please remove the 2♦ and 3♣. Each player will be dealt 10 cards."
        case 6: return "For 6 players, please remove the 2♦, 3♦, 3♣, and 4♣. Each player will be dealt 8 cards."
        default: return ""
        }
    }

    // MARK: - Player field with self-designation icon

    @ViewBuilder
    private func playerField(index i: Int) -> some View {
        HStack(spacing: 12) {
            // person icon — filled = this is "me", outline = not designated
            Button {
                if viewModel.selfPlayerIndex == i {
                    viewModel.selfPlayerIndex = nil
                } else {
                    viewModel.selfPlayerIndex = i
                }
            } label: {
                Image(systemName: viewModel.selfPlayerIndex == i ? "person.fill" : "person")
                    .foregroundColor(
                        viewModel.selfPlayerIndex == i
                            ? .white
                            : .white.opacity(0.45)
                    )
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.selfPlayerIndex)
            }
            .buttonStyle(.plain)
            .tutorialAnchor(i == 0 ? .selfMarker : nil)

            TextField("Player \(i + 1) name", text: nameBinding(i))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
                .foregroundColor(.white)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: i)
                .submitLabel(i < viewModel.playerCount - 1 ? .next : .done)
                .onSubmit {
                    DispatchQueue.main.async {
                        focusedField = i < viewModel.playerCount - 1 ? i + 1 : nil
                    }
                }
                .onChange(of: nameBinding(i).wrappedValue) { _, newValue in
                    if newValue.count > 10 {
                        viewModel.playerNames[i] = String(newValue.prefix(10))
                    }
                }
        }
    }

    /// Index-safe binding — a field animating out after the count shrinks can
    /// still render one pass while its playerNames slot is already gone.
    private func nameBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { viewModel.playerNames.indices.contains(i) ? viewModel.playerNames[i] : "" },
            set: { if viewModel.playerNames.indices.contains(i) { viewModel.playerNames[i] = $0 } }
        )
    }

    // MARK: - Game Center name autofill

    /// Fills the currently-designated self slot with the GC display name only
    /// if that slot is empty — never overwrites a name the user typed.
    /// Authentication itself is owned by GameCenterService at the app root.
    private func applyGameCenterName() {
        guard gameCenter.playerID != nil,
              let name = gameCenter.displayName,
              let idx = viewModel.selfPlayerIndex,
              viewModel.playerNames.indices.contains(idx),
              viewModel.playerNames[idx].trimmingCharacters(in: .whitespaces).isEmpty
        else { return }
        viewModel.playerNames[idx] = name
    }
}

// What's next:
// - ScoreboardView / HandRowView: variable columns + moon patterns per count.
// - SharePayload + share-service: hands carry playerCount scores on the wire.

#Preview {
    PlayerSetupView(viewModel: GameViewModel(persistsState: false))
        .environmentObject(GameCenterService())
}
