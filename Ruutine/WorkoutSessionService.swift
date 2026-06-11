import Foundation
import Supabase

enum WorkoutSessionService {
    struct SessionInsert: Encodable {
        let userId: UUID
        let name: String
        let createdAt: String
        let durationSeconds: Int
        let totalVolumeKg: Double
        let exercisesCompleted: [ExerciseCompletedJSON]

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case name
            case createdAt = "created_at"
            case durationSeconds = "duration_seconds"
            case totalVolumeKg = "total_volume_kg"
            case exercisesCompleted = "exercises_completed"
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
        let sessionId: UUID
        let exerciseName: String
        let setNumber: Int
        let weightKg: Double
        let reps: Int
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case exerciseName = "exercise_name"
            case setNumber = "set_number"
            case weightKg = "weight_kg"
            case reps
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
        let totalVolumeKg = exercises.reduce(0.0) { volume, exercise in
            volume + exercise.sets.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
        }

        let sessionInsert = SessionInsert(
            userId: userId,
            name: sessionName,
            createdAt: now,
            durationSeconds: durationSeconds,
            totalVolumeKg: totalVolumeKg,
            exercisesCompleted: exercisesJSON
        )

        let session: SessionIDRow
        do {
            session = try await SupabaseClient.shared
                .from("completed_sessions")
                .insert(sessionInsert)
                .select("id")
                .single()
                .execute()
                .value
        } catch {
            logSaveError(table: "completed_sessions", error: error)
            throw error
        }

        var totalVolume = 0.0
        var totalSets = 0
        var recapExercises: [RecapExercise] = []

        for exercise in exercises {
            var recapSets: [RecapSet] = []
            for set in exercise.sets {
                let log = ExerciseLogInsert(
                    sessionId: session.id,
                    exerciseName: exercise.name,
                    setNumber: set.setNumber,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    createdAt: now
                )
                do {
                    try await SupabaseClient.shared
                        .from("exercise_logs")
                        .insert(log)
                        .execute()
                } catch {
                    logSaveError(table: "exercise_logs", error: error)
                    throw error
                }

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

    private static func logSaveError(table: String, error: Error) {
        print("[WorkoutSessionService] \(table) insert failed")
        print("  error: \(error)")
        print("  localizedDescription: \(error.localizedDescription)")
        if let column = schemaMismatchColumn(in: error.localizedDescription) {
            print("  schema column: \(column)")
        }
    }

    static func userFacingMessage(for error: Error) -> String {
        let description = error.localizedDescription
        if let column = schemaMismatchColumn(in: description) {
            return "Save failed on \(column): \(description)"
        }
        return description
    }

    private static func schemaMismatchColumn(in message: String) -> String? {
        guard let openQuote = message.firstIndex(of: "'"),
              let closeQuote = message[openQuote...].dropFirst().firstIndex(of: "'")
        else { return nil }

        let columnStart = message.index(after: openQuote)
        let columnEnd = closeQuote
        guard columnStart < columnEnd else { return nil }

        let column = String(message[columnStart..<columnEnd])
        guard message.contains("column") else { return nil }
        return column
    }
}
