import Auth
import SwiftUI
import UniformTypeIdentifiers

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel: ActiveWorkoutViewModel
    @State private var recapData: WorkoutRecapData?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showExercisePicker = false
    @State private var draggedExerciseID: UUID?
    @FocusState private var focusedField: WorkoutFieldFocus?

    var onWorkoutComplete: (() -> Void)?

    init(
        initialExercises: [WorkoutExercise]? = nil,
        workoutName: String? = nil,
        onWorkoutComplete: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: ActiveWorkoutViewModel(
                initialExercises: initialExercises,
                workoutName: workoutName
            )
        )
        self.onWorkoutComplete = onWorkoutComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            timerBar
            exerciseList
            bottomBar
        }
        .background(RuutineColor.background.ignoresSafeArea())
        .task(id: authVM.session?.user.id) {
            guard let userId = authVM.session?.user.id else { return }
            await viewModel.loadPreviousSets(userId: userId)
        }
        .fullScreenCover(item: $recapData) { data in
            WorkoutRecapView(data: data) {
                recapData = nil
                onWorkoutComplete?()
                dismiss()
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                viewModel.addExercise(exercise)
                if let userId = authVM.session?.user.id {
                    Task {
                        await viewModel.loadPreviousSets(for: exercise.name, userId: userId)
                    }
                }
            }
        }
        .alert("Couldn't Save Workout", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {
                saveError = nil
            }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(RuutineColor.muted.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            ZStack {
                Text(viewModel.workoutName.uppercased())
                    .font(.bebas(28))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 48)

                HStack {
                    Spacer()
                    Button {
                        print("Workout settings tapped")
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(RuutineColor.muted)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var timerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ELAPSED")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
                    .tracking(1)

                Text(viewModel.elapsedFormatted)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                viewModel.toggleRestTimer()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))

                    if viewModel.restSecondsRemaining != nil {
                        Text(viewModel.restFormatted)
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                    } else {
                        Text("Rest")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundColor(viewModel.restSecondsRemaining != nil ? RuutineColor.accent : RuutineColor.muted)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RuutineColor.border)
                .frame(height: 1)
        }
    }

    private var exerciseList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.exercises) { exercise in
                    exerciseCard(exercise)
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: ExerciseDropDelegate(
                                targetExercise: exercise,
                                viewModel: viewModel,
                                draggedExerciseID: $draggedExerciseID
                            )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
        }
    }

    private func exerciseCard(_ exercise: WorkoutExercise) -> some View {
        let isDragging = draggedExerciseID == exercise.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    dragHandleIcon

                    Text(exercise.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(RuutineColor.foreground)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button {
                    viewModel.removeExercise(exercise)
                } label: {
                    Text("✕")
                        .font(.system(size: 16))
                        .foregroundColor(RuutineColor.muted)
                        .frame(width: 28, height: 28)
                }
            }

            if !exercise.sets.isEmpty {
                setColumnHeader
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                setRow(exercise: exercise, set: set, setNumber: index + 1, setIndex: index)
            }

            Button {
                viewModel.addSet(to: exercise.id)
            } label: {
                Text("+ Add Set")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(RuutineColor.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDragging ? RuutineColor.accent.opacity(0.4) : RuutineColor.border,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isDragging ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onDrag {
            draggedExerciseID = exercise.id
            return NSItemProvider(object: exercise.id.uuidString as NSString)
        } preview: {
            exerciseDragPreview(exercise)
        }
    }

    private var setColumnHeader: some View {
        HStack(spacing: SetColumn.spacing) {
            Text("Set")
                .frame(width: SetColumn.set, alignment: .center)
            Text("Previous")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("kg")
                .frame(width: SetColumn.kg, alignment: .center)
            Text("Reps")
                .frame(width: SetColumn.reps, alignment: .center)
            Text("✓")
                .frame(width: SetColumn.check, alignment: .center)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(RuutineColor.muted)
        .textCase(.uppercase)
        .padding(.top, 4)
    }

    private func exerciseDragPreview(_ exercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                dragHandleIcon
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)
                    .lineLimit(2)
                Spacer()
            }

            if !exercise.sets.isEmpty {
                setColumnHeader
            }

            ForEach(Array(exercise.sets.prefix(3).enumerated()), id: \.element.id) { index, set in
                setRow(exercise: exercise, set: set, setNumber: index + 1, setIndex: index)
            }

            if exercise.sets.count > 3 {
                Text("+\(exercise.sets.count - 3) more sets")
                    .font(.system(size: 12))
                    .foregroundColor(RuutineColor.muted)
            }
        }
        .padding(12)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.accent.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .frame(maxWidth: UIScreen.main.bounds.width - 32)
    }

    private var dragHandleIcon: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(RuutineColor.muted)
            .frame(width: 28, height: 28)
    }

    private func setRow(
        exercise: WorkoutExercise,
        set: WorkoutSet,
        setNumber: Int,
        setIndex: Int
    ) -> some View {
        let isConfirmed = viewModel.isSetConfirmed(exerciseID: exercise.id, setID: set.id)
        let weight = viewModel.setWeight(exerciseID: exercise.id, setID: set.id)
        let reps = viewModel.setReps(exerciseID: exercise.id, setID: set.id)
        let weightPlaceholder = viewModel.placeholderWeight(for: exercise, setIndex: setIndex)
        let repsPlaceholder = viewModel.placeholderReps(for: exercise, setIndex: setIndex)
        let previousText = viewModel.previousSet(for: exercise.name, setIndex: setIndex)?.displayText ?? "—"
        let canConfirm = (!weight.isEmpty || !weightPlaceholder.isEmpty)
            && (!reps.isEmpty || !repsPlaceholder.isEmpty)
        let weightFocus = WorkoutFieldFocus.weight(exerciseID: exercise.id, setID: set.id)
        let repsFocus = WorkoutFieldFocus.reps(exerciseID: exercise.id, setID: set.id)

        return HStack(spacing: SetColumn.spacing) {
            Text("\(setNumber)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isConfirmed ? RuutineColor.muted : RuutineColor.foreground)
                .frame(width: SetColumn.set, height: 26)
                .background(RuutineColor.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(previousText)
                .font(.system(size: 11))
                .foregroundColor(RuutineColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            workoutField(
                text: weightBinding(exerciseID: exercise.id, setID: set.id),
                placeholder: weightPlaceholder,
                width: SetColumn.kg,
                isConfirmed: isConfirmed,
                keyboardType: .decimalPad,
                focus: weightFocus
            )

            workoutField(
                text: repsBinding(exerciseID: exercise.id, setID: set.id),
                placeholder: repsPlaceholder,
                width: SetColumn.reps,
                isConfirmed: isConfirmed,
                keyboardType: .numberPad,
                focus: repsFocus
            )

            Button {
                viewModel.toggleSetConfirmed(exerciseID: exercise.id, setID: set.id)
            } label: {
                confirmButton(isConfirmed: isConfirmed)
            }
            .buttonStyle(.plain)
            .frame(width: SetColumn.check)
            .opacity(canConfirm ? 1 : 0.4)
        }
        .padding(.vertical, 4)
    }

    private func confirmButton(isConfirmed: Bool) -> some View {
        ZStack {
            if isConfirmed {
                Circle()
                    .fill(RuutineColor.accent)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RuutineColor.accentForeground)
            } else {
                Circle()
                    .stroke(RuutineColor.muted, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
            }
        }
    }

    private func workoutField(
        text: Binding<String>,
        placeholder: String,
        width: CGFloat,
        isConfirmed: Bool,
        keyboardType: UIKeyboardType,
        focus: WorkoutFieldFocus
    ) -> some View {
        let isFocused = focusedField == focus

        return ZStack {
            if text.wrappedValue.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted.opacity(0.55))
            }

            TextField("", text: text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isConfirmed ? RuutineColor.muted : RuutineColor.foreground)
                .multilineTextAlignment(.center)
                .keyboardType(keyboardType)
                .disabled(isConfirmed)
                .focused($focusedField, equals: focus)
        }
        .frame(width: width, height: 34)
        .background(RuutineColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isFocused ? RuutineColor.accent : RuutineColor.border,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func weightBinding(exerciseID: UUID, setID: UUID) -> Binding<String> {
        Binding(
            get: {
                viewModel.exercises
                    .first(where: { $0.id == exerciseID })?
                    .sets.first(where: { $0.id == setID })?.weight ?? ""
            },
            set: { viewModel.updateSet(exerciseID: exerciseID, setID: setID, weight: $0) }
        )
    }

    private func repsBinding(exerciseID: UUID, setID: UUID) -> Binding<String> {
        Binding(
            get: {
                viewModel.exercises
                    .first(where: { $0.id == exerciseID })?
                    .sets.first(where: { $0.id == setID })?.reps ?? ""
            },
            set: { viewModel.updateSet(exerciseID: exerciseID, setID: setID, reps: $0) }
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                let spacing: CGFloat = 12
                let availableWidth = geometry.size.width
                let splitWidth = max(availableWidth - spacing, 0)

                HStack(spacing: spacing) {
                    Button {
                        showExercisePicker = true
                    } label: {
                        Text("Add Exercise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(RuutineColor.accentForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(RuutineColor.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(
                        width: viewModel.hasConfirmedSet ? splitWidth * 0.6 : availableWidth,
                        height: 48
                    )

                    if viewModel.hasConfirmedSet {
                        Button {
                            finishSession()
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .tint(RuutineColor.foreground)
                                } else {
                                    Text("Finish Session")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(RuutineColor.foreground)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(RuutineColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(RuutineColor.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isSaving)
                        .frame(width: splitWidth * 0.4, height: 48)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .frame(height: 48)
            .animation(.easeInOut(duration: 0.2), value: viewModel.hasConfirmedSet)

            Button {
                viewModel.cancelWorkout()
                dismiss()
            } label: {
                Text("Cancel Workout")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            RuutineColor.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RuutineColor.border)
                        .frame(height: 1)
                }
        )
    }

    private func finishSession() {
        guard let userId = authVM.session?.user.id,
              let payload = viewModel.buildCompletionPayload()
        else { return }

        isSaving = true
        Task {
            do {
                let recap = try await WorkoutSessionService.saveCompletedWorkout(
                    userId: userId,
                    sessionName: viewModel.workoutName,
                    durationSeconds: payload.durationSeconds,
                    exercises: payload.exercises
                )
                viewModel.finishWorkout()
                recapData = recap
            } catch {
                print("[ActiveWorkoutView] Finish Session save failed: \(error)")
                saveError = WorkoutSessionService.userFacingMessage(for: error)
            }
            isSaving = false
        }
    }
}

private enum SetColumn {
    static let set: CGFloat = 28
    static let kg: CGFloat = 56
    static let reps: CGFloat = 48
    static let check: CGFloat = 32
    static let spacing: CGFloat = 6
}

private enum WorkoutFieldFocus: Hashable {
    case weight(exerciseID: UUID, setID: UUID)
    case reps(exerciseID: UUID, setID: UUID)
}

private struct ExerciseDropDelegate: DropDelegate {
    let targetExercise: WorkoutExercise
    let viewModel: ActiveWorkoutViewModel
    @Binding var draggedExerciseID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        draggedExerciseID != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedExerciseID,
              draggedID != targetExercise.id
        else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.moveExercise(draggedID: draggedID, before: targetExercise.id)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedExerciseID = nil
        return true
    }

    func dropExited(info: DropInfo) {}
}

#Preview {
    ActiveWorkoutView()
        .environmentObject(AuthViewModel())
}
