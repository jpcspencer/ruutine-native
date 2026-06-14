import Combine
import Foundation
import Supabase

@MainActor
final class ProgramViewModel: ObservableObject {
    @Published var days: [ProgramDay] = []
    @Published var customProgramName: String?
    @Published var programWeek = 1
    @Published var programContent: ProgramContent?
    @Published var profileName = ""
    @Published var profileGoal = ""
    @Published var profileDaysPerWeek = 0
    @Published var overviewText = ""
    @Published var overviewFacts: [String] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    /// Stored custom name for program edit saves; empty when using the default possessive title.
    var programName: String { customProgramName ?? "" }

    var displayTitle: String {
        if let custom = customProgramName?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom.uppercased()
        }
        return UserDisplayName.possessiveProgramTitle(from: profileName)
    }

    /// Value to pre-fill in the rename field (preserves custom casing when set).
    var renameFieldValue: String {
        if let custom = customProgramName?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return displayTitle
    }

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

            profileName = profile.name
            profileGoal = profile.goal
            profileDaysPerWeek = profile.daysPerWeek
        } catch {
            profileName = ""
            print("[ProgramViewModel] profile load error: \(error)")
        }

        do {
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
            customProgramName = Self.resolvedCustomName(from: program.programContent.name)
            programWeek = program.programContent.week ?? 1
            days = program.programContent.days ?? []
            buildOverview()
        } catch {
            days = []
            customProgramName = nil
            programContent = nil
            overviewText = ""
            overviewFacts = []
            print("[ProgramViewModel] program load error: \(error)")
        }

        isLoading = false
    }

    func saveProgramName(_ input: String, userId: UUID) async throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            try await clearCustomProgramName(userId: userId)
            customProgramName = nil
        } else {
            try await ProgramService.updateProgramName(profileId: userId, name: trimmed)
            customProgramName = trimmed
        }

        if let content = programContent {
            programContent = ProgramContent(
                name: trimmed.isEmpty ? nil : trimmed,
                week: content.week,
                days: content.days,
                overview: content.overview,
                description: content.description,
                rationale: content.rationale,
                duration: content.duration,
                length: content.length
            )
        }
    }

    private func clearCustomProgramName(userId: UUID) async throws {
        guard let content = programContent else { return }
        guard let data = try? JSONEncoder().encode(content),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ProgramServiceError.server("Could not update program")
        }
        dict.removeValue(forKey: "name")
        try await ProgramService.saveProgram(profileId: userId, programContent: dict)
    }

    private static func resolvedCustomName(from storedName: String?) -> String? {
        guard let storedName = storedName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !storedName.isEmpty,
              storedName.caseInsensitiveCompare("My Program") != .orderedSame
        else { return nil }
        return storedName
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
