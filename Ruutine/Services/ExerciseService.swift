import Combine
import Foundation

@MainActor
final class ExerciseService: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false

    func loadExercises(profileId: String) async {
        isLoading = true
        exercises = Exercise.all.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        isLoading = false
    }
}
