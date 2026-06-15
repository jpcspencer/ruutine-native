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

extension Notification.Name {
    static let workoutCompleted = Notification.Name("workoutCompleted")
}
