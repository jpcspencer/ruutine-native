import Foundation
import Supabase

struct PreviousSetRecord: Equatable {
    let weightKg: Double?
    let reps: Int?

    var displayText: String {
        guard let weightKg, let reps else { return "—" }
        let weight = Self.formatWeight(weightKg)
        return "\(weight) kg × \(reps)"
    }

    var weightPlaceholder: String {
        guard let weightKg else { return "" }
        return Self.formatWeight(weightKg)
    }

    var repsPlaceholder: String {
        guard let reps else { return "" }
        return "\(reps)"
    }

    private static func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

enum PreviousSetsService {
    private struct SessionIDRow: Decodable {
        let id: UUID
    }

    private struct LogRow: Decodable {
        let sessionId: UUID?
        let weightKg: Double?
        let reps: Int?
        let setNumber: Int?

        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case weightKg = "weight_kg"
            case reps
            case setNumber = "set_number"
        }
    }

    static func fetchPreviousSets(
        for exerciseName: String,
        userId: UUID
    ) async -> [PreviousSetRecord] {
        do {
            let sessions: [SessionIDRow] = try await SupabaseClient.shared
                .from("completed_sessions")
                .select("id")
                .eq("user_profile_id", value: userId)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            guard !sessions.isEmpty else { return [] }

            let sessionIds = sessions.map(\.id)
            let logs: [LogRow] = try await SupabaseClient.shared
                .from("exercise_logs")
                .select("session_id, weight_kg, reps, set_number")
                .in("session_id", values: sessionIds)
                .eq("exercise_name", value: exerciseName)
                .order("set_number", ascending: true)
                .limit(20)
                .execute()
                .value

            guard !logs.isEmpty else { return [] }

            let mostRecentSessionId = sessionIds.first { sessionId in
                logs.contains { $0.sessionId == sessionId }
            }

            guard let mostRecentSessionId else { return [] }

            return logs
                .filter { $0.sessionId == mostRecentSessionId }
                .sorted { ($0.setNumber ?? 0) < ($1.setNumber ?? 0) }
                .map { PreviousSetRecord(weightKg: $0.weightKg, reps: $0.reps) }
        } catch {
            return []
        }
    }
}
