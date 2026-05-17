//
//  PlayerSetupView.swift
//  Hearts Scoreboard
//

import SwiftUI
import GameKit

struct PlayerSetupView: View {
    @ObservedObject var viewModel: GameViewModel
    @FocusState private var focusedField: Int?
    @State private var showNewGameConfirmation = false
    @State private var showNoSelfWarning = false
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

                        VStack(spacing: 14) {
                            ForEach(0..<4) { i in
                                playerField(index: i)
                            }
                        }
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
                                        focusedField = min(3, (focusedField ?? 0) + 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .disabled((focusedField ?? 0) == 3)

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

            // Stats button — top-right corner
            VStack {
                HStack {
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
            Button("Continue") { viewModel.startGame() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You're about to start a game that you're not going to track. Are you sure you'd like to continue?")
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .onAppear {
            authenticateGameCenter()
        }
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
            viewModel.startGame()
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

            TextField("Player \(i + 1) name", text: $viewModel.playerNames[i])
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
                .foregroundColor(.white)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: i)
                .submitLabel(i < 3 ? .next : .done)
                .onSubmit {
                    DispatchQueue.main.async {
                        focusedField = i < 3 ? i + 1 : nil
                    }
                }
                .onChange(of: viewModel.playerNames[i]) { _, newValue in
                    if newValue.count > 10 {
                        viewModel.playerNames[i] = String(newValue.prefix(10))
                    }
                }
        }
    }

    // MARK: - Game Center authentication

    private func authenticateGameCenter() {
        let vm = viewModel
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            guard GKLocalPlayer.local.isAuthenticated else { return }
            DispatchQueue.main.async {
                vm.gameCenterPlayerID = GKLocalPlayer.local.playerID
                // Fill the currently-designated self slot with the GC display
                // name only if that slot is empty — don't overwrite a name the
                // user already typed.
                guard let idx = vm.selfPlayerIndex,
                      vm.playerNames.indices.contains(idx),
                      vm.playerNames[idx].trimmingCharacters(in: .whitespaces).isEmpty
                else { return }
                vm.playerNames[idx] = GKLocalPlayer.local.displayName
            }
        }
    }
}

#Preview {
    PlayerSetupView(viewModel: GameViewModel())
}
