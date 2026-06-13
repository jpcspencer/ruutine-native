import Foundation
import Supabase

// Capacitor reference: ~/ruutine/app/api/sessions/complete/route.ts
// completed_sessions insert columns:
//   user_id, user_profile_id, session_name, exercises_completed
// exercise_logs insert columns:
//   user_id, session_id, exercise_name, set_number, weight_kg, reps, completed

enum WorkoutSessionService {
    struct SessionInsert: Encodable {
        let userId: UUID
        let userProfileId: UUID
        let sessionName: String
        let exercisesCompleted: [SessionExerciseCompletedJSON]
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case userProfileId = "user_profile_id"
            case sessionName = "session_name"
            case exercisesCompleted = "exercises_completed"
            case notes
        }
    }

    /// Matches Capacitor: `{ name, sets: <confirmed set count> }`
    struct SessionExerciseCompletedJSON: Codable {
        let name: String
        let sets: Int
    }

    struct ExerciseLogInsert: Encodable {
        let userId: UUID
        let sessionId: UUID
        let exerciseName: String
        let setNumber: Int
        let weightKg: Double?
        let reps: Int?
        let completed: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case sessionId = "session_id"
            case exerciseName = "exercise_name"
            case setNumber = "set_number"
            case weightKg = "weight_kg"
            case reps
            case completed
        }
    }

    struct SessionIDRow: Decodable {
        let id: UUID
    }

    static func saveCompletedWorkout(
        userId: UUID,
        profileId: UUID,
        sessionName: String,
        durationSeconds: Int,
        exercises: [CompletedExercisePayload],
        notes: String? = nil,
        photoData: Data? = nil
    ) async throws -> WorkoutRecapData {
        let trimmedSessionName = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let exercisesWithSets = exercises.filter { !$0.sets.isEmpty }
        let exercisesJSON = exercisesWithSets.map { exercise in
            SessionExerciseCompletedJSON(name: exercise.name, sets: exercise.sets.count)
        }

        print("[WorkoutSessionService] completed_sessions columns: user_id, user_profile_id, session_name, exercises_completed")
        print("[WorkoutSessionService] exercise_logs columns: user_id, session_id, exercise_name, set_number, weight_kg, reps, completed")

        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionInsert = SessionInsert(
            userId: userId,
            userProfileId: profileId,
            sessionName: trimmedSessionName,
            exercisesCompleted: exercisesJSON,
            notes: trimmedNotes?.isEmpty == false ? trimmedNotes : nil
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

        for exercise in exercisesWithSets {
            var recapSets: [RecapSet] = []
            for (setIndex, set) in exercise.sets.enumerated() {
                let log = ExerciseLogInsert(
                    userId: userId,
                    sessionId: session.id,
                    exerciseName: exercise.name,
                    setNumber: setIndex + 1,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    completed: true
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
                    RecapSet(setNumber: setIndex + 1, weightKg: set.weightKg, reps: set.reps)
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
            sessionName: trimmedSessionName,
            durationSeconds: durationSeconds,
            totalSets: totalSets,
            totalVolumeKg: totalVolume,
            exercises: recapExercises,
            profileId: profileId,
            note: trimmedNotes,
            photoData: photoData
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
