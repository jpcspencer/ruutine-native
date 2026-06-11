import Combine
import Foundation
import Supabase

@MainActor
final class ExerciseService: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false

    private static let cacheKey = "cached_exercises"

    func loadExercises(profileId: String) async {
        if let cached = loadFromCache() {
            exercises = cached
            isLoading = false
        } else {
            isLoading = true
        }

        do {
            let fetched = try await fetchFromNetwork(profileId: profileId)
            exercises = fetched
            saveToCache(fetched)
        } catch {
            if exercises.isEmpty, let cached = loadFromCache() {
                exercises = cached
            }
        }

        isLoading = false
    }

    private func fetchFromNetwork(profileId: String) async throws -> [Exercise] {
        guard let url = URL(string: "https://ruutine.app/api/exercises/list?profileId=\(profileId)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let session = try? await SupabaseClient.shared.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(ExerciseListResponse.self, from: data)
        return sortExercises(payload.exercises.map(mapExercise))
    }

    private func mapExercise(_ item: ExerciseAPIItem) -> Exercise {
        Exercise(
            id: item.id ?? Self.idFromName(item.name),
            name: item.name,
            primaryMuscle: item.primaryMuscle ?? "Unknown",
            secondaryMuscles: item.secondaryMuscles ?? [],
            difficulty: item.difficulty ?? "beginner"
        )
    }

    private func sortExercises(_ items: [Exercise]) -> [Exercise] {
        items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadFromCache() -> [Exercise]? {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let cached = try? decoder.decode([Exercise].self, from: data) else { return nil }
        return sortExercises(cached)
    }

    private func saveToCache(_ items: [Exercise]) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    private static func idFromName(_ name: String) -> String {
        name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
    }
}

private struct ExerciseListResponse: Decodable {
    let exercises: [ExerciseAPIItem]
}

private struct ExerciseAPIItem: Decodable {
    let id: String?
    let name: String
    let primaryMuscle: String?
    let secondaryMuscles: [String]?
    let difficulty: String?
}
