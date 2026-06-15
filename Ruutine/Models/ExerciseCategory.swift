import Foundation

enum InputKind {
    case weightReps
    case addedWeightReps
    case assistedReps
    case repsOnly
    case cardio
    case duration
}

enum ExerciseCategory: String, Codable, Hashable {
    case barbell
    case dumbbell
    case machineOther = "machine_other"
    case weightedBodyweight = "weighted_bodyweight"
    case assistedBodyweight = "assisted_bodyweight"
    case repsOnly = "reps_only"
    case cardio
    case duration

    var inputKind: InputKind {
        switch self {
        case .barbell, .dumbbell, .machineOther:
            return .weightReps
        case .weightedBodyweight:
            return .addedWeightReps
        case .assistedBodyweight:
            return .assistedReps
        case .repsOnly:
            return .repsOnly
        case .cardio:
            return .cardio
        case .duration:
            return .duration
        }
    }
}
