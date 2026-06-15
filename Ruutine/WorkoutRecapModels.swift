import Foundation

struct RecapSet: Identifiable, Equatable {
    let id = UUID()
    let setNumber: Int
    let weightKg: Double
    let reps: Int
}

struct RecapExercise: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let primaryMuscle: String?
    let sets: [RecapSet]
}

struct WorkoutRecapData: Identifiable, Equatable {
    let id: UUID
    let sessionName: String
    let durationSeconds: Int
    let totalSets: Int
    let totalVolumeKg: Double
    let exercises: [RecapExercise]
    let profileId: UUID
    let note: String?
    let photoData: Data?

    init(
        id: UUID,
        sessionName: String,
        durationSeconds: Int,
        totalSets: Int,
        totalVolumeKg: Double,
        exercises: [RecapExercise],
        profileId: UUID,
        note: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.sessionName = sessionName
        self.durationSeconds = durationSeconds
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
        self.exercises = exercises
        self.profileId = profileId
        self.note = note
        self.photoData = photoData
    }

    var trainedMuscles: [String] {
        ExerciseMuscleMap.muscles(for: exercises)
    }

    var durationFormatted: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var volumeFormatted: String {
        "\(Int(totalVolumeKg.rounded())) kg"
    }

    static func fromCompletion(
        profileId: UUID,
        sessionName: String,
        durationSeconds: Int,
        exercises: [CompletedExercisePayload],
        totalVolumeKg: Double,
        totalSets: Int,
        note: String? = nil,
        photoData: Data? = nil,
        sessionId: UUID = UUID()
    ) -> WorkoutRecapData {
        let recapExercises = exercises.map { exercise in
            RecapExercise(
                name: exercise.name,
                primaryMuscle: exercise.primaryMuscle,
                sets: exercise.sets.map {
                    RecapSet(
                        setNumber: $0.setNumber,
                        weightKg: $0.weightKg ?? 0,
                        reps: $0.reps ?? 0
                    )
                }
            )
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        return WorkoutRecapData(
            id: sessionId,
            sessionName: sessionName.trimmingCharacters(in: .whitespacesAndNewlines),
            durationSeconds: durationSeconds,
            totalSets: totalSets,
            totalVolumeKg: totalVolumeKg,
            exercises: recapExercises,
            profileId: profileId,
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil,
            photoData: photoData
        )
    }
}

struct CompletedExercisePayload {
    let name: String
    let primaryMuscle: String?
    let sets: [CompletedSetPayload]
}

struct CompletedSetPayload {
    let setNumber: Int
    let weightKg: Double?
    let reps: Int?
    let durationSeconds: Int?
    let distanceM: Double?
}

enum WorkoutSetPersistence {
    struct ExerciseLogFields {
        let weightKg: Double?
        let reps: Int?
        let durationSeconds: Int?
        let distanceM: Double?
    }

    static func completedSetPayload(
        from set: WorkoutSet,
        setNumber: Int,
        inputKind: InputKind
    ) -> CompletedSetPayload? {
        switch inputKind {
        case .weightReps, .addedWeightReps, .assistedReps:
            guard let weight = Double(set.weight.trimmingCharacters(in: .whitespaces)),
                  let reps = Int(set.reps.trimmingCharacters(in: .whitespaces))
            else { return nil }
            return CompletedSetPayload(
                setNumber: setNumber,
                weightKg: weight,
                reps: reps,
                durationSeconds: nil,
                distanceM: nil
            )

        case .repsOnly:
            guard let reps = Int(set.reps.trimmingCharacters(in: .whitespaces)) else { return nil }
            return CompletedSetPayload(
                setNumber: setNumber,
                weightKg: nil,
                reps: reps,
                durationSeconds: nil,
                distanceM: nil
            )

        case .cardio:
            let durationSeconds = set.durationSeconds
            let distanceM = set.distanceM
            let hasTime = (durationSeconds ?? 0) > 0
            let hasDistance = (distanceM ?? 0) > 0
            guard hasTime || hasDistance else { return nil }
            return CompletedSetPayload(
                setNumber: setNumber,
                weightKg: nil,
                reps: nil,
                durationSeconds: hasTime ? durationSeconds : nil,
                distanceM: hasDistance ? distanceM : nil
            )

        case .duration:
            guard let durationSeconds = set.durationSeconds, durationSeconds > 0 else { return nil }
            return CompletedSetPayload(
                setNumber: setNumber,
                weightKg: nil,
                reps: nil,
                durationSeconds: durationSeconds,
                distanceM: nil
            )
        }
    }

    static func exerciseLogFields(
        from set: WorkoutSet,
        inputKind: InputKind,
        isImperial: Bool
    ) -> ExerciseLogFields {
        switch inputKind {
        case .weightReps, .addedWeightReps, .assistedReps:
            return ExerciseLogFields(
                weightKg: HistoryFormatting.parseWeight(set.weight, isImperial: isImperial),
                reps: HistoryFormatting.parseReps(set.reps),
                durationSeconds: nil,
                distanceM: nil
            )

        case .repsOnly:
            return ExerciseLogFields(
                weightKg: nil,
                reps: HistoryFormatting.parseReps(set.reps),
                durationSeconds: nil,
                distanceM: nil
            )

        case .cardio:
            let durationSeconds = set.durationSeconds
            let distanceM = set.distanceM
            let hasTime = (durationSeconds ?? 0) > 0
            let hasDistance = (distanceM ?? 0) > 0
            return ExerciseLogFields(
                weightKg: nil,
                reps: nil,
                durationSeconds: hasTime ? durationSeconds : nil,
                distanceM: hasDistance ? distanceM : nil
            )

        case .duration:
            let durationSeconds = set.durationSeconds
            let hasTime = (durationSeconds ?? 0) > 0
            return ExerciseLogFields(
                weightKg: nil,
                reps: nil,
                durationSeconds: hasTime ? durationSeconds : nil,
                distanceM: nil
            )
        }
    }
}

extension Notification.Name {
    static let workoutCompleted = Notification.Name("workoutCompleted")
}
