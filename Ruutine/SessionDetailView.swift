import SwiftUI

struct SessionDetailView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let session: HistorySessionItem
    let isImperial: Bool
    let onSave: ([ExerciseLogUpdate]) async throws -> Void

    @State private var logs: [ExerciseLogDetail]
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var editWeightByLogId: [UUID: String] = [:]
    @State private var editRepsByLogId: [UUID: String] = [:]
    @State private var saveError: String?

    init(
        session: HistorySessionItem,
        logs: [ExerciseLogDetail],
        isImperial: Bool,
        onSave: @escaping ([ExerciseLogUpdate]) async throws -> Void
    ) {
        self.session = session
        self.isImperial = isImperial
        self.onSave = onSave
        _logs = State(initialValue: logs)
    }

    private var groupedExercises: [(name: String, sets: [ExerciseLogDetail])] {
        var groups: [String: [ExerciseLogDetail]] = [:]
        for log in logs {
            let name = log.exerciseName ?? "Unknown"
            groups[name, default: []].append(log)
        }
        return groups
            .map { (name: $0.key, sets: $0.value.sorted { ($0.setNumber ?? 0) < ($1.setNumber ?? 0) }) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sessionHeader

                    sectionHeader("EXERCISES")

                    if groupedExercises.isEmpty {
                        Text("No exercise logs for this session.")
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.muted)
                    } else {
                        ForEach(groupedExercises, id: \.name) { exercise in
                            exerciseCard(exercise)
                        }
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.system(size: 13))
                            .foregroundColor(RuutineColor.destructive)
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .background(RuutineColor.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button("Done") {
                dismiss()
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(RuutineColor.muted)
            .buttonStyle(.plain)

            Spacer()

            if isEditing {
                borderedToolbarButton("Cancel") {
                    cancelEditing()
                }

                accentToolbarButton(isSaving ? "Saving…" : "Save") {
                    Task { await saveEdits() }
                }
                .disabled(isSaving)
            } else {
                borderedToolbarButton("Edit") {
                    beginEditing()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RuutineColor.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RuutineColor.border)
                .frame(height: 1)
        }
    }

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(HistoryFormatting.detailDateLabel(session.date))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1.2)

            Text(session.sessionName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(RuutineColor.foreground)

            Text(HistoryFormatting.detailTimeLabel(session.date))
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(RuutineColor.muted)
            .tracking(1.2)
    }

    private func borderedToolbarButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(RuutineColor.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func accentToolbarButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(RuutineColor.accentForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RuutineColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func exerciseCard(_ exercise: (name: String, sets: [ExerciseLogDetail])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(RuutineColor.foreground)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                if isEditing {
                    editableSetRow(set, fallbackIndex: index)
                } else {
                    Text("Set \(set.setNumber ?? index + 1): \(HistoryFormatting.setLine(weightKg: set.weightKg, reps: set.reps, isImperial: isImperial))")
                        .font(.system(size: 13))
                        .foregroundColor(RuutineColor.muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RuutineColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func editableSetRow(_ set: ExerciseLogDetail, fallbackIndex: Int) -> some View {
        HStack(spacing: 8) {
            Text("Set \(set.setNumber ?? fallbackIndex + 1)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(RuutineColor.muted)
                .frame(width: 44, alignment: .leading)

            TextField(isImperial ? "lb" : "kg", text: weightBinding(for: set.id))
                .keyboardType(.decimalPad)
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RuutineColor.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity)

            TextField("reps", text: repsBinding(for: set.id))
                .keyboardType(.numberPad)
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RuutineColor.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity)
        }
    }

    private func weightBinding(for logId: UUID) -> Binding<String> {
        Binding(
            get: { editWeightByLogId[logId] ?? "" },
            set: { editWeightByLogId[logId] = $0 }
        )
    }

    private func repsBinding(for logId: UUID) -> Binding<String> {
        Binding(
            get: { editRepsByLogId[logId] ?? "" },
            set: { editRepsByLogId[logId] = $0 }
        )
    }

    private func beginEditing() {
        saveError = nil
        editWeightByLogId = Dictionary(uniqueKeysWithValues: logs.map { log in
            (log.id, weightDisplayString(for: log))
        })
        editRepsByLogId = Dictionary(uniqueKeysWithValues: logs.map { log in
            (log.id, log.reps.map(String.init) ?? "")
        })
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
        editWeightByLogId = [:]
        editRepsByLogId = [:]
        saveError = nil
    }

    private func saveEdits() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let updates = logs.map { log in
            ExerciseLogUpdate(
                id: log.id,
                weightKg: parseWeightText(editWeightByLogId[log.id] ?? ""),
                reps: parseRepsText(editRepsByLogId[log.id] ?? "")
            )
        }

        do {
            try await onSave(updates)
            logs = logs.map { log in
                guard let update = updates.first(where: { $0.id == log.id }) else { return log }
                return ExerciseLogDetail(
                    id: log.id,
                    sessionId: log.sessionId,
                    exerciseName: log.exerciseName,
                    weightKg: update.weightKg,
                    reps: update.reps,
                    setNumber: log.setNumber
                )
            }
            isEditing = false
            editWeightByLogId = [:]
            editRepsByLogId = [:]
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func weightDisplayString(for log: ExerciseLogDetail) -> String {
        guard let kg = log.weightKg else { return "" }
        let display = isImperial ? kg * 2.20462 : kg
        if display.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", display)
        }
        return String(format: "%.1f", display)
    }

    private func parseWeightText(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed) else { return nil }
        let kg = isImperial ? value / 2.20462 : value
        return (kg * 10).rounded() / 10
    }

    private func parseRepsText(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed) else { return nil }
        return value
    }
}

struct ExerciseLogUpdate {
    let id: UUID
    let weightKg: Double?
    let reps: Int?
}
