import Foundation

enum ExerciseMuscleMap {
    private static let map: [String: String] = [
        "barbell bench press": "Chest",
        "bench press": "Chest",
        "squat": "Quadriceps",
        "back squat": "Quadriceps",
        "barbell squat": "Quadriceps",
        "deadlift": "Back",
        "romanian deadlift": "Hamstrings",
        "overhead press": "Shoulders",
        "barbell row": "Back",
        "pull-up": "Back",
        "pullup": "Back",
        "lat pulldown": "Back",
        "leg press": "Quadriceps",
        "leg curl": "Hamstrings",
        "hip thrust": "Glutes",
        "calf raise": "Calves",
        "plank": "Core",
        "crunch": "Core",
        "bicep curl": "Biceps",
        "tricep pushdown": "Triceps",
        "lateral raise": "Shoulders",
        "incline bench press": "Chest",
        "dumbbell bench press": "Chest",
    ]

    static func muscle(for exerciseName: String) -> String? {
        let key = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let muscle = map[key] {
            return muscle
        }
        return map.first { key.contains($0.key) || $0.key.contains(key) }?.value
    }

    static func muscles(for exerciseNames: [String]) -> [String] {
        var trained = Set<String>()
        for name in exerciseNames {
            if let muscle = muscle(for: name) {
                trained.insert(muscle)
            }
        }
        return trained.sorted()
    }
}
