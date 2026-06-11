import Auth
import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel: ActiveWorkoutViewModel
    @State private var recapData: WorkoutRecapData?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showExercisePicker = false

    var onWorkoutComplete: (() -> Void)?

    init(initialExercises: [WorkoutExercise]? = nil, onWorkoutComplete: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ActiveWorkoutViewModel(initialExercises: initialExercises))
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

                    if let _ = viewModel.restSecondsRemaining {
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
        }
    }

    private func exerciseCard(_ exercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)

                Spacer()

                Button {
                    viewModel.removeExercise(exercise)
                } label: {
                    Text("✕")
                        .font(.system(size: 16))
                        .foregroundColor(RuutineColor.muted)
                        .frame(width: 28, height: 28)
                }
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
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        let canConfirm = (!weight.isEmpty || !weightPlaceholder.isEmpty)
            && (!reps.isEmpty || !repsPlaceholder.isEmpty)

        return HStack(spacing: 8) {
            Text("Set \(setNumber)")
                .font(.system(size: 13))
                .foregroundColor(RuutineColor.muted)
                .frame(width: 44, alignment: .leading)

            workoutField(
                text: weightBinding(exerciseID: exercise.id, setID: set.id),
                placeholder: weightPlaceholder,
                width: 70,
                isConfirmed: isConfirmed
            )

            Text("kg")
                .font(.system(size: 12))
                .foregroundColor(RuutineColor.muted)

            workoutField(
                text: repsBinding(exerciseID: exercise.id, setID: set.id),
                placeholder: repsPlaceholder,
                width: 60,
                isConfirmed: isConfirmed
            )

            Button {
                viewModel.toggleSetConfirmed(exerciseID: exercise.id, setID: set.id)
            } label: {
                confirmButton(isConfirmed: isConfirmed)
            }
            .buttonStyle(.plain)
            .opacity(canConfirm ? 1 : 0.4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isConfirmed ? RuutineColor.accent.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
        .foregroundColor(isConfirmed ? RuutineColor.muted : RuutineColor.foreground)
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
        isConfirmed: Bool
    ) -> some View {
        ZStack {
            if text.wrappedValue.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.muted.opacity(0.6))
            }

            TextField("", text: text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isConfirmed ? RuutineColor.muted : RuutineColor.foreground)
                .multilineTextAlignment(.center)
                .keyboardType(width == 60 ? .numberPad : .decimalPad)
                .disabled(isConfirmed)
        }
        .frame(width: width, height: 36)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RuutineColor.border, lineWidth: 1)
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
            HStack(spacing: 12) {
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
                .frame(maxWidth: .infinity)
                .layoutPriority(viewModel.hasConfirmedSet ? 6 : 1)

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
                    .frame(maxWidth: .infinity)
                    .layoutPriority(4)
                }
            }

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
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    ActiveWorkoutView()
        .environmentObject(AuthViewModel())
}
