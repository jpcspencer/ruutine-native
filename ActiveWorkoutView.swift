import Auth
import SwiftUI
import UniformTypeIdentifiers

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel: ActiveWorkoutViewModel
    @State private var recapData: WorkoutRecapData?
    @State private var recapSaveError: String?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showExercisePicker = false
    @State private var showCancelConfirmation = false
    @State private var showWorkoutSettings = false
    @State private var showRestPresets = false
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
        ZStack {
            VStack(spacing: 0) {
                header
                timerBar
                exerciseList
                bottomBar
            }
            .background(RuutineColor.background.ignoresSafeArea())

            if showCancelConfirmation {
                cancelWorkoutDialog
            }
        }
        .task(id: authVM.session?.user.id) {
            guard let userId = authVM.session?.user.id else { return }
            await viewModel.loadPreviousSets(userId: userId)
        }
        .fullScreenCover(item: $recapData) { data in
            WorkoutRecapView(data: data, saveError: recapSaveError) {
                recapData = nil
                recapSaveError = nil
                onWorkoutComplete?()
                dismiss()
            }
        }
        .sheet(isPresented: $showWorkoutSettings) {
            WorkoutSettingsSheet(
                workoutName: viewModel.workoutName,
                note: viewModel.workoutNote,
                startedAt: viewModel.startedAt,
                photoData: viewModel.workoutPhotoData,
                restDurationSeconds: viewModel.sessionDefaultRestSeconds
            ) { name, note, startTime, photoData, restSeconds in
                viewModel.applySettings(
                    name: name,
                    note: note,
                    startTime: startTime,
                    photoData: photoData
                )
                viewModel.setSessionDefaultRestSeconds(restSeconds)
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercises in
                for exercise in exercises {
                    viewModel.addExercise(exercise)
                    if let userId = authVM.session?.user.id {
                        Task {
                            await viewModel.loadPreviousSets(for: exercise.name, userId: userId)
                        }
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
        .onChange(of: recapSaveError) { _, error in
            if error != nil { Haptics.notify(.error) }
        }
        .onChange(of: saveError) { _, error in
            if error != nil { Haptics.notify(.error) }
        }
        .confirmationDialog(
            "Rest duration",
            isPresented: $showRestPresets,
            titleVisibility: .visible
        ) {
            ForEach(RestDurationPreferences.presets, id: \.self) { seconds in
                Button(RestDurationPreferences.formatted(seconds)) {
                    Haptics.selection()
                    viewModel.applyRestPreset(seconds)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(RuutineColor.muted.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 6)

            ZStack {
                VStack(spacing: 2) {
                    Text(viewModel.workoutName.uppercased())
                        .font(.bebas(26))
                        .foregroundColor(RuutineColor.foreground)
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(viewModel.workoutDateSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(RuutineColor.muted)
                }
                .padding(.horizontal, 96)

                HStack(alignment: .center) {
                    RuutineNavButton(kind: .gear) {
                        showWorkoutSettings = true
                    }
                    .accessibilityLabel("Workout settings")

                    Spacer(minLength: 0)

                    if viewModel.hasConfirmedSet {
                        RuutineNavButton(kind: .finish(isLoading: isSaving)) {
                            finishSession()
                        }
                        .disabled(isSaving)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .animation(.easeInOut(duration: 0.2), value: viewModel.hasConfirmedSet)
        }
        .padding(.bottom, 6)
    }

    private var timerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ELAPSED")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
                    .tracking(1)

                Text(viewModel.elapsedFormatted)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)
                    .monospacedDigit()
            }

            Spacer()

            restButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RuutineColor.border)
                .frame(height: 1)
        }
    }

    private var exerciseList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(viewModel.exercises) { exercise in
                    exerciseCard(exercise)
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: WorkoutExerciseDropDelegate(
                                targetExercise: exercise,
                                onMove: { draggedID, targetID in
                                    viewModel.moveExercise(draggedID: draggedID, before: targetID)
                                },
                                draggedExerciseID: $draggedExerciseID
                            )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 6)
        }
    }

    private func exerciseCard(_ exercise: WorkoutExercise) -> some View {
        let isDragging = draggedExerciseID == exercise.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    dragHandleIcon

                    Text(exercise.name)
                        .font(.system(size: 15, weight: .bold))
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
                WorkoutSetColumnHeader(weightLabel: "kg")
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                setRow(exercise: exercise, set: set, setNumber: index + 1, setIndex: index)
            }

            Button {
                Haptics.impact(.light)
                viewModel.addSet(to: exercise.id)
            } label: {
                Text("+ Add Set")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(RuutineColor.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isDragging ? RuutineColor.accent.opacity(0.4) : RuutineColor.border,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isDragging ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onDrag {
            draggedExerciseID = exercise.id
            return NSItemProvider(object: exercise.id.uuidString as NSString)
        } preview: {
            exerciseDragPreview(exercise)
        }
    }

    private var setColumnHeader: some View {
        WorkoutSetColumnHeader(weightLabel: "kg")
    }

    private func exerciseDragPreview(_ exercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                dragHandleIcon
                Text(exercise.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)
                    .lineLimit(2)
                Spacer()
            }

            if !exercise.sets.isEmpty {
                WorkoutSetColumnHeader(weightLabel: "kg")
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
        .padding(10)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(RuutineColor.accent.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: RuutineColor.foreground.opacity(0.25), radius: 8, y: 3)
        .frame(maxWidth: UIScreen.main.bounds.width - 32)
    }

    private var dragHandleIcon: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(RuutineColor.muted)
            .frame(width: 24, height: 24)
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

        return WorkoutSetRowView(
            setNumber: setNumber,
            previousText: previousText,
            weight: weightBinding(exerciseID: exercise.id, setID: set.id),
            reps: repsBinding(exerciseID: exercise.id, setID: set.id),
            weightPlaceholder: weightPlaceholder,
            repsPlaceholder: repsPlaceholder,
            isConfirmed: isConfirmed,
            canConfirm: canConfirm,
            exerciseID: exercise.id,
            setID: set.id,
            onToggleConfirm: {
                viewModel.toggleSetConfirmed(exerciseID: exercise.id, setID: set.id)
            },
            focusedField: $focusedField
        )
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
        VStack(spacing: 8) {
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

            Button {
                showCancelConfirmation = true
            } label: {
                Text("Cancel Workout")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(RuutineColor.destructive)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RuutineColor.destructive.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(RuutineColor.destructive.opacity(0.85), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
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

    private var restButton: some View {
        Group {
            if viewModel.restSecondsRemaining != nil {
                HStack(spacing: 6) {
                    restAdjustButton("-15") {
                        Haptics.impact(.light)
                        viewModel.adjustActiveRest(by: -15)
                    }

                    Button {
                        showRestPresets = true
                    } label: {
                        Text(viewModel.restFormatted)
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(RuutineColor.accent)
                            .frame(minWidth: 44)
                    }
                    .buttonStyle(.plain)

                    restAdjustButton("+15") {
                        Haptics.impact(.light)
                        viewModel.adjustActiveRest(by: 15)
                    }

                    Button {
                        viewModel.toggleRestTimer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(RuutineColor.muted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop rest timer")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button {
                    viewModel.toggleRestTimer()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))

                        Text("Rest")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(RuutineColor.muted)
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
        }
    }

    private func restAdjustButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(RuutineColor.foreground)
                .frame(width: 36, height: 28)
                .background(RuutineColor.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var cancelWorkoutDialog: some View {
        ZStack {
            RuutineColor.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    showCancelConfirmation = false
                }

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Text("Cancel workout? Your progress won't be saved.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RuutineColor.foreground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button {
                            showCancelConfirmation = false
                        } label: {
                            Text("Keep Going")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(RuutineColor.foreground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RuutineColor.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(RuutineColor.border, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            showCancelConfirmation = false
                            viewModel.cancelWorkout()
                            dismiss()
                        } label: {
                            Text("Cancel Workout")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(RuutineColor.destructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RuutineColor.destructive.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(RuutineColor.destructive.opacity(0.85), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: showCancelConfirmation)
    }

    private func finishSession() {
        guard let userId = authVM.session?.user.id,
              let payload = viewModel.buildCompletionPayload()
        else { return }

        let workoutName = viewModel.workoutName
        let workoutNote = viewModel.workoutNote
        let workoutPhotoData = viewModel.workoutPhotoData

        let recap = WorkoutRecapData.fromCompletion(
            profileId: userId,
            sessionName: workoutName,
            durationSeconds: payload.durationSeconds,
            exercises: payload.exercises,
            totalVolumeKg: payload.totalVolume,
            totalSets: payload.totalSets,
            note: workoutNote,
            photoData: workoutPhotoData
        )

        recapSaveError = nil
        recapData = recap
        Haptics.notify(.success)
        SoundFX.workoutComplete()
        viewModel.finishWorkout()

        Task {
            do {
                _ = try await WorkoutSessionService.saveCompletedWorkout(
                    userId: userId,
                    profileId: userId,
                    sessionName: workoutName,
                    durationSeconds: payload.durationSeconds,
                    exercises: payload.exercises,
                    notes: workoutNote,
                    photoData: workoutPhotoData
                )
            } catch {
                print("[ActiveWorkoutView] Finish Session save failed: \(error)")
                recapSaveError = WorkoutSessionService.userFacingMessage(for: error)
            }
        }
    }
}

#Preview {
    ActiveWorkoutView()
        .environmentObject(AuthViewModel())
}
