import Foundation

// Capacitor reference: ~/ruutine/lib/exercise-muscle-map.ts

enum ExerciseMuscleMap {
    /// Fallback name map when glossary lookup misses.
    private static let exerciseNameMap: [String: String] = [
        "barbell bench press": "Chest",
        "bench press": "Chest",
        "smith machine bench press": "Chest",
        "smith machine bench press (flat)": "Chest",
        "dumbbell bench press": "Chest",
        "incline barbell bench press": "Chest",
        "incline dumbbell press": "Chest",
        "incline bench press": "Chest",
        "decline bench press": "Chest",
        "dumbbell fly": "Chest",
        "cable crossover": "Chest",
        "cable fly": "Chest",
        "chest press": "Chest",
        "machine chest press": "Chest",
        "pec deck": "Chest",
        "push-up": "Chest",
        "pushup": "Chest",
        "chest dip": "Chest",
        "overhead press": "Shoulders",
        "barbell overhead press": "Shoulders",
        "seated overhead press": "Shoulders",
        "dumbbell shoulder press": "Shoulders",
        "military press": "Shoulders",
        "arnold press": "Shoulders",
        "smith machine shoulder press": "Shoulders",
        "lateral raise": "Shoulders",
        "dumbbell lateral raise": "Shoulders",
        "cable lateral raise": "Shoulders",
        "front raise": "Shoulders",
        "face pull": "Shoulders",
        "face pulls": "Shoulders",
        "rear delt fly": "Shoulders",
        "reverse fly": "Shoulders",
        "upright row": "Shoulders",
        "barbell row": "Back",
        "barbell rows": "Back",
        "bent over row": "Back",
        "smith machine bent over row": "Back",
        "dumbbell row": "Back",
        "one arm dumbbell row": "Back",
        "pull-up": "Back",
        "pullup": "Back",
        "chin-up": "Back",
        "lat pulldown": "Back",
        "wide grip lat pulldown": "Back",
        "close grip lat pulldown": "Back",
        "seated cable row": "Back",
        "cable row": "Back",
        "t-bar row": "Back",
        "deadlift": "Back",
        "conventional deadlift": "Back",
        "sumo deadlift": "Back",
        "smith machine deadlift": "Back",
        "rack pull": "Back",
        "hyperextension": "Back",
        "back extension": "Back",
        "shrug": "Back",
        "barbell shrug": "Back",
        "dumbbell shrug": "Back",
        "smith machine shrug": "Back",
        "barbell curl": "Biceps",
        "ez bar curl": "Biceps",
        "dumbbell curl": "Biceps",
        "hammer curl": "Biceps",
        "incline dumbbell curl": "Biceps",
        "preacher curl": "Biceps",
        "cable curl": "Biceps",
        "concentration curl": "Biceps",
        "machine curl": "Biceps",
        "tricep pushdown": "Triceps",
        "triceps pushdown": "Triceps",
        "cable tricep pushdown": "Triceps",
        "skull crusher": "Triceps",
        "close-grip bench press": "Triceps",
        "close grip bench press": "Triceps",
        "overhead tricep extension": "Triceps",
        "tricep dip": "Triceps",
        "dip": "Triceps",
        "tricep kickback": "Triceps",
        "rope pushdown": "Triceps",
        "barbell squat": "Quadriceps",
        "squat": "Quadriceps",
        "smith machine squat": "Quadriceps",
        "smith machine pause squat": "Quadriceps",
        "pause squat": "Quadriceps",
        "front squat": "Quadriceps",
        "goblet squat": "Quadriceps",
        "hack squat": "Quadriceps",
        "leg press": "Quadriceps",
        "leg extension": "Quadriceps",
        "bulgarian split squat": "Quadriceps",
        "split squat": "Quadriceps",
        "lunge": "Quadriceps",
        "walking lunge": "Quadriceps",
        "romanian deadlift": "Hamstrings",
        "smith machine romanian deadlift": "Hamstrings",
        "rdl": "Hamstrings",
        "leg curl": "Hamstrings",
        "lying leg curl": "Hamstrings",
        "seated leg curl": "Hamstrings",
        "nordic curl": "Hamstrings",
        "good morning": "Hamstrings",
        "stiff leg deadlift": "Hamstrings",
        "hip thrust": "Glutes",
        "smith machine hip thrust": "Glutes",
        "barbell hip thrust": "Glutes",
        "glute bridge": "Glutes",
        "cable kickback": "Glutes",
        "donkey kick": "Glutes",
        "sumo squat": "Glutes",
        "calf raise": "Calves",
        "standing calf raise": "Calves",
        "seated calf raise": "Calves",
        "smith machine calf raise": "Calves",
        "leg press calf raise": "Calves",
        "donkey calf raise": "Calves",
        "plank": "Core",
        "crunch": "Core",
        "sit-up": "Core",
        "situp": "Core",
        "ab wheel": "Core",
        "cable crunch": "Core",
        "hanging leg raise": "Core",
        "leg raise": "Core",
        "russian twist": "Core",
        "oblique crunch": "Core",
        "side plank": "Core",
        "dead bug": "Core",
        "mountain climber": "Core",
    ]

