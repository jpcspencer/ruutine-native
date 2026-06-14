import SwiftUI
import UniformTypeIdentifiers

struct SessionDetailView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let sessionId: UUID
    let isImperial: Bool
    let onSave: (SessionEditDraft) async throws -> Void

    @State private var displayedName: String
    @State private var displayedDate: Date
    @State private var displayedDurationSeconds: Int?
    @State private var logs: [ExerciseLogDetail]
    @State private var editState: SessionEditState
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showExercisePicker = false
    @State private var draggedExerciseID: UUID?
    @FocusState private var focusedField: WorkoutFieldFocus?

    init(
        session: HistorySessionItem,
        logs: [ExerciseLogDetail],
        isImperial: Bool,
        onSave: @escaping (SessionEditDraft) async throws -> Void
    ) {
        sessionId = session.id
        self.isImperial = isImperial
        self.onSave = onSave
        _displayedName = State(initialValue: session.sessionName)
        _displayedDate = State(initialValue: session.date)
        _displayedDurationSeconds = State(initialValue: session.durationSeconds)
        _logs = State(initialValue: logs)
        _editState = State(
            initialValue: SessionEditState(
                sessionName: session.sessionName,
                sessionDate: session.date,
                durationSeconds: session.durationSeconds,
                logs: logs,
                isImperial: isImperial
            )
        )
    }

    private var groupedExercises: [(name: String, sets: [ExerciseLogDetail])] {
        var groups: [String: [ExerciseLogDetail]] = [:]
        var order: [String] = []

        for log in logs {
            let name = log.exerciseName ?? "Unknown"
            if groups[name] == nil {
                order.append(name)
                groups[name] = []
            }
            groups[name]?.append(log)
        }

        return order.map { name in
            (
                name: name,
                sets: (groups[name] ?? []).sorted { ($0.setNumber ?? 0) < ($1.setNumber ?? 0) }
            )
        }
    }

    private var weightColumnLabel: String {
        isImperial ? "lb" : "kg"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sessionHeader

                    sectionHeader("EXERCISES")

                    if isEditing {
                        editExercisesList
                        addExerciseButton
                    } else if groupedExercises.isEmpty {
                        Text("No exercise logs for this session.")
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.muted)
                    } else {
                        ForEach(groupedExercises, id: \.name) { exercise in
                            readOnlyExerciseCard(exercise)
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
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                editState.addExercise(exercise)
            }
            .environmentObject(themeManager)
        }
        .onChange(of: saveError) { _, error in
            if error != nil { Haptics.notify(.error) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            RuutinePillButton(title: "Done", style: .tertiary) {
                dismiss()
            }

            Spacer()

            if isEditing {
                RuutinePillButton(title: "Cancel", style: .secondary) {
                    cancelEditing()
                }

                RuutinePillButton(
                    title: isSaving ? "Saving…" : "Save",
                    style: .primary,
                    isLoading: isSaving,
                    isDisabled: isSaving
                ) {
                    Task { await saveEdits() }
                }
            } else {
                RuutinePillButton(title: "Edit", style: .secondary) {
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

    @ViewBuilder
    private var sessionHeader: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("WORKOUT NAME")
                    TextField("Workout name", text: $editState.sessionName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(RuutineColor.foreground)
                        .padding(14)
                        .background(RuutineColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(RuutineColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("DATE")
                    datePickerField(
                        selection: $editState.sessionDay,
                        components: [.date]
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("START TIME")
                        datePickerField(
                            selection: $editState.startTime,
                            components: [.hourAndMinute]
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("END TIME")
                        datePickerField(
                            selection: $editState.endTime,
                            components: [.hourAndMinute]
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let durationSeconds = editState.derivedDurationSeconds {
                    HStack(spacing: 6) {
                        Text("Duration")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(RuutineColor.muted)
                        Text(HistoryFormatting.workoutLengthLabel(durationSeconds))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(RuutineColor.foreground)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(HistoryFormatting.detailDateLabel(displayedDate))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
                    .tracking(1.2)

                Text(displayedName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)

                Text(sessionTimeLine)
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.muted)
            }
        }
    }

    private var sessionTimeLine: String {
        let time = HistoryFormatting.detailTimeLabel(displayedDate)
        guard let durationSeconds = displayedDurationSeconds else {
            return time
        }
        return "\(time) · \(HistoryFormatting.workoutLengthLabel(durationSeconds))"
    }

    private func datePickerField(selection: Binding<Date>, components: DatePickerComponents) -> some View {
        DatePicker("", selection: selection, displayedComponents: components)
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(RuutineColor.accent)
            .padding(14)
            .background(RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var addExerciseButton: some View {
        Button {
            Haptics.impact(.light)
            showExercisePicker = true
        } label: {
            Text("Add Exercise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(RuutineColor.accentForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RuutineColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var editExercisesList: some View {
        if editState.exercises.isEmpty {
            Text("No exercises yet. Add one below.")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)
        } else {
            VStack(spacing: 10) {
                ForEach(editState.exercises) { exercise in
                    editExerciseCard(for: exercise)
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: WorkoutExerciseDropDelegate(
                                targetExercise: exercise,
                                onMove: { draggedID, targetID in
                                    editState.moveExercise(draggedID: draggedID, before: targetID)
                                },
                                draggedExerciseID: $draggedExerciseID
                            )
                        )
                }
            }
        }
    }

    private func editExerciseCard(for exercise: WorkoutExercise) -> some View {
        let isDragging = draggedExerciseID == exercise.id

        return WorkoutExerciseEditorCard(
            exerciseName: exercise.name,
            showsDragHandle: true,
            isDragging: isDragging,
            showsDeleteColumn: true,
            weightLabel: weightColumnLabel,
            hasSets: !exercise.sets.isEmpty,
            onRemoveExercise: {
                editState.removeExercise(exercise)
            },
            onAddSet: {
                editState.addSet(to: exercise.id)
            }
        ) {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                let isConfirmed = editState.isSetConfirmed(exerciseID: exercise.id, setID: set.id)
                let weightPlaceholder = editState.placeholderWeight(for: exercise, setIndex: index)
                let repsPlaceholder = editState.placeholderReps(for: exercise, setIndex: index)
                let canConfirm = (!set.weight.isEmpty || !weightPlaceholder.isEmpty)
                    && (!set.reps.isEmpty || !repsPlaceholder.isEmpty)

                WorkoutSetRowView(
                    setNumber: index + 1,
                    previousText: "—",
                    weight: weightBinding(exerciseID: exercise.id, setID: set.id),
                    reps: repsBinding(exerciseID: exercise.id, setID: set.id),
                    weightPlaceholder: weightPlaceholder,
                    repsPlaceholder: repsPlaceholder,
                    isConfirmed: isConfirmed,
                    canConfirm: canConfirm,
                    exerciseID: exercise.id,
                    setID: set.id,
                    showsDeleteButton: true,
                    onToggleConfirm: {
                        editState.toggleSetConfirmed(exerciseID: exercise.id, setID: set.id)
                    },
                    onDelete: {
                        editState.removeSet(exerciseID: exercise.id, setID: set.id)
                    },
                    focusedField: $focusedField
                )
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onDrag {
            draggedExerciseID = exercise.id
            return NSItemProvider(object: exercise.id.uuidString as NSString)
        } preview: {
            sessionExerciseDragPreview(exercise)
        }
    }

    private func sessionExerciseDragPreview(_ exercise: WorkoutExercise) -> some View {
        WorkoutExerciseDragPreview(
            exerciseName: exercise.name,
            weightLabel: weightColumnLabel,
            hasSets: !exercise.sets.isEmpty
        ) {
            ForEach(Array(exercise.sets.prefix(3).enumerated()), id: \.element.id) { index, set in
                Text("Set \(index + 1): \(HistoryFormatting.setLine(weightKg: HistoryFormatting.parseWeight(set.weight, isImperial: isImperial), reps: HistoryFormatting.parseReps(set.reps), isImperial: isImperial))")
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted)
            }

            if exercise.sets.count > 3 {
                Text("+\(exercise.sets.count - 3) more sets")
                    .font(.system(size: 12))
                    .foregroundColor(RuutineColor.muted)
            }
        }
    }

    private func readOnlyExerciseCard(_ exercise: (name: String, sets: [ExerciseLogDetail])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(RuutineColor.foreground)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 8) {
                    if set.completed == true {
                        WorkoutSetConfirmButton(isConfirmed: true)
                            .scaleEffect(0.75)
                    }

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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(RuutineColor.muted)
            .tracking(1.2)
    }

    private func weightBinding(exerciseID: UUID, setID: UUID) -> Binding<String> {
        Binding(
            get: {
                editState.exercises
                    .first(where: { $0.id == exerciseID })?
                    .sets.first(where: { $0.id == setID })?.weight ?? ""
            },
            set: { editState.updateSet(exerciseID: exerciseID, setID: setID, weight: $0) }
        )
    }

    private func repsBinding(exerciseID: UUID, setID: UUID) -> Binding<String> {
        Binding(
            get: {
                editState.exercises
                    .first(where: { $0.id == exerciseID })?
                    .sets.first(where: { $0.id == setID })?.reps ?? ""
            },
            set: { editState.updateSet(exerciseID: exerciseID, setID: setID, reps: $0) }
        )
    }

    private func beginEditing() {
        saveError = nil
        editState = SessionEditState(
            sessionName: displayedName,
            sessionDate: displayedDate,
            durationSeconds: displayedDurationSeconds,
            logs: logs,
            isImperial: isImperial
        )
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
        saveError = nil
        focusedField = nil
        draggedExerciseID = nil
    }

    private func saveEdits() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let draft = editState.draft

        do {
            try await onSave(draft)
            displayedName = draft.sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
            displayedDate = draft.sessionDate
            displayedDurationSeconds = draft.durationSeconds
            logs = SessionLogConverter.logs(
                from: draft,
                sessionId: sessionId,
                isImperial: isImperial
            )
            isEditing = false
            focusedField = nil
            draggedExerciseID = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}
