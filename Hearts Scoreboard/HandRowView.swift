//
//  HandRowView.swift
//  Hearts Scoreboard
//

import SwiftUI

struct HandRowView: View {
    let hand: [Int]
    let buttonColumnWidth: CGFloat
    let passDirection: String
    let moonShooterIndex: Int?
    let onSave: ([Int], Int?) -> Void

    @State private var isEditing = false
    @State private var editValues: [String] = []
    @FocusState private var focusedField: Int?

    var body: some View {
        HStack(spacing: 4) {
            // Pass direction — left column mirrors home/x buttons in header
            Text(passDirection)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
                .frame(width: buttonColumnWidth)

            // Score columns
            ForEach(0..<hand.count, id: \.self) { i in
                if isEditing {
                    TextField("0", text: $editValues[i])
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.13))
                        .cornerRadius(7)
                        .focused($focusedField, equals: i)
                        .frame(maxWidth: 100)
                        .frame(maxWidth: .infinity)
                        .onChange(of: editValues[i]) { _, newValue in
                            let digits = newValue.filter { $0.isNumber }
                            if digits != newValue { editValues[i] = digits }
                        }
                } else {
                    Group {
                        if i == moonShooterIndex {
                            Text("🌙")
                        } else {
                            Text("\(hand[i])")
                                .foregroundColor(.white.opacity(0.78))
                        }
                    }
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
            }

            // Pencil / checkmark button — right side
            Button {
                if isEditing { handleSave() } else { startEditing() }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                    .font(isEditing ? .title3 : .caption)
                    .foregroundColor(
                        isEditing
                            ? (isValidEdit ? Color(hex: "4CD964") : .white.opacity(0.25))
                            : .white.opacity(0.3)
                    )
            }
            .disabled(isEditing && !isValidEdit)
            .frame(width: buttonColumnWidth)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .onSubmit { if isEditing && isValidEdit { handleSave() } }
    }

    // MARK: - Helpers

    private var isValidEdit: Bool {
        let vals = editValues.map { Int($0) ?? 0 }
        if vals.reduce(0, +) == 26 { return true }
        // Moon pattern B (all but one player at 26, one 0)
        return vals.filter { $0 == 26 }.count == vals.count - 1 && vals.filter { $0 == 0 }.count == 1
    }

    private func startEditing() {
        editValues = hand.map { String($0) }
        isEditing = true
        // Defer focus assignment so SwiftUI binds the field that just
        // appeared this render pass before we try to focus it.
        DispatchQueue.main.async {
            focusedField = 0
        }
    }

    private func handleSave() {
        let vals = editValues.map { Int($0) ?? 0 }
        var finalValues = vals
        var moonIdx: Int? = nil

        // Moon pattern A: shooter entered 26, others 0 → invert
        if vals.filter({ $0 == 26 }).count == 1 && vals.filter({ $0 == 0 }).count == vals.count - 1 {
            let idx = vals.firstIndex(of: 26)!
            finalValues = [Int](repeating: 26, count: vals.count)
            finalValues[idx] = 0
            moonIdx = idx
        }
        // Moon pattern B: all but one at 26, one 0 → already correct
        else if vals.filter({ $0 == 26 }).count == vals.count - 1 && vals.filter({ $0 == 0 }).count == 1 {
            moonIdx = vals.firstIndex(of: 0)
        }

        onSave(finalValues, moonIdx)
        isEditing = false
        // Same defer pattern — onSave + isEditing both mutate state in
        // this render pass, so the focus reset has to wait its turn.
        DispatchQueue.main.async {
            focusedField = nil
        }
    }
}

// What's next:
// - StatsView: GameHistoryCard / HandPreviewRow / GameDetailView columns from
//   the saved game's own player count.

#Preview {
    ZStack {
        feltGreen
        HandRowView(
            hand: [0, 26, 26, 26],
            buttonColumnWidth: 44,
            passDirection: "👈",
            moonShooterIndex: 0,
            onSave: { _, _ in }
        )
    }
}
