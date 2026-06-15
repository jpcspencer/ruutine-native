import Foundation
import SwiftUI
import UIKit

struct SessionEditDraft {
    let sessionName: String
    let sessionDate: Date
    let durationSeconds: Int?
    let exercises: [WorkoutExercise]
    let originalLogIds: Set<UUID>
}

struct SessionEditState {
    var sessionName: String
    var sessionDay: Date
    var startTime: Date
    var endTime: Date
    var exercises: [WorkoutExercise]
    let originalLogIds: Set<UUID>
    let isImperial: Bool

    init(
        sessionName: String,
        sessionDate: Date,
        durationSeconds: Int?,
        logs: [ExerciseLogDetail],
        isImperial: Bool
    ) {
        self.sessionName = sessionName
        self.isImperial = isImperial
        let calendar = Calendar.current
        sessionDay = calendar.startOfDay(for: sessionDate)
        startTime = sessionDate
        if let durationSeconds, durationSeconds > 0 {
            endTime = sessionDate.addingTimeInterval(TimeInterval(durationSeconds))
        } else {
            endTime = sessionDate
        }
        let converted = SessionLogConverter.exercises(from: logs, isImperial: isImperial)
        exercises = converted.exercises
        originalLogIds = converted.originalLogIds
    }

    var derivedDurationSeconds: Int? {
        SessionTiming.durationSeconds(day: sessionDay, startTime: startTime, endTime: endTime)
    }

    var derivedSessionDate: Date {
        SessionTiming.sessionTimestamp(day: sessionDay, startTime: startTime)
    }

    var draft: SessionEditDraft {
        SessionEditDraft(
            sessionName: sessionName,
            sessionDate: derivedSessionDate,
            durationSeconds: derivedDurationSeconds,
            exercises: exercises,
            originalLogIds: originalLogIds
        )
    }

    mutating func addExercise(_ exercise: Exercise) {
        exercises.append(
            WorkoutExercise(
                name: exercise.name,
                primaryMuscle: exercise.primaryMuscle,
                category: exercise.category
            )
        )
    }

    mutating func removeExercise(_ exercise: WorkoutExercise) {
        exercises.removeAll { $0.id == exercise.id }
    }

    mutating func moveExercise(draggedID: UUID, before targetID: UUID) {
        guard let from = exercises.firstIndex(where: { $0.id == draggedID }),
              let to = exercises.firstIndex(where: { $0.id == targetID }),
              from != to
        else { return }

        exercises.move(
            fromOffsets: IndexSet(integer: from),
            toOffset: to > from ? to + 1 : to
        )
        Haptics.impact(.medium)
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
}

enum SessionLogConverter {
    static func exercises(
        from logs: [ExerciseLogDetail],
        isImperial: Bool,
        exerciseOrder: [String]? = nil
    ) -> (exercises: [WorkoutExercise], originalLogIds: Set<UUID>) {
        var originalLogIds = Set<UUID>()
        var grouped: [String: [ExerciseLogDetail]] = [:]

        for log in logs {
            originalLogIds.insert(log.id)
            let name = log.exerciseName ?? "Unknown"
            grouped[name, default: []].append(log)
        }

        let exerciseOrder = exerciseOrder ?? orderedExerciseNames(from: logs)

        let exercises = exerciseOrder.compactMap { name -> WorkoutExercise? in
            guard let exerciseLogs = grouped[name] else { return nil }
            let sets = exerciseLogs
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
                category: catalogExercise?.category ?? .barbell,
                sets: sets.isEmpty ? [WorkoutSet()] : sets
            )
        }

        return (exercises, originalLogIds)
    }

    static func orderedExerciseNames(from logs: [ExerciseLogDetail]) -> [String] {
        var order: [String] = []
        for log in logs {
            let name = log.exerciseName ?? "Unknown"
            if !order.contains(name) {
                order.append(name)
            }
        }
        return order
    }

    static func sortLogs(
        _ logs: [ExerciseLogDetail],
        exerciseOrder: [String]
    ) -> [ExerciseLogDetail] {
        guard !exerciseOrder.isEmpty else { return logs }

        let orderIndex = Dictionary(
            uniqueKeysWithValues: exerciseOrder.enumerated().map { ($1, $0) }
        )

        return logs.sorted { lhs, rhs in
            let leftName = lhs.exerciseName ?? ""
            let rightName = rhs.exerciseName ?? ""
            let leftOrder = orderIndex[leftName] ?? Int.max
            let rightOrder = orderIndex[rightName] ?? Int.max
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }
            return (lhs.setNumber ?? 0) < (rhs.setNumber ?? 0)
        }
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
                        completed: set.isConfirmed,
                        durationSeconds: nil,
                        distanceM: nil
                    )
                )
            }
        }

        return result
    }
}
