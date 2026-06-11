import Foundation
import Supabase

enum WorkoutSessionService {
    struct SessionInsert: Encodable {
        let userId: UUID
        let userProfileId: UUID
        let sessionName: String
        let exercisesCompleted: [ExerciseCompletedJSON]
        let createdAt: String
        let finishedAt: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case userProfileId = "user_profile_id"
            case sessionName = "session_name"
            case exercisesCompleted = "exercises_completed"
            case createdAt = "created_at"
            case finishedAt = "finished_at"
        }
    }

    struct ExerciseCompletedJSON: Encodable {
        let name: String
        let sets: [SetCompletedJSON]
    }

    struct SetCompletedJSON: Encodable {
        let weightKg: Double
        let reps: Int

        enum CodingKeys: String, CodingKey {
            case weightKg = "weight_kg"
            case reps
        }
    }

    struct ExerciseLogInsert: Encodable {
        let userId: UUID
        let userProfileId: UUID
        let sessionId: UUID
        let exerciseName: String
        let setNumber: Int
        let weightKg: Double
        let reps: Int
        let completed: Bool
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case userProfileId = "user_profile_id"
            case sessionId = "session_id"
            case exerciseName = "exercise_name"
            case setNumber = "set_number"
            case weightKg = "weight_kg"
            case reps
            case completed
            case createdAt = "created_at"
        }
    }

    struct SessionIDRow: Decodable {
        let id: UUID
    }

    static func saveCompletedWorkout(
        userId: UUID,
        sessionName: String,
        durationSeconds: Int,
        exercises: [CompletedExercisePayload]
    ) async throws -> WorkoutRecapData {
        let now = ISO8601DateFormatter().string(from: Date())
        let exercisesJSON = exercises.map { exercise in
            ExerciseCompletedJSON(
                name: exercise.name,
                sets: exercise.sets.map { SetCompletedJSON(weightKg: $0.weightKg, reps: $0.reps) }
            )
        }

        let sessionInsert = SessionInsert(
            userId: userId,
            userProfileId: userId,
            sessionName: sessionName,
            exercisesCompleted: exercisesJSON,
            createdAt: now,
            finishedAt: now
        )

        let session: SessionIDRow = try await SupabaseClient.shared
            .from("completed_sessions")
            .insert(sessionInsert)
            .select("id")
            .single()
            .execute()
            .value

        var totalVolume = 0.0
        var totalSets = 0
        var recapExercises: [RecapExercise] = []

        for exercise in exercises {
            var recapSets: [RecapSet] = []
            for set in exercise.sets {
                let log = ExerciseLogInsert(
                    userId: userId,
                    userProfileId: userId,
                    sessionId: session.id,
                    exerciseName: exercise.name,
                    setNumber: set.setNumber,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    completed: true,
                    createdAt: now
                )
                try await SupabaseClient.shared
                    .from("exercise_logs")
                    .insert(log)
                    .execute()

                totalVolume += set.weightKg * Double(set.reps)
                totalSets += 1
                recapSets.append(
                    RecapSet(setNumber: set.setNumber, weightKg: set.weightKg, reps: set.reps)
                )
            }
            if !recapSets.isEmpty {
                recapExercises.append(
                    RecapExercise(
                        name: exercise.name,
                        primaryMuscle: exercise.primaryMuscle,
                        sets: recapSets
                    )
                )
            }
        }

        return WorkoutRecapData(
            id: session.id,
            sessionName: sessionName,
            durationSeconds: durationSeconds,
            totalSets: totalSets,
            totalVolumeKg: totalVolume,
            exercises: recapExercises,
            profileId: userId
        )
    }
}
