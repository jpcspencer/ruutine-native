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
    case time(exerciseID: UUID, setID: UUID)
    case distance(exerciseID: UUID, setID: UUID)
}

enum WorkoutSetFieldFormatting {
    static func timeText(seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "" }
        return stopwatchDisplay(fromDigits: stopwatchDigits(fromDurationSeconds: seconds))
    }

    static func stopwatchDigits(fromDurationSeconds totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes == 0 {
            return seconds == 0 ? "" : String(seconds)
        }
        return "\(minutes)" + String(format: "%02d", seconds)
    }

    static func minutesAndSeconds(fromDigits digits: String) -> (minutes: Int, seconds: Int) {
        guard !digits.isEmpty else { return (0, 0) }

        let secondsPart = Int(digits.suffix(min(2, digits.count))) ?? 0
        let minutesPart = digits.count > 2 ? Int(digits.dropLast(2)) ?? 0 : 0

        var minutes = minutesPart
        var seconds = secondsPart
        if seconds >= 60 {
            minutes += seconds / 60
            seconds %= 60
        }
        return (minutes, seconds)
    }

    /// Raw digit-position display (no seconds rollover). Rollover applies only in `durationSeconds(fromStopwatchDigits:)`.
    static func stopwatchDisplay(fromDigits digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let secondsDigits = digits.suffix(min(2, digits.count))
        let seconds = String(format: "%02d", Int(secondsDigits) ?? 0)
        let minutes = digits.count > 2 ? String(digits.dropLast(2)) : "0"
        return "\(minutes):\(seconds)"
    }

    static func durationSeconds(fromStopwatchDigits digits: String) -> Int? {
        guard !digits.isEmpty else { return nil }
        let parts = minutesAndSeconds(fromDigits: digits)
        let total = parts.minutes * 60 + parts.seconds
        return total > 0 ? total : nil
    }

    /// Idempotent right-to-left stopwatch input: extract digits, strip leading zeros, cap at 6.
    static func parseStopwatchInput(_ newText: String) -> (digits: String, durationSeconds: Int?) {
        var digits = String(newText.filter(\.isNumber))
        digits = String(digits.drop(while: { $0 == "0" }))
        if digits.count > 6 {
            digits = String(digits.suffix(6))
        }
        return (digits, durationSeconds(fromStopwatchDigits: digits))
    }

    static func timeDisplayText(for set: WorkoutSet) -> String {
        if !set.timeEntryDigits.isEmpty {
            return stopwatchDisplay(fromDigits: set.timeEntryDigits)
        }
        if let seconds = set.durationSeconds, seconds > 0 {
            return timeText(seconds: seconds)
        }
        return ""
    }

    static func distanceText(meters: Double?) -> String {
        guard let meters, meters > 0 else { return "" }
        let km = meters / 1000
        if km == km.rounded() {
            return String(format: "%.0f", km)
        }
        var formatted = String(format: "%.2f", km)
        while formatted.contains(".") && (formatted.hasSuffix("0") || formatted.hasSuffix(".")) {
            formatted.removeLast()
        }
        return formatted
    }

    static func parseDistanceText(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let km = Double(trimmed), km >= 0 else { return nil }
        return km * 1000
    }
}

