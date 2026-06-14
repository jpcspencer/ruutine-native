import SwiftUI

struct WeightLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let isImperial: Bool
    let onSave: (Double) async throws -> Void

    @State private var weightInput = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Log your current bodyweight. It will appear on your chart and update your profile.")
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("WEIGHT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(RuutineColor.muted)
                        .tracking(1.2)

                    HStack(spacing: 8) {
                        TextField(isImperial ? "e.g. 180" : "e.g. 82", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 15))
                            .foregroundColor(RuutineColor.foreground)
                            .padding(14)
                            .background(RuutineColor.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(RuutineColor.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text(isImperial ? "lb" : "kg")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(RuutineColor.muted)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(RuutineColor.destructive)
                }

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(RuutineColor.accentForeground)
                        } else {
                            Text("Save Weight")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(RuutineColor.accentForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RuutineColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || weightInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .background(RuutineColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .ruutineNavigationChrome()
            .toolbar {
                RuutineToolbarItem(placement: .principal) {
                    Text("LOG WEIGHT")
                        .font(.bebas(22))
                        .tracking(1)
                }
                RuutineToolbarItem(placement: .topBarLeading) {
                    RuutineNavButton(kind: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() async {
        let trimmed = weightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            errorMessage = "Enter a valid weight."
            return
        }

        let weightKg = isImperial ? value / 2.20462 : value
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await onSave(weightKg)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
