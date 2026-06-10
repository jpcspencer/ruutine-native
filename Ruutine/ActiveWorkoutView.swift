import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActiveWorkoutViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            timerBar
            exerciseList
            bottomBar
        }
        .background(Color.ruuBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.ruuMuted.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            ZStack {
                Text(viewModel.workoutName.uppercased())
                    .font(.ruuBebas(22))
                    .foregroundColor(.ruuForeground)
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
                            .foregroundColor(.ruuMuted)
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
                    .foregroundColor(.ruuMuted)
                    .tracking(1)

                Text(viewModel.elapsedFormatted)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.ruuForeground)
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
                .foregroundColor(viewModel.restSecondsRemaining != nil ? .ruuAccent : .ruuMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.ruuSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.ruuBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ruuBorder)
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
                    .foregroundColor(.ruuForeground)

                Spacer()

                Button {
                    viewModel.removeExercise(exercise)
                } label: {
                    Text("✕")
                        .font(.system(size: 16))
                        .foregroundColor(.ruuMuted)
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
                    .foregroundColor(.ruuAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.ruuSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ruuBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func setRow(
        exercise: WorkoutExercise,
        set: WorkoutSet,
        setNumber: Int,
        setIndex: Int
    ) -> some View {
        HStack(spacing: 8) {
            Text("Set \(setNumber)")
                .font(.system(size: 13))
                .foregroundColor(set.isConfirmed ? .ruuMuted : .ruuMuted)
                .frame(width: 44, alignment: .leading)

            workoutField(
                text: weightBinding(exerciseID: exercise.id, setID: set.id),
                placeholder: viewModel.placeholderWeight(for: exercise, setIndex: setIndex),
                width: 70,
                isConfirmed: set.isConfirmed
            )

            Text("kg")
                .font(.system(size: 12))
                .foregroundColor(.ruuMuted)

            workoutField(
                text: repsBinding(exerciseID: exercise.id, setID: set.id),
                placeholder: viewModel.placeholderReps(for: exercise, setIndex: setIndex),
                width: 60,
                isConfirmed: set.isConfirmed
            )

            Button {
                viewModel.toggleSetConfirmed(exerciseID: exercise.id, setID: set.id)
            } label: {
                ZStack {
                    Circle()
                        .stroke(set.isConfirmed ? Color.clear : Color.ruuMuted, lineWidth: 1.5)
                        .background(
                            Circle()
                                .fill(set.isConfirmed ? Color.ruuAccent : Color.clear)
                        )
                        .frame(width: 28, height: 28)

                    if set.isConfirmed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.ruuAccentForeground)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(set.weight.isEmpty || set.reps.isEmpty)
            .opacity(set.weight.isEmpty || set.reps.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    set.isConfirmed ? Color.ruuAccent.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
        .foregroundColor(set.isConfirmed ? .ruuMuted : .ruuForeground)
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
                    .foregroundColor(.ruuMuted.opacity(0.6))
            }

            TextField("", text: text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isConfirmed ? .ruuMuted : .ruuForeground)
                .multilineTextAlignment(.center)
                .keyboardType(width == 60 ? .numberPad : .decimalPad)
                .disabled(isConfirmed)
        }
        .frame(width: width, height: 36)
        .background(Color.ruuSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.ruuBorder, lineWidth: 1)
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
                    viewModel.addExercise()
                } label: {
                    Text("Add Exercise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.ruuAccentForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.ruuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity)

                if viewModel.hasConfirmedSet {
                    Button {
                        viewModel.finishWorkout()
                        dismiss()
                    } label: {
                        Text("Finish Session")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.ruuForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.ruuSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.ruuBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
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
            Color.ruuBackground
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.ruuBorder)
                        .frame(height: 1)
                }
        )
    }
}

#Preview {
    ActiveWorkoutView()
}
