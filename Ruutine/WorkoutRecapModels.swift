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

    var trainedMuscles: [String] {
        ExerciseMuscleMap.muscles(for: exercises.map(\.name))
    }

    var durationFormatted: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var volumeFormatted: String {
        "\(Int(totalVolumeKg.rounded())) kg"
    }
}

struct CompletedExercisePayload {
    let name: String
    let sets: [CompletedSetPayload]
}

struct CompletedSetPayload {
    let setNumber: Int
    let weightKg: Double
    let reps: Int
}

extension Notification.Name {
    static let workoutCompleted = Notification.Name("workoutCompleted")
}
