import Combine
import Foundation
import Supabase

@MainActor
final class ProgramViewModel: ObservableObject {
    @Published var days: [ProgramDay] = []
    @Published var programName = "My Program"
    @Published var programWeek = 1
    @Published var programContent: ProgramContent?
    @Published var profileGoal = ""
    @Published var profileDaysPerWeek = 0
    @Published var overviewText = ""
    @Published var overviewFacts: [String] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let profile: ProfileDetail = try await SupabaseClient.shared
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            profileGoal = profile.goal
            profileDaysPerWeek = profile.daysPerWeek

            let program: TrainingProgram = try await SupabaseClient.shared
                .from("training_programs")
                .select()
                .eq("user_profile_id", value: userId)
                .eq("week_number", value: 1)
                .single()
                .execute()
                .value

            if let jsonData = try? JSONEncoder().encode(program.programContent),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("[ProgramViewModel] training_programs.program_content JSON:")
                print(jsonString)
            }

            programContent = program.programContent
            programName = program.programContent.name ?? "My Program"
            programWeek = program.programContent.week ?? 1
            days = program.programContent.days ?? []
            buildOverview()
        } catch {
            days = []
            programName = "My Program"
            programContent = nil
            overviewText = ""
            overviewFacts = []
            print("[ProgramViewModel] load error: \(error)")
        }

        isLoading = false
    }

    func exercisesForDay(_ day: ProgramDay) -> [WorkoutExercise] {
        (day.exercises ?? []).map { exercise in
            WorkoutExercise(
                name: exercise.name,
                primaryMuscle: ExerciseMuscleMap.primaryMuscle(for: exercise.name),
                sets: [WorkoutSet()]
            )
        }
    }

    private func buildOverview() {
        guard let content = programContent else {
            overviewText = ""
            overviewFacts = []
            return
        }

        if let stored = content.storedOverview {
            overviewText = stored
        } else {
            let goalLabel = ProfileLabels.goal(profileGoal)
            let dayCount = days.count
            let split = inferSplitStyle(from: days)
            overviewText = "A \(dayCount)-day \(split) built for your \(goalLabel.lowercased()) goal. Each session is structured to match your equipment and experience."
        }

        var facts: [String] = []
        facts.append("Goal: \(ProfileLabels.goal(profileGoal))")
        facts.append("Days/week: \(days.count)")
        facts.append("Focus: \(inferSplitStyle(from: days))")
        if let duration = content.storedDuration {
            facts.append("Duration: \(duration)")
        }
        overviewFacts = facts
    }

    private func inferSplitStyle(from days: [ProgramDay]) -> String {
        let names = days.map { $0.name.lowercased() }
        let combined = names.joined(separator: " ")
        if combined.contains("push") && combined.contains("pull") {
            return "push/pull/legs split"
        }
        if combined.contains("upper") && combined.contains("lower") {
            return "upper/lower split"
        }
        if combined.contains("full body") || combined.contains("full-body") {
            return "full-body split"
        }
        if days.count >= 5 {
            return "high-frequency hypertrophy split"
        }
        if days.count <= 3 {
            return "focused training split"
        }
        return "balanced training split"
    }
}

private extension ExerciseMuscleMap {
    static func primaryMuscle(for exerciseName: String) -> String? {
        let muscles = muscles(forExerciseName: exerciseName)
        return muscles.first
    }
}