    static func muscle(for exerciseName: String) -> String? {
        muscles(forExerciseName: exerciseName).first
    }

    static func muscles(forExerciseName exerciseName: String) -> [String] {
        var trained = Set<String>()

        if let exercise = Exercise.lookup(name: exerciseName) {
            addHeatmapMuscle(exercise.primaryMuscle, to: &trained)
            for secondary in exercise.secondaryMuscles {
                addHeatmapMuscle(secondary, to: &trained)
            }
        }

        if !trained.isEmpty {
            return trained.sorted()
        }

        let key = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let mapped = exerciseNameMap[key] {
            trained.insert(mapped)
        } else if let mapped = exerciseNameMap.first(where: { key.contains($0.key) || $0.key.contains(key) })?.value {
            trained.insert(mapped)
        }

        return trained.sorted()
    }

    static func muscles(for exerciseNames: [String]) -> [String] {
        var trained = Set<String>()
        for name in exerciseNames {
            muscles(forExerciseName: name).forEach { trained.insert($0) }
        }
        return trained.sorted()
    }

    static func muscles(for exercises: [RecapExercise]) -> [String] {
        var trained = Set<String>()
        for exercise in exercises {
            if let primary = exercise.primaryMuscle {
                addHeatmapMuscle(primary, to: &trained)
            }
            if let glossary = Exercise.lookup(name: exercise.name) {
                addHeatmapMuscle(glossary.primaryMuscle, to: &trained)
                for secondary in glossary.secondaryMuscles {
                    addHeatmapMuscle(secondary, to: &trained)
                }
            }
            muscles(forExerciseName: exercise.name).forEach { trained.insert($0) }
        }
        return trained.sorted()
    }

    static func heatmapMuscle(from label: String) -> String? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Chest", "Upper chest":
            return "Chest"
        case "Shoulders", "Rotator cuff":
            return "Shoulders"
        case "Back", "Upper back", "Lats", "Traps", "Lower back":
            return "Back"
        case "Biceps", "Brachialis":
            return "Biceps"
        case "Triceps":
            return "Triceps"
        case "Quadriceps", "Quads", "Legs":
            return "Quadriceps"
        case "Hamstrings":
            return "Hamstrings"
        case "Glutes":
            return "Glutes"
        case "Calves":
            return "Calves"
        case "Core", "Obliques", "Abs":
            return "Core"
        default:
            return MuscleMapDefinitions.muscleToSvgIds[label] != nil ? label : nil
        }
    }

    private static func addHeatmapMuscle(_ label: String, to trained: inout Set<String>) {
        guard let muscle = heatmapMuscle(from: label) else { return }
        trained.insert(muscle)
    }
}
