import Combine
import Foundation
import Supabase

enum ExerciseServiceError: LocalizedError {
    case emptyName
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Exercise name cannot be empty."
        case .notSignedIn: return "Sign in to save custom exercises."
        }
    }
}

@MainActor
final class ExerciseService: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var isSaving = false

    func loadExercises(profileId: UUID?) async {
        isLoading = true
        defer { isLoading = false }

        var merged = Exercise.all
        guard let profileId else {
            exercises = Self.sorted(merged)
            return
        }

        do {
            let custom = try await fetchCustomExercises(profileId: profileId)
            merged = Self.mergeCatalog(Exercise.all, with: custom)
            exercises = Self.sorted(merged)
        } catch {
            print("[ExerciseService] load custom exercises error: \(error)")
            exercises = Self.sorted(merged)
        }
    }

    func createCustomExercise(name: String, profileId: UUID) async throws -> Exercise {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExerciseServiceError.emptyName }

        if let existing = exercises.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }

        isSaving = true
        defer { isSaving = false }

        let insert = CustomExerciseInsert(
            userProfileId: profileId,
            name: trimmed,
            primaryMuscle: "Custom",
            secondaryMuscles: [],
            difficulty: "beginner"
        )

        let row: CustomExerciseRow = try await SupabaseClient.shared
            .from("user_custom_exercises")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        let exercise = row.toExercise()
        var next = exercises
        if !next.contains(where: { $0.id == exercise.id }) {
            next.append(exercise)
        }
        exercises = Self.sorted(next)
        return exercise
    }

    private func fetchCustomExercises(profileId: UUID) async throws -> [CustomExerciseRow] {
        try await SupabaseClient.shared
            .from("user_custom_exercises")
            .select()
            .eq("user_profile_id", value: profileId)
            .order("name", ascending: true)
            .execute()
            .value
    }

    private static func mergeCatalog(_ catalog: [Exercise], with custom: [CustomExerciseRow]) -> [Exercise] {
        var byName = Dictionary(
            uniqueKeysWithValues: catalog.map { ($0.name.lowercased(), $0) }
        )
        for row in custom {
            byName[row.name.lowercased()] = row.toExercise()
        }
        return Array(byName.values)
    }

    private static func sorted(_ exercises: [Exercise]) -> [Exercise] {
        exercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

private struct CustomExerciseInsert: Encodable {
    let userProfileId: UUID
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let difficulty: String

    enum CodingKeys: String, CodingKey {
        case name, difficulty
        case userProfileId = "user_profile_id"
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
    }
}

private struct CustomExerciseRow: Decodable {
    let id: UUID
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let difficulty: String

    enum CodingKeys: String, CodingKey {
        case id, name, difficulty
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
    }

    func toExercise() -> Exercise {
        Exercise(
            id: "custom-\(id.uuidString)",
            name: name,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: secondaryMuscles,
            difficulty: difficulty.capitalized
        )
    }
}
