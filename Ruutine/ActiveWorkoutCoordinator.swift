import Combine
import SwiftUI

@MainActor
final class ActiveWorkoutCoordinator: ObservableObject {
    @Published var viewModel: ActiveWorkoutViewModel?
    @Published var isExpanded = false

    func start(initialExercises: [WorkoutExercise]?, workoutName: String?) {
        SoundFX.startWorkout()
        viewModel = ActiveWorkoutViewModel(
            initialExercises: initialExercises,
            workoutName: workoutName
        )
        isExpanded = true
    }

    func minimize() {
        isExpanded = false
    }

    func expand() {
        isExpanded = true
    }

    func end() {
        viewModel = nil
        isExpanded = false
    }
}
