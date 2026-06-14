import SwiftUI

enum WorkoutSetColumn {
    static let set: CGFloat = 26
    static let kg: CGFloat = 52
    static let reps: CGFloat = 44
    static let check: CGFloat = 28
    static let delete: CGFloat = 22
    static let spacing: CGFloat = 5
}

enum WorkoutFieldFocus: Hashable {
    case weight(exerciseID: UUID, setID: UUID)
    case reps(exerciseID: UUID, setID: UUID)
}

struct WorkoutSetColumnHeader: View {
    let weightLabel: String
    var showsDeleteColumn = false

    var body: some View {
        HStack(spacing: WorkoutSetColumn.spacing) {
            Text("Set")
                .frame(width: WorkoutSetColumn.set, alignment: .center)
            Text("Previous")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(weightLabel)
                .frame(width: WorkoutSetColumn.kg, alignment: .center)
            Text("Reps")
                .frame(width: WorkoutSetColumn.reps, alignment: .center)
            Text("✓")
                .frame(width: WorkoutSetColumn.check, alignment: .center)
            if showsDeleteColumn {
                Color.clear
                    .frame(width: WorkoutSetColumn.delete)
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(RuutineColor.muted)
        .textCase(.uppercase)
        .padding(.top, 2)
    }
}

struct WorkoutSetConfirmButton: View {
    let isConfirmed: Bool

    var body: some View {
        ZStack {
            if isConfirmed {
                Circle()
                    .fill(RuutineColor.accent)
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(RuutineColor.accentForeground)
            } else {
                Circle()
                    .stroke(RuutineColor.muted, lineWidth: 1.5)
                    .frame(width: 24, height: 24)
            }
        }
    }
}

struct WorkoutSetInputField: View {
    @Binding var text: String
    let placeholder: String
    let width: CGFloat
    let isConfirmed: Bool
    let keyboardType: UIKeyboardType
    let focus: WorkoutFieldFocus
    var focusedField: FocusState<WorkoutFieldFocus?>.Binding

    private var isFocused: Bool {
        focusedField.wrappedValue == focus
    }

    var body: some View {
        ZStack {
            if text.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted.opacity(0.55))
            }

            TextField("", text: $text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isConfirmed ? RuutineColor.muted : RuutineColor.foreground)
                .multilineTextAlignment(.center)
                .keyboardType(keyboardType)
                .disabled(isConfirmed)
                .focused(focusedField, equals: focus)
        }
        .frame(width: width, height: 30)
        .background(RuutineColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isFocused ? RuutineColor.accent : RuutineColor.border,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct WorkoutSetRowView: View {
    let setNumber: Int
    let previousText: String
    @Binding var weight: String
    @Binding var reps: String
    let weightPlaceholder: String
    let repsPlaceholder: String
    let isConfirmed: Bool
    let canConfirm: Bool
    let exerciseID: UUID
    let setID: UUID
    var showsDeleteButton = false
    let onToggleConfirm: () -> Void
    var onDelete: (() -> Void)?
    var focusedField: FocusState<WorkoutFieldFocus?>.Binding

    var body: some View {
        HStack(spacing: WorkoutSetColumn.spacing) {
            Text("\(setNumber)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isConfirmed ? RuutineColor.muted : RuutineColor.foreground)
                .frame(width: WorkoutSetColumn.set, height: 22)
                .background(RuutineColor.background)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(previousText)
                .font(.system(size: 11))
                .foregroundColor(RuutineColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            WorkoutSetInputField(
                text: $weight,
                placeholder: weightPlaceholder,
                width: WorkoutSetColumn.kg,
                isConfirmed: isConfirmed,
                keyboardType: .decimalPad,
                focus: .weight(exerciseID: exerciseID, setID: setID),
                focusedField: focusedField
            )

            WorkoutSetInputField(
                text: $reps,
                placeholder: repsPlaceholder,
                width: WorkoutSetColumn.reps,
                isConfirmed: isConfirmed,
                keyboardType: .numberPad,
                focus: .reps(exerciseID: exerciseID, setID: setID),
                focusedField: focusedField
            )

            Button(action: onToggleConfirm) {
                WorkoutSetConfirmButton(isConfirmed: isConfirmed)
            }
            .buttonStyle(.plain)
            .frame(width: WorkoutSetColumn.check)
            .opacity(canConfirm ? 1 : 0.4)

            if showsDeleteButton {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(RuutineColor.muted)
                }
                .buttonStyle(.plain)
                .frame(width: WorkoutSetColumn.delete)
            }
        }
        .padding(.vertical, 2)
    }
}

struct WorkoutExerciseEditorCard<SetRows: View>: View {
    let exerciseName: String
    var showsDragHandle = false
    var isDragging = false
    let showsDeleteColumn: Bool
    let weightLabel: String
    let hasSets: Bool
    let onRemoveExercise: () -> Void
    let onAddSet: () -> Void
    @ViewBuilder let setRows: () -> SetRows

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    if showsDragHandle {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(RuutineColor.muted)
                            .frame(width: 24, height: 24)
                    }

                    Text(exerciseName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(RuutineColor.foreground)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button(action: onRemoveExercise) {
                    Text("✕")
                        .font(.system(size: 16))
                        .foregroundColor(RuutineColor.muted)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            if hasSets {
                WorkoutSetColumnHeader(weightLabel: weightLabel, showsDeleteColumn: showsDeleteColumn)
            }

            setRows()

            Button(action: {
                Haptics.impact(.light)
                onAddSet()
            }) {
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
    }
}

struct WorkoutExerciseDragPreview<SetRows: View>: View {
    let exerciseName: String
    let weightLabel: String
    let hasSets: Bool
    @ViewBuilder let setRows: () -> SetRows

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(RuutineColor.muted)
                    .frame(width: 24, height: 24)

                Text(exerciseName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)
                    .lineLimit(2)

                Spacer()
            }

            if hasSets {
                WorkoutSetColumnHeader(weightLabel: weightLabel)
            }

            setRows()
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
}

struct WorkoutExerciseDropDelegate: DropDelegate {
    let targetExercise: WorkoutExercise
    let onMove: (UUID, UUID) -> Void
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
            onMove(draggedID, targetExercise.id)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedExerciseID = nil
        return true
    }

    func dropExited(info: DropInfo) {}
}
