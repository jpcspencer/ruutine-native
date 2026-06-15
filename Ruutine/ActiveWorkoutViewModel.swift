import Combine
import Foundation
import SwiftUI

struct WorkoutSet: Codable, Identifiable, Equatable {
    let id: UUID
    var weight: String
    var reps: String
    var durationSeconds: Int?
    var distanceM: Double?
    var timeEntryDigits: String
    var isConfirmed: Bool

    init(
        id: UUID = UUID(),
        weight: String = "",
        reps: String = "",
        durationSeconds: Int? = nil,
        distanceM: Double? = nil,
        timeEntryDigits: String = "",
        isConfirmed: Bool = false
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceM = distanceM
        self.timeEntryDigits = timeEntryDigits
        self.isConfirmed = isConfirmed
    }

    enum CodingKeys: String, CodingKey {
        case id, weight, reps, durationSeconds, distanceM, timeEntryDigits, isConfirmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        weight = try container.decode(String.self, forKey: .weight)
        reps = try container.decode(String.self, forKey: .reps)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceM = try container.decodeIfPresent(Double.self, forKey: .distanceM)
        timeEntryDigits = try container.decodeIfPresent(String.self, forKey: .timeEntryDigits) ?? ""
        isConfirmed = try container.decode(Bool.self, forKey: .isConfirmed)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(weight, forKey: .weight)
        try container.encode(reps, forKey: .reps)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(distanceM, forKey: .distanceM)
        try container.encode(timeEntryDigits, forKey: .timeEntryDigits)
        try container.encode(isConfirmed, forKey: .isConfirmed)
    }
}

struct WorkoutExercise: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var primaryMuscle: String?
    var category: ExerciseCategory
    var sets: [WorkoutSet]

    init(
        id: UUID = UUID(),
        name: String,
        primaryMuscle: String? = nil,
        category: ExerciseCategory = .barbell,
        sets: [WorkoutSet] = [WorkoutSet()]
    ) {
        self.id = id
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.category = category
        self.sets = sets
    }

    enum CodingKeys: String, CodingKey {
        case id, name, primaryMuscle, category, sets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        primaryMuscle = try container.decodeIfPresent(String.self, forKey: .primaryMuscle)
        category = try container.decodeIfPresent(ExerciseCategory.self, forKey: .category) ?? .barbell
        sets = try container.decode([WorkoutSet].self, forKey: .sets)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(primaryMuscle, forKey: .primaryMuscle)
        try container.encode(category, forKey: .category)
        try container.encode(sets, forKey: .sets)
    }
}

struct ActiveWorkoutState: Codable {
    var workoutName: String
    var exercises: [WorkoutExercise]
    var startedAt: Date
    var restSecondsRemaining: Int?
    var defaultRestSeconds: Int?
    var workoutNote: String?
    var workoutPhotoJPEGBase64: String?
}

@MainActor
final class ActiveWorkoutViewModel: ObservableObject {
    @Published var workoutName: String
    @Published var exercises: [WorkoutExercise]
    @Published var workoutNote: String = ""
    @Published var workoutPhotoData: Data?
    @Published var elapsedSeconds = 0
    @Published var restSecondsRemaining: Int?
    @Published private(set) var sessionDefaultRestSeconds: Int = RestDurationPreferences.defaultSeconds
    @Published var previousSetsByExercise: [String: [PreviousSetRecord]] = [:]
    @Published private(set) var hasConfirmedSet = false

    private(set) var startedAt: Date
    private var elapsedTimer: Timer?
    private var restTimer: Timer?

    private static let storageKey = "activeWorkoutState"

    var workoutDateSubtitle: String {
        Self.dateSubtitleFormatter.string(from: startedAt)
    }

