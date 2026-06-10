import Combine
import Foundation

struct WorkoutSet: Codable, Identifiable, Equatable {
    let id: UUID
    var weight: String
    var reps: String
    var isConfirmed: Bool

    init(id: UUID = UUID(), weight: String = "", reps: String = "", isConfirmed: Bool = false) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isConfirmed = isConfirmed
    }
}

struct WorkoutExercise: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var sets: [WorkoutSet]

    init(id: UUID = UUID(), name: String, sets: [WorkoutSet] = [WorkoutSet()]) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

struct ActiveWorkoutState: Codable {
    var workoutName: String
    var exercises: [WorkoutExercise]
    var startedAt: Date
    var restSecondsRemaining: Int?
}

@MainActor
final class ActiveWorkoutViewModel: ObservableObject {
    @Published var workoutName: String
    @Published var exercises: [WorkoutExercise]
    @Published var elapsedSeconds = 0
    @Published var restSecondsRemaining: Int?

    private var startedAt: Date
    private var elapsedTimer: Timer?
    private var restTimer: Timer?

    private static let storageKey = "activeWorkoutState"

    var hasConfirmedSet: Bool {
        exercises.contains { exercise in
            exercise.sets.contains { $0.isConfirmed }
        }
    }

    init() {
        if let saved = Self.loadState() {
            workoutName = saved.workoutName
            exercises = saved.exercises
            startedAt = saved.startedAt
            restSecondsRemaining = saved.restSecondsRemaining
        } else {
            workoutName = Self.defaultWorkoutName()
            exercises = Self.placeholderExercises()
            startedAt = Date()
            restSecondsRemaining = nil
        }

        updateElapsed()
        startElapsedTimer()
        if restSecondsRemaining != nil {
            startRestTimer()
        }
    }

    deinit {
        elapsedTimer?.invalidate()
        restTimer?.invalidate()
    }

    func toggleRestTimer() {
        if restSecondsRemaining != nil {
            restSecondsRemaining = nil
            restTimer?.invalidate()
            restTimer = nil
        } else {
            restSecondsRemaining = 90
            startRestTimer()
        }
        persist()
    }

    func removeExercise(_ exercise: WorkoutExercise) {
        exercises.removeAll { $0.id == exercise.id }
        persist()
    }

    func addSet(to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[index].sets.append(WorkoutSet())
        persist()
    }

    func updateSet(
        exerciseID: UUID,
        setID: UUID,
        weight: String? = nil,
        reps: String? = nil,
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
        if let isConfirmed {
            exercises[exerciseIndex].sets[setIndex].isConfirmed = isConfirmed
        }
        persist()
    }

    func toggleSetConfirmed(exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }

        exercises[exerciseIndex].sets[setIndex].isConfirmed.toggle()
        persist()
    }

    func addExercise() {
        exercises.append(WorkoutExercise(name: "New Exercise"))
        persist()
    }

    func cancelWorkout() {
        clearPersistence()
    }

    func finishWorkout() {
        clearPersistence()
    }

    func placeholderWeight(for exercise: WorkoutExercise, setIndex: Int) -> String {
        if setIndex > 0 {
            let previous = exercise.sets[setIndex - 1]
            if previous.isConfirmed, !previous.weight.isEmpty {
                return previous.weight
            }
        }
        return exercise.sets.prefix(setIndex).last(where: { $0.isConfirmed && !$0.weight.isEmpty })?.weight ?? ""
    }

    func placeholderReps(for exercise: WorkoutExercise, setIndex: Int) -> String {
        if setIndex > 0 {
            let previous = exercise.sets[setIndex - 1]
            if previous.isConfirmed, !previous.reps.isEmpty {
                return previous.reps
            }
        }
        return exercise.sets.prefix(setIndex).last(where: { $0.isConfirmed && !$0.reps.isEmpty })?.reps ?? ""
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

    private func startRestTimer() {
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard let remaining = self.restSecondsRemaining else { return }
                if remaining <= 1 {
                    self.restSecondsRemaining = nil
                    self.restTimer?.invalidate()
                    self.restTimer = nil
                } else {
                    self.restSecondsRemaining = remaining - 1
                }
                self.persist()
            }
        }
    }

    private func persist() {
        let state = ActiveWorkoutState(
            workoutName: workoutName,
            exercises: exercises,
            startedAt: startedAt,
            restSecondsRemaining: restSecondsRemaining
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func clearPersistence() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        elapsedTimer?.invalidate()
        restTimer?.invalidate()
    }

    private static func loadState() -> ActiveWorkoutState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ActiveWorkoutState.self, from: data)
    }

    private static func defaultWorkoutName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d"
        return "\(formatter.string(from: Date()).uppercased()) WORKOUT"
    }

    private static func placeholderExercises() -> [WorkoutExercise] {
        [
            WorkoutExercise(name: "Barbell Squat"),
            WorkoutExercise(name: "Bench Press"),
            WorkoutExercise(name: "Deadlift"),
        ]
    }
}
