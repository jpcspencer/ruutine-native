import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String     // current exercise
        var currentSet: Int          // e.g. 2
        var totalSets: Int           // e.g. 4
        var targetReps: Int?         // optional target reps for the current set
        var weight: Double?          // optional target weight for the current set
        var isResting: Bool          // true while a rest timer is running
        var restEndDate: Date?       // when the current rest timer ends (for a self-counting countdown)
    }

    var workoutName: String          // static for the session, e.g. "Afternoon Workout"
}
