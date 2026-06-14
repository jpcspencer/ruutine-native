import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let profile: ProfileDetail
    let onSave: (ProfileEditDraft) async throws -> Void

    @State private var draft: ProfileEditDraft
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let goalOptions = Array(ProfileLabels.goals.keys).sorted()
    private let experienceOptions = Array(ProfileLabels.experienceLevels.keys).sorted()
    private let equipmentOptions = Array(ProfileLabels.equipment.keys).sorted()

    init(
        profile: ProfileDetail,
        onSave: @escaping (ProfileEditDraft) async throws -> Void
    ) {
        self.profile = profile
        self.onSave = onSave
        _draft = State(initialValue: ProfileEditDraft(from: profile))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldSection(title: "NAME") {
                        textField("Your name", text: $draft.name)
                    }

                    fieldSection(title: "GOAL") {
                        chipGrid(goalOptions) { key in
                            ProfileLabels.goal(key)
                        } isSelected: { draft.goal == $0 } onSelect: { draft.goal = $0 }
                    }

                    fieldSection(title: "EXPERIENCE") {
                        chipGrid(experienceOptions) { key in
                            ProfileLabels.experience(key)
                        } isSelected: { draft.experienceLevel == $0 } onSelect: { draft.experienceLevel = $0 }
                    }

                    fieldSection(title: "DAYS PER WEEK") {
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { dayCount in
                                dayCountChip(dayCount)
                            }
                        }
                    }

                    fieldSection(title: "TRAINING DAYS") {
                        ProfileChipFlowLayout(spacing: 8) {
                            ForEach(Array(ProfileLabels.weekdayLabels.enumerated()), id: \.offset) { index, label in
                                trainingDayChip(day: index + 1, label: label)
                            }
                        }
                    }

                    fieldSection(title: "EQUIPMENT") {
                        chipGrid(equipmentOptions) { key in
                            ProfileLabels.equipment[key] ?? key
                        } isSelected: { draft.equipmentAccess.contains($0) } onSelect: { toggleEquipment($0) }
                    }

                    fieldSection(title: "INJURIES / LIMITATIONS") {
                        TextField("None", text: $draft.injuriesLimitations, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.system(size: 15))
                            .foregroundColor(RuutineColor.foreground)
                            .padding(14)
                            .background(RuutineColor.background)
                            .overlay(fieldBorder)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    fieldSection(title: "HEIGHT") {
                        HStack(spacing: 8) {
                            unitChip("Metric", isActive: !draft.isImperial) {
                                draft.unitPreference = "metric"
                            }
                            unitChip("Imperial", isActive: draft.isImperial) {
                                draft.unitPreference = "imperial"
                            }
                        }

                        if draft.isImperial {
                            HStack(spacing: 12) {
                                textField("Feet", text: $draft.heightFeetText, keyboard: .numberPad)
                                textField("Inches", text: $draft.heightInchesText, keyboard: .numberPad)
                            }
                        } else {
                            textField("Height (cm)", text: $draft.heightCmText, keyboard: .decimalPad)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(RuutineColor.destructive)
                    }
                }
                .padding(20)
            }
            .background(RuutineColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT PROFILE")
                        .font(.bebas(22))
                        .tracking(1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    RuutineNavButton(kind: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    RuutineNavButton(kind: .save, isDisabled: isSaving || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        Task { await save() }
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await onSave(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleEquipment(_ id: String) {
        if draft.equipmentAccess.contains(id) {
            draft.equipmentAccess.removeAll { $0 == id }
        } else {
            draft.equipmentAccess.append(id)
        }
    }

    private func toggleTrainingDay(_ day: Int) {
        if draft.trainingDays.contains(day) {
            draft.trainingDays.removeAll { $0 == day }
        } else if draft.trainingDays.count < draft.daysPerWeek {
            draft.trainingDays.append(day)
            draft.trainingDays.sort()
        }
    }

    @ViewBuilder
    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1.2)
            content()
        }
    }

    private func textField(
        _ placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.system(size: 15))
            .foregroundColor(RuutineColor.foreground)
            .padding(14)
            .background(RuutineColor.background)
            .overlay(fieldBorder)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(RuutineColor.border, lineWidth: 1)
    }

    private func chipGrid(
        _ options: [String],
        label: @escaping (String) -> String,
        isSelected: @escaping (String) -> Bool,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        ProfileChipFlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(label(option))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected(option) ? RuutineColor.accentForeground : RuutineColor.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected(option) ? RuutineColor.accent : RuutineColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected(option) ? Color.clear : RuutineColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayCountChip(_ count: Int) -> some View {
        Button {
            draft.daysPerWeek = count
            if draft.trainingDays.count > count {
                draft.trainingDays = Array(draft.trainingDays.prefix(count))
            }
        } label: {
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(draft.daysPerWeek == count ? RuutineColor.accentForeground : RuutineColor.foreground)
                .frame(width: 36, height: 36)
                .background(draft.daysPerWeek == count ? RuutineColor.accent : RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(draft.daysPerWeek == count ? Color.clear : RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func trainingDayChip(day: Int, label: String) -> some View {
        let isSelected = draft.trainingDays.contains(day)
        let isDisabled = !isSelected && draft.trainingDays.count >= draft.daysPerWeek

        return Button {
            toggleTrainingDay(day)
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? RuutineColor.accentForeground : RuutineColor.foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isSelected ? RuutineColor.accent : RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func unitChip(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? RuutineColor.accentForeground : RuutineColor.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? RuutineColor.accent : RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? Color.clear : RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// Simple flow layout for profile edit chip rows.
private struct ProfileChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