    init(initialExercises: [WorkoutExercise]? = nil, workoutName initialWorkoutName: String? = nil) {
        let globalDefault = RestDurationPreferences.defaultSeconds
        sessionDefaultRestSeconds = globalDefault

        if let initialExercises {
            workoutName = initialWorkoutName ?? Self.defaultWorkoutName()
            exercises = initialExercises
            startedAt = Date()
            restSecondsRemaining = nil
            workoutNote = ""
            workoutPhotoData = nil
            persist()
        } else if let saved = Self.loadState() {
            workoutName = saved.workoutName
            exercises = saved.exercises
            startedAt = saved.startedAt
            restSecondsRemaining = saved.restSecondsRemaining
            sessionDefaultRestSeconds = saved.defaultRestSeconds ?? globalDefault
            workoutNote = saved.workoutNote ?? ""
            if let base64 = saved.workoutPhotoJPEGBase64 {
                workoutPhotoData = Data(base64Encoded: base64)
            }
        } else {
            workoutName = Self.defaultWorkoutName()
            exercises = []
            startedAt = Date()
            restSecondsRemaining = nil
        }

        updateElapsed()
        refreshHasConfirmedSet()
        startElapsedTimer()
        if let remaining = restSecondsRemaining {
            startRestTimer()
            RestTimerNotificationManager.scheduleRestEnd(
                at: Date().addingTimeInterval(TimeInterval(remaining))
            )
        }
        syncLiveActivity(startIfNeeded: true)
    }

    deinit {
        elapsedTimer?.invalidate()
        restTimer?.invalidate()
    }

    func toggleRestTimer() {
        if restSecondsRemaining != nil {
            stopRestTimer()
            persist()
            syncLiveActivity()
        } else {
            beginRest(seconds: sessionDefaultRestSeconds)
        }
    }

    func adjustActiveRest(by delta: Int) {
        guard restSecondsRemaining != nil else { return }

        let updatedDefault = max(RestDurationPreferences.minimumSeconds, sessionDefaultRestSeconds + delta)
        applySessionDefaultRestSeconds(updatedDefault)

        let updatedRemaining = max(0, (restSecondsRemaining ?? 0) + delta)
        if updatedRemaining == 0 {
            completeRestTimer()
        } else {
            restSecondsRemaining = updatedRemaining
            rescheduleRestEndNotification()
            persist()
            syncLiveActivity()
        }
    }

    func applyRestPreset(_ seconds: Int) {
        applySessionDefaultRestSeconds(seconds)

        if restSecondsRemaining != nil {
            restSecondsRemaining = seconds
            rescheduleRestEndNotification()
        }

        persist()
        syncLiveActivity()
    }

    func setSessionDefaultRestSeconds(_ seconds: Int) {
        applySessionDefaultRestSeconds(seconds)
        persist()
    }

    private func applySessionDefaultRestSeconds(_ seconds: Int) {
        sessionDefaultRestSeconds = seconds
        RestDurationPreferences.defaultSeconds = seconds
    }

    func removeExercise(_ exercise: WorkoutExercise) {
        exercises.removeAll { $0.id == exercise.id }
        refreshHasConfirmedSet()
        persist()
        syncLiveActivity()
    }

    func moveExercise(draggedID: UUID, before targetID: UUID) {
        guard let from = exercises.firstIndex(where: { $0.id == draggedID }),
              let to = exercises.firstIndex(where: { $0.id == targetID }),
              from != to
        else { return }

        exercises.move(
            fromOffsets: IndexSet(integer: from),
            toOffset: to > from ? to + 1 : to
        )
        Haptics.impact(.medium)
        persist()
        syncLiveActivity()
    }

    func addSet(to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[index].sets.append(WorkoutSet())
        persist()
        syncLiveActivity()
    }

    func removeSet(exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        exercises[exerciseIndex].sets.remove(at: setIndex)
        refreshHasConfirmedSet()
        persist()
        syncLiveActivity()
    }

