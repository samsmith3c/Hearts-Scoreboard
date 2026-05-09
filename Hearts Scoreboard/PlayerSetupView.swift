//
//  PlayerSetupView.swift
//  Hearts Scoreboard
//

import SwiftUI

struct PlayerSetupView: View {
    @ObservedObject var viewModel: GameViewModel
    @FocusState private var focusedField: Int?

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

                // Player name fields
                VStack(spacing: 14) {
                    ForEach(0..<4) { i in
                        playerField(index: i)
                    }
                }
                .padding(.horizontal, 32)

                // Target score picker
                VStack(spacing: 8) {
                    Text("Target Score")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("Target Score", selection: $viewModel.targetScore) {
                        Text("50").tag(50)
                        Text("75").tag(75)
                        Text("100").tag(100)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 32)

                // Start Game button
                Button {
                    focusedField = nil
                    viewModel.startGame()
                } label: {
                    Text("Start Game")
                        .font(.headline)
                        .foregroundColor(feltGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(allFieldsFilled ? Color.white : Color.white.opacity(0.3))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .disabled(!allFieldsFilled)
                .animation(.easeInOut(duration: 0.2), value: allFieldsFilled)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button { focusedField = max(0, (focusedField ?? 0) - 1) } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled((focusedField ?? 0) == 0)

                Button { focusedField = min(3, (focusedField ?? 0) + 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled((focusedField ?? 0) == 3)

                Spacer()

                Button("Done") { focusedField = nil }
            }
        }
    }

    @ViewBuilder
    private func playerField(index i: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 20)

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
                    focusedField = i < 3 ? i + 1 : nil
                }
                .onChange(of: viewModel.playerNames[i]) { _, newValue in
                    if newValue.count > 10 {
                        viewModel.playerNames[i] = String(newValue.prefix(10))
                    }
                }
        }
    }
}

#Preview {
    PlayerSetupView(viewModel: GameViewModel())
}