enum WorkoutSetConfirmLogic {
    private static func hasText(_ value: String, placeholder: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !placeholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func canConfirm(
        inputKind: InputKind,
        weight: String,
        weightPlaceholder: String,
        reps: String,
        repsPlaceholder: String,
        time: String,
        timePlaceholder: String,
        distance: String,
        distancePlaceholder: String
    ) -> Bool {
        switch inputKind {
        case .weightReps, .addedWeightReps, .assistedReps:
            return hasText(weight, placeholder: weightPlaceholder)
                && hasText(reps, placeholder: repsPlaceholder)
        case .repsOnly:
            return hasText(reps, placeholder: repsPlaceholder)
        case .cardio:
            return hasText(time, placeholder: timePlaceholder)
                || hasText(distance, placeholder: distancePlaceholder)
        case .duration:
            return hasText(time, placeholder: timePlaceholder)
        }
    }

    static func prepareForConfirm(
        set: inout WorkoutSet,
        inputKind: InputKind,
        weightPlaceholder: String,
        repsPlaceholder: String,
        durationPlaceholderSeconds: Int?,
        distancePlaceholderMeters: Double?
    ) -> Bool {
        switch inputKind {
        case .weightReps, .addedWeightReps, .assistedReps:
            if set.weight.isEmpty, !weightPlaceholder.isEmpty {
                set.weight = weightPlaceholder
            }
            if set.reps.isEmpty, !repsPlaceholder.isEmpty {
                set.reps = repsPlaceholder
            }
            return !set.weight.isEmpty && !set.reps.isEmpty

        case .repsOnly:
            if set.reps.isEmpty, !repsPlaceholder.isEmpty {
                set.reps = repsPlaceholder
            }
            return !set.reps.isEmpty

        case .cardio:
            if (set.durationSeconds ?? 0) <= 0, let durationPlaceholderSeconds, durationPlaceholderSeconds > 0 {
                set.durationSeconds = durationPlaceholderSeconds
            }
            if (set.distanceM ?? 0) <= 0, let distancePlaceholderMeters, distancePlaceholderMeters > 0 {
                set.distanceM = distancePlaceholderMeters
            }
            let hasTime = (set.durationSeconds ?? 0) > 0
            let hasDistance = (set.distanceM ?? 0) > 0
            return hasTime || hasDistance

        case .duration:
            if (set.durationSeconds ?? 0) <= 0, let durationPlaceholderSeconds, durationPlaceholderSeconds > 0 {
                set.durationSeconds = durationPlaceholderSeconds
            }
            return (set.durationSeconds ?? 0) > 0
        }
    }
}

extension InputKind {
    func weightColumnLabel(unit: String) -> String {
        switch self {
        case .weightReps:
            return unit
        case .addedWeightReps:
            return "+\(unit)"
        case .assistedReps:
            return "−\(unit)"
        default:
            return unit
        }
    }
}

struct WorkoutSetColumnHeader: View {
    let inputKind: InputKind
    var weightColumnLabel: String = "kg"
    var showsDeleteColumn = false

    private var primaryLabel: String? {
        switch inputKind {
        case .weightReps, .addedWeightReps, .assistedReps:
            return inputKind.weightColumnLabel(unit: weightColumnLabel)
        case .repsOnly:
            return nil
        case .cardio, .duration:
            return "Time"
        }
    }

    private var secondaryLabel: String? {
        switch inputKind {
        case .weightReps, .addedWeightReps, .assistedReps, .repsOnly:
            return "Reps"
        case .cardio:
            return "km"
        case .duration:
            return nil
        }
    }

