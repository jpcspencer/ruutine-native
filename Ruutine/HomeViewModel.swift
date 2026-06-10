import Combine
import Foundation
import Supabase

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var todaySession: TodaySessionData?
    @Published var streak = 0
    @Published var totalSessions = 0
    @Published var volumeDisplay = 0
    @Published var volumeLabel = "kg"
    @Published var progressWeeks: [WeekProgress] = []
    @Published var trainedMuscles: [String] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let profile: UserProfile = try await SupabaseClient.shared
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            self.profile = profile
            volumeLabel = profile.isImperial ? "lb" : "kg"

            let program: TrainingProgram? = try? await SupabaseClient.shared
                .from("training_programs")
                .select()
                .eq("user_profile_id", value: userId)
                .eq("week_number", value: 1)
                .single()
                .execute()
                .value

            let sessions: [CompletedSession] = try await SupabaseClient.shared
                .from("completed_sessions")
                .select("id, user_profile_id, session_name, finished_at, created_at")
                .eq("user_profile_id", value: userId)
                .order("finished_at", ascending: false, nullsFirst: false)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            totalSessions = sessions.count
            streak = computeStreak(from: sessions)

            let sessionIds = sessions.map(\.id)
            var volumeBySession: [UUID: Double] = [:]
            var muscles = Set<String>()

            let weekStart = startOfWeek(for: Date())
            let weekSessionIds = Set(
                sessions.compactMap { session -> UUID? in
                    guard let date = session.effectiveDate, date >= weekStart else { return nil }
                    return session.id
                }
            )

            if !sessionIds.isEmpty {
                let logs: [ExerciseLog] = try await SupabaseClient.shared
                    .from("exercise_logs")
                    .select("session_id, weight_kg, reps, exercise_name")
                    .in("session_id", values: sessionIds)
                    .execute()
                    .value

                for log in logs {
                    guard let sessionId = log.sessionId else { continue }
                    let volume = (log.weightKg ?? 0) * Double(log.reps ?? 0)
                    volumeBySession[sessionId, default: 0] += volume
                    guard weekSessionIds.contains(sessionId) else { continue }
                    if let name = log.exerciseName, let muscle = ExerciseMuscleMap.muscle(for: name) {
                        muscles.insert(muscle)
                    }
                }
            }

            trainedMuscles = Array(muscles).sorted()
            progressWeeks = computeProgressWeeks(sessions: sessions, volumeBySession: volumeBySession)

            var volumeThisWeek = 0.0
            for session in sessions {
                guard let date = session.effectiveDate, date >= weekStart else { continue }
                volumeThisWeek += volumeBySession[session.id] ?? 0
            }

            volumeDisplay = Int(
                profile.isImperial
                    ? (volumeThisWeek * 2.20462).rounded()
                    : volumeThisWeek.rounded()
            )

            todaySession = computeTodaySession(
                profile: profile,
                program: program,
                sessions: sessions
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func computeTodaySession(
        profile: UserProfile,
        program: TrainingProgram?,
        sessions: [CompletedSession]
    ) -> TodaySessionData? {
        let days = program?.programContent.days ?? []
        guard !days.isEmpty else { return nil }

        let trainingDays = profile.trainingDays.isEmpty ? [1, 3, 5] : profile.trainingDays
        let todayWeekday = currentWeekday()
        guard trainingDays.contains(todayWeekday) else { return nil }

        let completedNames = sessions.map { $0.sessionName.lowercased() }
        let lastCompletedIndex = days.enumerated().reduce(-1) { last, item in
            let wasCompleted = completedNames.contains { name in
                name.contains(item.element.name.lowercased())
                    || item.element.name.lowercased().contains(name)
            }
            return wasCompleted ? item.offset : last
        }

        let nextIndex = lastCompletedIndex >= 0 ? (lastCompletedIndex + 1) % days.count : 0
        let sessionDay = days[nextIndex]
        let completedToday = sessions.contains { session in
            guard session.sessionName.caseInsensitiveCompare(sessionDay.name) == .orderedSame else {
                return false
            }
            guard let date = session.createdAt else { return false }
            return Calendar.current.isDateInToday(date)
        }

        return TodaySessionData(
            day: sessionDay.day,
            name: sessionDay.name,
            exerciseCount: sessionDay.exercises?.count ?? 0,
            completedToday: completedToday
        )
    }

    private func computeStreak(from sessions: [CompletedSession]) -> Int {
        let dated = sessions.compactMap { session -> Date? in
            guard let date = session.effectiveDate else { return nil }
            return Calendar.current.startOfDay(for: date)
        }.sorted(by: >)

        guard let mostRecent = dated.first else { return 0 }

        let today = Calendar.current.startOfDay(for: Date())
        let daysSince = Calendar.current.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        guard daysSince <= 1 else { return 0 }

        var streak = 0
        var expected = today
        for date in dated {
            let diff = Calendar.current.dateComponents([.day], from: date, to: expected).day ?? 99
            if diff == 0 || diff == 1 {
                streak += 1
                expected = date
            } else {
                break
            }
        }
        return streak
    }

    private func computeProgressWeeks(
        sessions: [CompletedSession],
        volumeBySession: [UUID: Double]
    ) -> [WeekProgress] {
        var weekMap: [String: (volume: Double, sessions: Int, week: Date)] = [:]

        for session in sessions {
            guard let date = session.effectiveDate else { continue }
            let week = startOfWeek(for: date)
            let key = ISO8601DateFormatter().string(from: week)
            let volume = volumeBySession[session.id] ?? 0
            let current = weekMap[key] ?? (volume: 0, sessions: 0, week: week)
            weekMap[key] = (
                volume: current.volume + volume,
                sessions: current.sessions + 1,
                week: week
            )
        }

        return weekMap.values
            .map { WeekProgress(id: ISO8601DateFormatter().string(from: $0.week), week: $0.week, volume: $0.volume, sessions: $0.sessions) }
            .sorted { $0.week < $1.week }
    }

    private func currentWeekday() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    private func startOfWeek(for date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}
