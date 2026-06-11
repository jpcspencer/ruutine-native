import Combine
import Foundation
import Supabase

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var monthGroups: [HistoryMonthGroup] = []
    @Published var workoutDays: Set<DateComponents> = []
    @Published var isImperial = false
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var logsBySession: [UUID: [ExerciseLogDetail]] = [:]

    func load(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let profile: UserProfile? = try? await SupabaseClient.shared
                .from("user_profiles")
                .select("id, name, training_days, unit_preference, biological_sex")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            isImperial = profile?.isImperial ?? false

            let sessions: [CompletedSession] = try await SupabaseClient.shared
                .from("completed_sessions")
                .select("id, user_profile_id, session_name, finished_at, created_at")
                .eq("user_profile_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let sessionIds = sessions.map(\.id)
            var volumeBySession: [UUID: Double] = [:]
            var bestSetsBySession: [UUID: [String: BestSet]] = [:]
            var exercisesBySession: [UUID: [String]] = [:]
            logsBySession = [:]

            if !sessionIds.isEmpty {
                let logs: [ExerciseLogDetail] = try await SupabaseClient.shared
                    .from("exercise_logs")
                    .select("id, session_id, exercise_name, weight_kg, reps, set_number")
                    .in("session_id", values: sessionIds)
                    .execute()
                    .value

                let deduped = ExerciseLogDeduper.dedupeLogs(logs)

                for log in deduped {
                    guard let sessionId = log.sessionId else { continue }
                    let volume = (log.weightKg ?? 0) * Double(log.reps ?? 0)
                    volumeBySession[sessionId, default: 0] += volume

                    logsBySession[sessionId, default: []].append(log)

                    guard let name = log.exerciseName, !name.isEmpty else { continue }
                    if exercisesBySession[sessionId]?.contains(name) != true {
                        exercisesBySession[sessionId, default: []].append(name)
                    }

                    let candidate = BestSet(weightKg: log.weightKg ?? 0, reps: log.reps ?? 0)
                    let existing = bestSetsBySession[sessionId]?[name]
                    if existing == nil || candidate.volume > (existing?.volume ?? 0) {
                        bestSetsBySession[sessionId, default: [:]][name] = candidate
                    }
                }

                for sessionId in sessionIds {
                    logsBySession[sessionId] = (logsBySession[sessionId] ?? [])
                        .sorted {
                            let left = $0.setNumber ?? 0
                            let right = $1.setNumber ?? 0
                            if left == right {
                                return ($0.exerciseName ?? "") < ($1.exerciseName ?? "")
                            }
                            return left < right
                        }
                }
            }

            let calendar = Calendar.current
            var days = Set<DateComponents>()
            var grouped: [String: [HistorySessionItem]] = [:]

            for session in sessions {
                guard let date = session.effectiveDate else { continue }
                let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
                days.insert(dayComponents)

                let item = HistorySessionItem(
                    id: session.id,
                    sessionName: session.sessionName,
                    date: date,
                    volume: volumeBySession[session.id] ?? 0,
                    exercises: exercisesBySession[session.id] ?? [],
                    bestSets: bestSetsBySession[session.id] ?? [:]
                )

                let monthKey = HistoryFormatting.monthHeader(from: date)
                grouped[monthKey, default: []].append(item)
            }

            workoutDays = days
            monthGroups = grouped
                .map { key, value in
                    HistoryMonthGroup(
                        id: key,
                        title: key,
                        sessions: value.sorted { $0.date > $1.date }
                    )
                }
                .sorted { lhs, rhs in
                    guard let left = lhs.sessions.first?.date,
                          let right = rhs.sessions.first?.date
                    else { return false }
                    return left > right
                }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logs(for sessionId: UUID) -> [ExerciseLogDetail] {
        logsBySession[sessionId] ?? []
    }

    func deleteSession(_ sessionId: UUID) async throws {
        try await SupabaseClient.shared
            .from("completed_sessions")
            .delete()
            .eq("id", value: sessionId)
            .execute()
    }
}
