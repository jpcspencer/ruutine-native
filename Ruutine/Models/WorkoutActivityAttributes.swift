import ActivityKit
import Foundation

enum WeightUnits {
    static let poundsPerKilogram = 2.20462

    static func unitLabel(isImperial: Bool) -> String {
        isImperial ? "lb" : "kg"
    }

    static func kgToDisplay(_ kg: Double, isImperial: Bool) -> Double {
        isImperial ? kg * poundsPerKilogram : kg
    }

    static func displayToKg(_ value: Double, isImperial: Bool) -> Double {
        isImperial ? value / poundsPerKilogram : value
    }

    static func roundedKg(fromDisplayValue value: Double, isImperial: Bool) -> Double {
        (displayToKg(value, isImperial: isImperial) * 10).rounded() / 10
    }

    static func parseDisplayWeight(_ text: String, isImperial: Bool) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed) else { return nil }
        return displayToKg(value, isImperial: isImperial)
    }

    static func formatted(_ value: Double, maximumFractionDigits: Int = 1) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.\(maximumFractionDigits)f", value)
    }

    static func formattedWeight(
        kg: Double,
        isImperial: Bool,
        maximumFractionDigits: Int = 1,
        includeUnit: Bool = true
    ) -> String {
        let displayValue = kgToDisplay(kg, isImperial: isImperial)
        let text = formatted(displayValue, maximumFractionDigits: maximumFractionDigits)
        return includeUnit ? "\(text) \(unitLabel(isImperial: isImperial))" : text
    }
}

enum DistanceUnits {
    static let metersPerKilometer = 1000.0
    static let metersPerMile = 1609.344

    static func unitLabel(isImperial: Bool) -> String {
        isImperial ? "mi" : "km"
    }

    static func metersToDisplay(_ meters: Double, isImperial: Bool) -> Double {
        meters / (isImperial ? metersPerMile : metersPerKilometer)
    }

    static func displayToMeters(_ value: Double, isImperial: Bool) -> Double {
        value * (isImperial ? metersPerMile : metersPerKilometer)
    }

    static func parseDisplayDistance(_ text: String, isImperial: Bool) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value >= 0 else { return nil }
        return displayToMeters(value, isImperial: isImperial)
    }

    static func formattedDistance(
        meters: Double,
        isImperial: Bool,
        maximumFractionDigits: Int = 2,
        includeUnit: Bool = true
    ) -> String {
        let displayValue = metersToDisplay(meters, isImperial: isImperial)
        let text = WeightUnits.formatted(displayValue, maximumFractionDigits: maximumFractionDigits)
        return includeUnit ? "\(text) \(unitLabel(isImperial: isImperial))" : text
    }
}

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String     // current exercise
        var currentSet: Int          // e.g. 2
        var totalSets: Int           // e.g. 4
        var targetReps: Int?         // optional target reps for the current set
        var weight: Double?          // optional target weight for the current set
        var weightUnitLabel: String = "kg"
        var isResting: Bool          // true while a rest timer is running
        var restEndDate: Date?       // when the current rest timer ends (for a self-counting countdown)
    }

    var workoutName: String          // static for the session, e.g. "Afternoon Workout"
}
