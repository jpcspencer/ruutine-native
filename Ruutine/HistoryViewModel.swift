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
    private var exerciseOrderBySession: [UUID: [String]] = [:]

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
                .select("id, user_profile_id, session_name, finished_at, created_at, exercises_completed, duration_seconds")
                .eq("user_profile_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            exerciseOrderBySession = Dictionary(
                uniqueKeysWithValues: sessions.map { session in
                    (
                        session.id,
                        session.exercisesCompleted?.map(\.name)
                            ?? []
                    )
                }
            )

            let sessionIds = sessions.map(\.id)
            var volumeBySession: [UUID: Double] = [:]
            var bestSetsBySession: [UUID: [String: BestSet]] = [:]
            var exercisesBySession: [UUID: [String]] = [:]
            logsBySession = [:]

            if !sessionIds.isEmpty {
                let logs: [ExerciseLogDetail] = try await SupabaseClient.shared
                    .from("exercise_logs")
                    .select("id, session_id, exercise_name, weight_kg, reps, set_number, completed, duration_seconds, distance_m")
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

                    let candidate = BestSet(
                        weightKg: log.weightKg ?? 0,
                        reps: log.reps ?? 0,
                        durationSeconds: log.durationSeconds,
                        distanceM: log.distanceM
                    )
                    let existing = bestSetsBySession[sessionId]?[name]
                    let isCardioCandidate = candidate.cardioScore > 0 && candidate.volume == 0
                    let shouldReplace: Bool
                    if isCardioCandidate {
                        shouldReplace = existing == nil || candidate.cardioScore > (existing?.cardioScore ?? 0)
                    } else {
                        shouldReplace = existing == nil || candidate.volume > (existing?.volume ?? 0)
                    }
                    if shouldReplace {
                        bestSetsBySession[sessionId, default: [:]][name] = candidate
                    }
                }

                for sessionId in sessionIds {
                    let order = exerciseOrderBySession[sessionId] ?? []
                    let sessionLogs = logsBySession[sessionId] ?? []
                    logsBySession[sessionId] = order.isEmpty
                        ? sessionLogs.sorted {
                            let left = $0.setNumber ?? 0
                            let right = $1.setNumber ?? 0
                            if left == right {
                                return ($0.exerciseName ?? "") < ($1.exerciseName ?? "")
                            }
                            return left < right
                        }
                        : SessionLogConverter.sortLogs(sessionLogs, exerciseOrder: order)
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
                    durationSeconds: session.durationSeconds,
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

    func saveSessionEdit(
        sessionId: UUID,
        userId: UUID,
        draft: SessionEditDraft,
        isImperial: Bool
    ) async throws {
        let trimmedName = draft.sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let exercisesCompleted = draft.exercises
            .filter { !$0.sets.isEmpty }
            .map {
                WorkoutSessionService.SessionExerciseCompletedJSON(
                    name: $0.name,
                    sets: $0.sets.count
                )
            }

        let sessionPayload = CompletedSessionUpdatePayload(
            sessionName: trimmedName,
            createdAt: draft.sessionDate,
            finishedAt: draft.sessionDate,
            durationSeconds: draft.durationSeconds,
            exercisesCompleted: exercisesCompleted
        )

        try await SupabaseClient.shared
            .from("completed_sessions")
            .update(sessionPayload)
            .eq("id", value: sessionId)
            .execute()

        var currentLogIds = Set<UUID>()

        for exercise in draft.exercises {
            for (index, set) in exercise.sets.enumerated() {
                let setNumber = index + 1
                let fields = WorkoutSetPersistence.exerciseLogFields(
                    from: set,
                    inputKind: exercise.category.inputKind,
                    isImperial: isImperial
                )
                let logPayload = ExerciseLogSavePayload(
                    weight_kg: fields.weightKg,
                    reps: fields.reps,
                    set_number: setNumber,
                    exercise_name: exercise.name,
                    completed: set.isConfirmed,
                    duration_seconds: fields.durationSeconds,
                    distance_m: fields.distanceM
                )

                if draft.originalLogIds.contains(set.id) {
                    currentLogIds.insert(set.id)
                    try await SupabaseClient.shared
                        .from("exercise_logs")
                        .update(logPayload)
                        .eq("id", value: set.id)
                        .execute()
                } else {
                    let insert = WorkoutSessionService.ExerciseLogInsert(
                        userId: userId,
                        sessionId: sessionId,
                        exerciseName: exercise.name,
                        setNumber: setNumber,
                        weightKg: fields.weightKg,
                        reps: fields.reps,
                        completed: set.isConfirmed,
                        durationSeconds: fields.durationSeconds,
                        distanceM: fields.distanceM
                    )
                    try await SupabaseClient.shared
                        .from("exercise_logs")
                        .insert(insert)
                        .execute()
                }
            }
        }

        let deletedLogIds = draft.originalLogIds.subtracting(currentLogIds)
        for logId in deletedLogIds {
            try await SupabaseClient.shared
                .from("exercise_logs")
                .delete()
                .eq("id", value: logId)
                .execute()
        }

        logsBySession[sessionId] = SessionLogConverter.logs(
            from: draft,
            sessionId: sessionId,
            isImperial: isImperial
        )
        exerciseOrderBySession[sessionId] = draft.exercises.map(\.name)
    }
}

private struct CompletedSessionUpdatePayload: Encodable {
    let sessionName: String
    let createdAt: Date
    let finishedAt: Date
    let durationSeconds: Int?
    let exercisesCompleted: [WorkoutSessionService.SessionExerciseCompletedJSON]

    enum CodingKeys: String, CodingKey {
        case sessionName = "session_name"
        case createdAt = "created_at"
        case finishedAt = "finished_at"
        case durationSeconds = "duration_seconds"
        case exercisesCompleted = "exercises_completed"
    }
}

private struct ExerciseLogSavePayload: Encodable {
    let weight_kg: Double?
    let reps: Int?
    let set_number: Int
    let exercise_name: String
    let completed: Bool
    let duration_seconds: Int?
    let distance_m: Double?
}
