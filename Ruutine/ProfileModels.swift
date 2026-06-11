import Foundation

struct ProfileDetail: Codable {
    let id: UUID
    let name: String
    let goal: String
    let experienceLevel: String
    let daysPerWeek: Int
    let trainingDays: [Int]
    let equipmentAccess: [String]
    let injuriesLimitations: String?
    let heightCm: Double?
    let weightKg: Double?
    let unitPreference: String?
    let theme: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, goal
        case experienceLevel = "experience_level"
        case daysPerWeek = "days_per_week"
        case trainingDays = "training_days"
        case equipmentAccess = "equipment_access"
        case injuriesLimitations = "injuries_limitations"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case unitPreference = "unit_preference"
        case theme
        case avatarUrl = "avatar_url"
    }
}

struct WeightLog: Codable, Identifiable {
    let id: UUID
    let weightKg: Double
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case weightKg = "weight_kg"
        case loggedAt = "logged_at"
    }
}

enum ProfileLabels {
    static let goals: [String: String] = [
        "strength": "Strength",
        "hypertrophy": "Hypertrophy",
        "endurance": "Endurance",
        "weight_loss": "Weight loss",
        "general": "General fitness",
    ]

    static let experienceLevels: [String: String] = [
        "beginner": "Beginner",
        "intermediate": "Intermediate",
        "advanced": "Advanced",
    ]

    static let equipment: [String: String] = [
        "full_gym": "Full gym",
        "home_gym": "Home gym",
        "dumbbells": "Dumbbells only",
        "kettlebells": "Kettlebells",
        "bands": "Resistance bands",
        "bodyweight": "Bodyweight only",
    ]

    static let themes = ["onyx", "chalk", "ember", "slate"]
    static let themeNames = ["Onyx", "Chalk", "Ember", "Slate"]

    static let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    static func goal(_ value: String) -> String {
        goals[value] ?? value.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func experience(_ value: String) -> String {
        experienceLevels[value] ?? value.capitalized
    }

    static func equipmentList(_ values: [String]) -> String {
        let labels = values.map { equipment[$0] ?? $0.replacingOccurrences(of: "_", with: " ").capitalized }
        return labels.isEmpty ? "—" : labels.joined(separator: ", ")
    }

    static func trainingDays(_ days: [Int]) -> String {
        let labels = weekdayLabels.enumerated().compactMap { index, label in
            days.contains(index + 1) ? label : nil
        }
        return labels.isEmpty ? "—" : labels.joined(separator: ", ")
    }

    static func heightWeight(heightCm: Double?, weightKg: Double?, isImperial: Bool) -> String {
        guard let heightCm, let weightKg else { return "—" }

        if isImperial {
            let totalInches = heightCm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.rounded()) % 12
            let pounds = weightKg * 2.20462
            let weightText = pounds.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", pounds)
                : String(format: "%.1f", pounds)
            return "\(feet)'\(inches)\" · \(weightText) lb"
        }

        let heightText = heightCm.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", heightCm)
            : String(format: "%.1f", heightCm)
        let weightText = weightKg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weightKg)
            : String(format: "%.1f", weightKg)
        return "\(heightText) cm · \(weightText) kg"
    }

    static func weightValue(_ kg: Double, isImperial: Bool) -> String {
        if isImperial {
            let pounds = kg * 2.20462
            let text = pounds.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", pounds)
                : String(format: "%.1f", pounds)
            return "\(text) lb"
        }
        let text = kg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", kg)
            : String(format: "%.1f", kg)
        return "\(text) kg"
    }

    static func logDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func chartStartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
