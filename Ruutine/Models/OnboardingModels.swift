import Foundation

/// Maps to Capacitor `OnboardingChatData` in ~/ruutine/lib/onboarding-chat.ts
struct OnboardingChatData: Equatable {
    var name: String = ""
    var goal: String = ""
    var experienceLevel: String = ""
    var daysPerWeek: Int = 0
    var trainingDays: [Int] = []
    var equipmentAccess: [String] = []
    var injuriesLimitations: String?
    var gender: String?
    var heightCm: Double?
    var weightKg: Double?
    var unitPreference: String = "metric"
    var measurementsSkip: Bool = false
    var measurementsSure: Bool = false
    var nameSkipped: Bool = false

    /// Seeds program-build flow with the user's existing name only; other fields are collected fresh.
    static func forProgramBuild(from profile: ProfileDetail) -> OnboardingChatData {
        var data = OnboardingChatData()
        data.name = UserDisplayName.normalizedStoredName(profile.name)
        data.nameSkipped = true
        data.unitPreference = profile.unitPreference ?? "metric"
        return data
    }
}

enum OnboardingFlow {
    case onboarding
    case programBuild
}

enum OnboardingStep: String, Equatable {
    case greetingName = "greeting_name"
    case goal
    case experience
    case daysPerWeek = "days_per_week"
    case trainingDays = "training_days"
    case equipment
    case injuries
    case injuriesCustom = "injuries_custom"
    case gender
    case measurementsAsk = "measurements_ask"
    case measurementsInput = "measurements_input"
    case generating
    case programPreview = "program_preview"
    case none
}

enum OnboardingMaps {
    static let dayLabels: [Int: String] = [
        1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun",
    ]

    static let greeting =
        "Hey! I'm Ruu, your training coach. What should I call you?"

    static let programBuildOpener = "Ready to build your program? Let's start."

    static let programBuildGoalQuestion = "What's your primary training goal?"

    static func chips(for step: OnboardingStep) -> [String] {
        switch step {
        case .greetingName:
            return []
        case .goal:
            return ["Get Stronger", "Build Muscle", "Lose Fat", "General Fitness"]
        case .experience:
            return ["Beginner", "Intermediate", "Advanced"]
        case .daysPerWeek:
            return ["2", "3", "4", "5", "6"]
        case .trainingDays:
            return (1...7).compactMap { dayLabels[$0] }
        case .equipment:
            return ["Full Gym", "Dumbbells Only", "Barbells & Rack", "Machines Only", "No Equipment"]
        case .injuries, .injuriesCustom:
            return ["None", "Lower Back", "Knee", "Shoulder", "Hip"]
        case .gender:
            return ["Male", "Female", "Prefer not to say"]
        case .measurementsAsk, .measurementsInput:
            return []
        default:
            return []
        }
    }

    static func placeholder(for step: OnboardingStep) -> String {
        switch step {
        case .greetingName: return "Type your name..."
        case .goal: return "e.g. Get stronger, build muscle..."
        case .experience: return "e.g. Beginner, intermediate..."
        case .daysPerWeek: return "e.g. 2, 4, or 5..."
        case .trainingDays: return "e.g. Mon, Wed, Fri..."
        case .equipment: return "e.g. Full gym, dumbbells..."
        case .injuries, .injuriesCustom: return "Add any details..."
        case .gender: return "e.g. Male, female..."
        case .measurementsAsk: return "Enter height and weight below"
        case .measurementsInput: return "Enter height and weight below"
        default: return "Message Ruu…"
        }
    }
}

struct OnboardingProgramPayload: Codable {
    let week: Int?
    let days: [OnboardingProgramDay]?

    init(week: Int? = nil, days: [OnboardingProgramDay]? = nil) {
        self.week = week
        self.days = days
    }

    private enum CodingKeys: String, CodingKey {
        case week, days
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        week = OnboardingProgramDecoding.flexibleInt(from: container, forKey: .week)
        days = try? container.decodeIfPresent([OnboardingProgramDay].self, forKey: .days) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(week, forKey: .week)
        try container.encodeIfPresent(days, forKey: .days)
    }
}

struct OnboardingProgramDay: Codable, Identifiable {
    var id: String { "\(day)-\(name)" }
    let day: Int
    let name: String
    let exercises: [OnboardingProgramExercise]?

    init(day: Int, name: String, exercises: [OnboardingProgramExercise]? = nil) {
        self.day = day
        self.name = name
        self.exercises = exercises
    }

    private enum DecodeKeys: String, CodingKey {
        case day, name, focus, title, label, exercises
    }

    private enum EncodeKeys: String, CodingKey {
        case day, name, exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodeKeys.self)
        day = OnboardingProgramDecoding.flexibleInt(from: container, keys: [.day]) ?? 0
        name = OnboardingProgramDecoding.flexibleString(
            from: container,
            keys: [.name, .focus, .title, .label]
        ) ?? "Workout"
        exercises = (try? container.decodeIfPresent([OnboardingProgramExercise].self, forKey: .exercises)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodeKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(exercises, forKey: .exercises)
    }
}

struct OnboardingProgramExercise: Codable, Identifiable {
    var id: String { name }
    let name: String
    let sets: Int?
    let reps: String?
    let rest: String?
    let notes: String?

    init(
        name: String,
        sets: Int? = nil,
        reps: String? = nil,
        rest: String? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.rest = rest
        self.notes = notes
    }

    private enum DecodeKeys: String, CodingKey {
        case name, exercise, sets, reps, rest, notes, cue
    }

    private enum EncodeKeys: String, CodingKey {
        case name, sets, reps, rest, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodeKeys.self)
        name = OnboardingProgramDecoding.flexibleString(
            from: container,
            keys: [.name, .exercise]
        ) ?? "Exercise"
        sets = OnboardingProgramDecoding.flexibleInt(from: container, forKey: .sets)
        reps = OnboardingProgramDecoding.flexibleStringOrInt(from: container, forKey: .reps)
        rest = OnboardingProgramDecoding.flexibleStringOrInt(from: container, forKey: .rest)
        notes = OnboardingProgramDecoding.flexibleString(from: container, keys: [.notes, .cue])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodeKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(sets, forKey: .sets)
        try container.encodeIfPresent(reps, forKey: .reps)
        try container.encodeIfPresent(rest, forKey: .rest)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

private enum OnboardingProgramDecoding {
    static func flexibleInt<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let string = try? container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Int(trimmed) {
                return value
            }
            if let value = Double(trimmed) {
                return Int(value)
            }
        }
        return nil
    }

    static func flexibleInt<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        keys: [K]
    ) -> Int? {
        for key in keys {
            if let value = flexibleInt(from: container, forKey: key) {
                return value
            }
        }
        return nil
    }

    static func flexibleString<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> String? {
        guard let value = try? container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func flexibleString<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        keys: [K]
    ) -> String? {
        for key in keys {
            if let value = flexibleString(from: container, forKey: key) {
                return value
            }
        }
        return nil
    }

    static func flexibleStringOrInt<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> String? {
        if let value = flexibleString(from: container, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