    func updateSet(
        exerciseID: UUID,
        setID: UUID,
        weight: String? = nil,
        reps: String? = nil,
        durationSeconds: Int? = nil,
        distanceM: Double? = nil,
        isConfirmed: Bool? = nil
    ) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }

        if let weight {
            exercises[exerciseIndex].sets[setIndex].weight = weight
        }
        if let reps {
            exercises[exerciseIndex].sets[setIndex].reps = reps
        }
        if let durationSeconds {
            exercises[exerciseIndex].sets[setIndex].durationSeconds = durationSeconds
        }
        if let distanceM {
            exercises[exerciseIndex].sets[setIndex].distanceM = distanceM
        }
        if let isConfirmed {
            exercises[exerciseIndex].sets[setIndex].isConfirmed = isConfirmed
            refreshHasConfirmedSet()
        }
        persist()
    }

    func updateSetTime(exerciseID: UUID, setID: UUID, digits: String, durationSeconds: Int?) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }

        exercises[exerciseIndex].sets[setIndex].timeEntryDigits = digits
        exercises[exerciseIndex].sets[setIndex].durationSeconds = durationSeconds
        persist()
    }

    func toggleSetConfirmed(exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }

        let exercise = exercises[exerciseIndex]

        if exercises[exerciseIndex].sets[setIndex].isConfirmed {
            exercises[exerciseIndex].sets[setIndex].isConfirmed = false
        } else {
            let canConfirm = WorkoutSetConfirmLogic.prepareForConfirm(
                set: &exercises[exerciseIndex].sets[setIndex],
                inputKind: exercise.category.inputKind,
                weightPlaceholder: placeholderWeight(for: exercise, setIndex: setIndex),
                repsPlaceholder: placeholderReps(for: exercise, setIndex: setIndex),
                durationPlaceholderSeconds: placeholderDurationSeconds(for: exercise, setIndex: setIndex),
                distancePlaceholderMeters: placeholderDistanceMeters(for: exercise, setIndex: setIndex)
            )
            guard canConfirm else { return }

            exercises[exerciseIndex].sets[setIndex].isConfirmed = true
            Haptics.impact(.medium)
            SoundFX.setComplete()
        }

        refreshHasConfirmedSet()
        persist()
        syncLiveActivity()
    }

    func isSetConfirmed(exerciseID: UUID, setID: UUID) -> Bool {
        exercises
            .first(where: { $0.id == exerciseID })?
            .sets.first(where: { $0.id == setID })?
            .isConfirmed ?? false
    }

    func setWeight(exerciseID: UUID, setID: UUID) -> String {
        exercises
            .first(where: { $0.id == exerciseID })?
            .sets.first(where: { $0.id == setID })?
            .weight ?? ""
    }

    func setReps(exerciseID: UUID, setID: UUID) -> String {
        exercises
            .first(where: { $0.id == exerciseID })?
            .sets.first(where: { $0.id == setID })?
            .reps ?? ""
    }

    func addExercise(_ exercise: Exercise) {
        exercises.append(
            WorkoutExercise(
                name: exercise.name,
                primaryMuscle: exercise.primaryMuscle,
                category: exercise.category
            )
        )
        persist()
        syncLiveActivity(startIfNeeded: true)
    }

    func loadPreviousSets(userId: UUID) async {
        var updated = previousSetsByExercise
        for exercise in exercises {
            guard updated[exercise.name] == nil else { continue }
            let records = await PreviousSetsService.fetchPreviousSets(
                for: exercise.name,
                userId: userId
            )
            if !records.isEmpty {
                updated[exercise.name] = records
            }
        }
        previousSetsByExercise = updated
    }

    func loadPreviousSets(for exerciseName: String, userId: UUID) async {
        let records = await PreviousSetsService.fetchPreviousSets(
            for: exerciseName,
            userId: userId
        )
        guard !records.isEmpty else { return }
        previousSetsByExercise[exerciseName] = records
    }

    func previousSet(for exerciseName: String, setIndex: Int) -> PreviousSetRecord? {
        guard let sets = previousSetsByExercise[exerciseName],
              setIndex < sets.count
        else { return nil }
        return sets[setIndex]
    }

    func applySettings(name: String, note: String, startTime: Date, photoData: Data?) {
        workoutName = name
        workoutNote = note
        startedAt = startTime
        workoutPhotoData = photoData
        updateElapsed()
        persist()
    }

    func cancelWorkout() {
        endLiveActivity()
        clearPersistence()
    }

    func buildCompletionPayload() -> (
        exercises: [CompletedExercisePayload],
        totalVolume: Double,
        totalSets: Int,
        durationSeconds: Int
    )? {
        var totalVolume = 0.0
        var totalSets = 0
        var completedExercises: [CompletedExercisePayload] = []

        for exercise in exercises {
            var confirmedSets: [CompletedSetPayload] = []

            for (setIndex, set) in exercise.sets.enumerated() where set.isConfirmed {
                guard let payload = WorkoutSetPersistence.completedSetPayload(
                    from: set,
                    setNumber: confirmedSets.count + 1,
                    inputKind: exercise.category.inputKind,
                    weightPlaceholder: placeholderWeight(for: exercise, setIndex: setIndex),
                    repsPlaceholder: placeholderReps(for: exercise, setIndex: setIndex)
                ) else { continue }

                if let weightKg = payload.weightKg, let reps = payload.reps {
                    totalVolume += weightKg * Double(reps)
                }
                totalSets += 1
                confirmedSets.append(payload)
            }

            if !confirmedSets.isEmpty {
                completedExercises.append(
                    CompletedExercisePayload(
                        name: exercise.name,
                        primaryMuscle: exercise.primaryMuscle,
                        sets: confirmedSets
                    )
                )
            }
        }

        guard totalSets > 0 else { return nil }

        return (completedExercises, totalVolume, totalSets, elapsedSeconds)
    }

    func finishWorkout() {
        elapsedTimer?.invalidate()
        restTimer?.invalidate()
        endLiveActivity()
        clearPersistence()
    }

    func placeholderWeight(for exercise: WorkoutExercise, setIndex: Int) -> String {
        if let previous = previousSet(for: exercise.name, setIndex: setIndex),
           !previous.weightPlaceholder.isEmpty {
            return previous.weightPlaceholder
        }
        if setIndex > 0 {
            let previous = exercise.sets[setIndex - 1]
            if previous.isConfirmed, !previous.weight.isEmpty {
                return previous.weight
            }
        }
        return exercise.sets.prefix(setIndex).last(where: { $0.isConfirmed && !$0.weight.isEmpty })?.weight ?? ""
    }

    func placeholderReps(for exercise: WorkoutExercise, setIndex: Int) -> String {
        if let previous = previousSet(for: exercise.name, setIndex: setIndex),
           !previous.repsPlaceholder.isEmpty {
            return previous.repsPlaceholder
        }
        if setIndex > 0 {
            let previous = exercise.sets[setIndex - 1]
            if previous.isConfirmed, !previous.reps.isEmpty {
                return previous.reps
            }
        }
        return exercise.sets.prefix(setIndex).last(where: { $0.isConfirmed && !$0.reps.isEmpty })?.reps ?? ""
    }

    func placeholderDurationSeconds(for exercise: WorkoutExercise, setIndex: Int) -> Int? {
        if setIndex > 0 {
            let previous = exercise.sets[setIndex - 1]
            if previous.isConfirmed, let seconds = previous.durationSeconds, seconds > 0 {
                return seconds
            }
        }
        return exercise.sets.prefix(setIndex).last(where: {
            $0.isConfirmed && ($0.durationSeconds ?? 0) > 0
        })?.durationSeconds
    }

    func placeholderDistanceMeters(for exercise: WorkoutExercise, setIndex: Int) -> Double? {
        if setIndex > 0 {
            let previous = exercise.sets[setIndex - 1]
            if previous.isConfirmed, let meters = previous.distanceM, meters > 0 {
                return meters
            }
        }
        return exercise.sets.prefix(setIndex).last(where: {
            $0.isConfirmed && ($0.distanceM ?? 0) > 0
        })?.distanceM
    }

    var elapsedFormatted: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var restFormatted: String {
        let remaining = restSecondsRemaining ?? 0
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsed()
            }
        }
    }

    private func updateElapsed() {
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(startedAt)))
    }

    private func beginRest(seconds: Int) {
        restSecondsRemaining = seconds
        startRestTimer()
        rescheduleRestEndNotification()
        persist()
        syncLiveActivity()
    }

    private func rescheduleRestEndNotification() {
        guard let remaining = restSecondsRemaining else { return }
        RestTimerNotificationManager.scheduleRestEnd(
            at: Date().addingTimeInterval(TimeInterval(remaining))
        )
    }

    private func completeRestTimer() {
        stopRestTimer()
        SoundFX.restEnd()
        Haptics.notify(.success)
        persist()
        syncLiveActivity()
    }

    private func stopRestTimer() {
        restSecondsRemaining = nil
        restTimer?.invalidate()
        restTimer = nil
        RestTimerNotificationManager.cancelRestEnd()
    }

    private func startRestTimer() {
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard let remaining = self.restSecondsRemaining else { return }
                if remaining <= 1 {
                    self.completeRestTimer()
                } else {
                    self.restSecondsRemaining = remaining - 1
                    self.persist()
                }
            }
        }
    }

    private func refreshHasConfirmedSet() {
        hasConfirmedSet = exercises.contains { exercise in
            exercise.sets.contains { $0.isConfirmed }
        }
    }

    private func persist() {
        let state = ActiveWorkoutState(
            workoutName: workoutName,
            exercises: exercises,
            startedAt: startedAt,
            restSecondsRemaining: restSecondsRemaining,
            defaultRestSeconds: sessionDefaultRestSeconds,
            workoutNote: workoutNote.isEmpty ? nil : workoutNote,
            workoutPhotoJPEGBase64: workoutPhotoData?.base64EncodedString()
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func clearPersistence() {
        RestTimerNotificationManager.cancelRestEnd()
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        elapsedTimer?.invalidate()
        restTimer?.invalidate()
    }

    private static func loadState() -> ActiveWorkoutState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ActiveWorkoutState.self, from: data)
    }

    static func defaultWorkoutName(for date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5...11:
            return "Morning Workout"
        case 12...16:
            return "Afternoon Workout"
        case 17...20:
            return "Evening Workout"
        default:
            return "Night Workout"
        }
    }

    private static let dateSubtitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    // MARK: - Live Activity

    private func syncLiveActivity(startIfNeeded: Bool = false) {
        if #available(iOS 16.1, *) {
            guard let state = makeLiveActivityContentState() else {
                WorkoutLiveActivityManager.shared.end()
                return
            }
            if startIfNeeded {
                WorkoutLiveActivityManager.shared.start(workoutName: workoutName, state: state)
            } else {
                WorkoutLiveActivityManager.shared.update(state)
            }
        }
    }

    private func endLiveActivity() {
        if #available(iOS 16.1, *) {
            WorkoutLiveActivityManager.shared.end()
        }
    }

    private func makeLiveActivityContentState() -> WorkoutActivityAttributes.ContentState? {
        guard !exercises.isEmpty else { return nil }

        let isResting = restSecondsRemaining != nil
        let restEndDate = isResting
            ? Date().addingTimeInterval(TimeInterval(restSecondsRemaining ?? 0))
            : nil

        for exercise in exercises {
            for (setIndex, set) in exercise.sets.enumerated() where !set.isConfirmed {
                return liveActivityContentState(
                    for: exercise,
                    setIndex: setIndex,
                    isResting: isResting,
                    restEndDate: restEndDate
                )
            }
        }

        if let lastExercise = exercises.last, !lastExercise.sets.isEmpty {
            return liveActivityContentState(
                for: lastExercise,
                setIndex: lastExercise.sets.count - 1,
                isResting: isResting,
                restEndDate: restEndDate
            )
        }

        return liveActivityContentState(
            for: exercises[0],
            setIndex: 0,
            isResting: isResting,
            restEndDate: restEndDate
        )
    }

    private func liveActivityContentState(
        for exercise: WorkoutExercise,
        setIndex: Int,
        isResting: Bool,
        restEndDate: Date?
    ) -> WorkoutActivityAttributes.ContentState {
        let set = exercise.sets[setIndex]
        let weightText = set.weight.isEmpty
            ? placeholderWeight(for: exercise, setIndex: setIndex)
            : set.weight
        let repsText = set.reps.isEmpty
            ? placeholderReps(for: exercise, setIndex: setIndex)
            : set.reps

        let weight = Double(weightText.trimmingCharacters(in: .whitespaces))
        let targetReps = Int(repsText.trimmingCharacters(in: .whitespaces))

        return WorkoutActivityAttributes.ContentState(
            exerciseName: exercise.name,
            currentSet: setIndex + 1,
            totalSets: exercise.sets.count,
            targetReps: targetReps,
            weight: weight,
            isResting: isResting,
            restEndDate: isResting ? restEndDate : nil
        )
    }

}