    var body: some View {
        HStack(spacing: WorkoutSetColumn.spacing) {
            Text("Set")
                .frame(width: WorkoutSetColumn.set, alignment: .center)
            Text("Previous")
                .frame(maxWidth: .infinity, alignment: .leading)

            if let primaryLabel {
                Text(primaryLabel)
                    .frame(width: WorkoutSetColumn.kg, alignment: .center)
            }

            if let secondaryLabel {
                Text(secondaryLabel)
                    .frame(width: secondaryFieldWidth, alignment: .center)
            }

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

    private var secondaryFieldWidth: CGFloat {
        inputKind == .repsOnly
            ? WorkoutSetColumn.kg + WorkoutSetColumn.spacing + WorkoutSetColumn.reps
            : WorkoutSetColumn.reps
    }
}

struct WorkoutSetConfirmButton: View {
    let isConfirmed: Bool

    private let cornerRadius: CGFloat = 7

    var body: some View {
        ZStack {
            if isConfirmed {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(RuutineColor.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(RuutineColor.accentForeground)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(RuutineColor.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(RuutineColor.border, lineWidth: 1)
                    )
            }
        }
        .frame(width: WorkoutSetColumn.check, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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

struct WorkoutSetTimeInputField: View {
    @Binding var digits: String
    let durationSeconds: Int?
    let placeholder: String
    let width: CGFloat
    let isConfirmed: Bool
    let focus: WorkoutFieldFocus
    var focusedField: FocusState<WorkoutFieldFocus?>.Binding

    private var isFocused: Bool {
        focusedField.wrappedValue == focus
    }

    private var overlayText: String {
        if !digits.isEmpty {
            return WorkoutSetFieldFormatting.stopwatchDisplay(fromDigits: digits)
        }
        if let durationSeconds, durationSeconds > 0 {
            return WorkoutSetFieldFormatting.timeText(seconds: durationSeconds)
        }
        return ""
    }

    var body: some View {
        ZStack {
            if overlayText.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted.opacity(0.55))
            } else if !overlayText.isEmpty {
                Text(overlayText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isConfirmed ? RuutineColor.muted : RuutineColor.foreground)
            }

            TextField("", text: $digits)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.clear)
                .tint(.clear)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
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

struct SwipeableSetRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var isHorizontalSwipe = false
    @State private var rowWidth: CGFloat = 0
    @State private var isCommittingDelete = false

    private var commitThreshold: CGFloat {
        max(130, rowWidth * 0.55)
    }

    private var isPastThreshold: Bool {
        abs(dragOffset) >= commitThreshold
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack {
                    RuutineColor.destructive.opacity(isPastThreshold ? 1 : 0.88)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(isPastThreshold ? 1.12 : 1)
                        .animation(.easeInOut(duration: 0.15), value: isPastThreshold)
                }
                .frame(width: max(abs(dragOffset), 0))
            }

            content()
                .background(RuutineColor.surface)
                .offset(x: dragOffset)
                .gesture(deleteDragGesture)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { rowWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        rowWidth = newWidth
                    }
            }
        )
        .clipped()
    }

    private var deleteDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !isCommittingDelete else { return }

                if !isHorizontalSwipe {
                    let width = value.translation.width
                    let height = value.translation.height
                    guard abs(width) > abs(height), width < 0 else { return }
                    isHorizontalSwipe = true
                }

                dragOffset = min(0, value.translation.width)
            }
            .onEnded { _ in
                guard isHorizontalSwipe else { return }
                isHorizontalSwipe = false

                let threshold = max(130, rowWidth * 0.55)
                if abs(dragOffset) >= threshold {
                    isCommittingDelete = true
                    let offScreen = -(rowWidth + 48)
                    withAnimation(.easeInOut(duration: 0.22)) {
                        dragOffset = offScreen
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        Haptics.impact(.medium)
                        onDelete()
                    }
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

struct WorkoutSetRowView: View {
    let inputKind: InputKind
    let setNumber: Int
    let previousText: String
    @Binding var weight: String
    @Binding var reps: String
    @Binding var time: String
    @Binding var distance: String
    let timeDurationSeconds: Int?
    let weightPlaceholder: String
    let repsPlaceholder: String
    let timePlaceholder: String
    let distancePlaceholder: String
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

            primaryField
            secondaryField

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

    @ViewBuilder
    private var primaryField: some View {
        switch inputKind {
        case .weightReps, .addedWeightReps, .assistedReps:
            WorkoutSetInputField(
                text: $weight,
                placeholder: weightPlaceholder,
                width: WorkoutSetColumn.kg,
                isConfirmed: isConfirmed,
                keyboardType: .decimalPad,
                focus: .weight(exerciseID: exerciseID, setID: setID),
                focusedField: focusedField
            )
        case .repsOnly:
            EmptyView()
        case .cardio, .duration:
            WorkoutSetTimeInputField(
                digits: $time,
                durationSeconds: timeDurationSeconds,
                placeholder: timePlaceholder,
                width: WorkoutSetColumn.kg,
                isConfirmed: isConfirmed,
                focus: .time(exerciseID: exerciseID, setID: setID),
                focusedField: focusedField
            )
        }
    }

    @ViewBuilder
    private var secondaryField: some View {
        switch inputKind {
        case .weightReps, .addedWeightReps, .assistedReps:
            WorkoutSetInputField(
                text: $reps,
                placeholder: repsPlaceholder,
                width: WorkoutSetColumn.reps,
                isConfirmed: isConfirmed,
                keyboardType: .numberPad,
                focus: .reps(exerciseID: exerciseID, setID: setID),
                focusedField: focusedField
            )
        case .repsOnly:
            WorkoutSetInputField(
                text: $reps,
                placeholder: repsPlaceholder,
                width: WorkoutSetColumn.kg + WorkoutSetColumn.spacing + WorkoutSetColumn.reps,
                isConfirmed: isConfirmed,
                keyboardType: .numberPad,
                focus: .reps(exerciseID: exerciseID, setID: setID),
                focusedField: focusedField
            )
        case .cardio:
            WorkoutSetInputField(
                text: $distance,
                placeholder: distancePlaceholder,
                width: WorkoutSetColumn.reps,
                isConfirmed: isConfirmed,
                keyboardType: .decimalPad,
                focus: .distance(exerciseID: exerciseID, setID: setID),
                focusedField: focusedField
            )
        case .duration:
            EmptyView()
        }
    }
}

struct WorkoutExerciseEditorCard<SetRows: View>: View {
    let exerciseName: String
    var showsDragHandle = false
    var isDragging = false
    let showsDeleteColumn: Bool
    let inputKind: InputKind
    var weightColumnLabel: String = "kg"
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
                WorkoutSetColumnHeader(
                    inputKind: inputKind,
                    weightColumnLabel: weightColumnLabel,
                    showsDeleteColumn: showsDeleteColumn
                )
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
    let inputKind: InputKind
    var weightColumnLabel: String = "kg"
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
                WorkoutSetColumnHeader(inputKind: inputKind, weightColumnLabel: weightColumnLabel)
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
