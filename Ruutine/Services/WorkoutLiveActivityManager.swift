import ActivityKit
import Foundation

@available(iOS 16.1, *)
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()
    private var activity: Activity<WorkoutActivityAttributes>?

    func start(workoutName: String, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity != nil { update(state); return }
        let attributes = WorkoutActivityAttributes(workoutName: workoutName)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {
            print("LiveActivity start error: \(error)")
        }
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        let current = activity
        activity = nil
        guard let current else { return }
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}
