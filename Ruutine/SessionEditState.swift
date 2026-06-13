import Foundation

struct SessionEditDraft {
    let sessionName: String
    let sessionDate: Date
    let exercises: [WorkoutExercise]
    let originalLogIds: Set<UUID>
}

struct SessionEditState {
    var sessionName: String
    var sessionDate: Date
    var exercises: [WorkoutExercise]
    let originalLogIds: Set<UUID>
    let isImperial: Bool

    init(
        sessionName: String,
        sessionDate: Date,
        logs: [ExerciseLogDetail],
        isImperial: Bool
    ) {
        self.sessionName = sessionName
        self.sessionDate = sessionDate
        self.isImperial = isImperial
        let converted = SessionLogConverter.exercises(from: logs, isImperial: isImperial)
        exercises = converted.exercises
        originalLogIds = converted.originalLogIds
    }

    var draft: SessionEditDraft {
        SessionEditDraft(
            sessionName: sessionName,
            sessionDate: sessionDate,
            exercises: exercises,
            originalLogIds: originalLogIds
        )
    }

    mutating func addExercise(_ exercise: Exercise) {
        exercises.append(
            WorkoutExercise(name: exercise.name, primaryMuscle: exercise.primaryMuscle)
        )
    }

    mutating func removeExercise(_ exercise: WorkoutExercise) {
        exercises.removeAll { $0.id == exercise.id }
    }

    mutating func addSet(to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[index].sets.append(WorkoutSet())
    }

    mutating func removeSet(exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    mutating func updateSet(
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
    }

    mutating func toggleSetConfirmed(exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }

        let exercise = exercises[exerciseIndex]

        if exercises[exerciseIndex].sets[setIndex].isConfirmed {
            exercises[exerciseIndex].sets[setIndex].isConfirmed = false
        } else {
            if exercises[exerciseIndex].sets[setIndex].weight.isEmpty {
                let placeholder = placeholderWeight(for: exercise, setIndex: setIndex)
                if !placeholder.isEmpty {
                    exercises[exerciseIndex].sets[setIndex].weight = placeholder
                }
            }
            if exercises[exerciseIndex].sets[setIndex].reps.isEmpty {
                let placeholder = placeholderReps(for: exercise, setIndex: setIndex)
                if !placeholder.isEmpty {
                    exercises[exerciseIndex].sets[setIndex].reps = placeholder
                }
            }

            guard !exercises[exerciseIndex].sets[setIndex].weight.isEmpty,
                  !exercises[exerciseIndex].sets[setIndex].reps.isEmpty
            else { return }

            exercises[exerciseIndex].sets[setIndex].isConfirmed = true
        }
    }

    func isSetConfirmed(exerciseID: UUID, setID: UUID) -> Bool {
        exercises
            .first(where: { $0.id == exerciseID })?
            .sets.first(where: { $0.id == setID })?
            .isConfirmed ?? false
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
}

enum SessionLogConverter {
    static func exercises(
        from logs: [ExerciseLogDetail],
        isImperial: Bool
    ) -> (exercises: [WorkoutExercise], originalLogIds: Set<UUID>) {
        var originalLogIds = Set<UUID>()
        var exerciseOrder: [String] = []
        var grouped: [String: [ExerciseLogDetail]] = [:]

        for log in logs {
            originalLogIds.insert(log.id)
            let name = log.exerciseName ?? "Unknown"
            if grouped[name] == nil {
                exerciseOrder.append(name)
                grouped[name] = []
            }
            grouped[name]?.append(log)
        }

        let exercises = exerciseOrder.map { name in
            let sets = (grouped[name] ?? [])
                .sorted { ($0.setNumber ?? 0) < ($1.setNumber ?? 0) }
                .map { log in
                    WorkoutSet(
                        id: log.id,
                        weight: HistoryFormatting.displayWeight(kg: log.weightKg, isImperial: isImperial),
                        reps: log.reps.map(String.init) ?? "",
                        isConfirmed: log.completed ?? true
                    )
                }
            let catalogExercise = Exercise.all.first { $0.name == name }
            return WorkoutExercise(
                name: name,
                primaryMuscle: catalogExercise?.primaryMuscle,
                sets: sets.isEmpty ? [WorkoutSet()] : sets
            )
        }

        return (exercises, originalLogIds)
    }

    static func logs(
        from draft: SessionEditDraft,
        sessionId: UUID,
        isImperial: Bool
    ) -> [ExerciseLogDetail] {
        var result: [ExerciseLogDetail] = []

        for exercise in draft.exercises {
            for (index, set) in exercise.sets.enumerated() {
                result.append(
                    ExerciseLogDetail(
                        id: set.id,
                        sessionId: sessionId,
                        exerciseName: exercise.name,
                        weightKg: HistoryFormatting.parseWeight(set.weight, isImperial: isImperial),
                        reps: HistoryFormatting.parseReps(set.reps),
                        setNumber: index + 1,
                        completed: set.isConfirmed
                    )
                )
            }
        }

        return result
    }
}
