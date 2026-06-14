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
        "Hey! I'm Atlas, your training coach. What should I call you?"

    static let programBuildOpener = "Ready to build your program? Let's start."

    static let programBuildGoalQuestion = "What's your primary training goal?"

    static func chips(for step: OnboardingStep) -> [String] {
        switch step {
        case .greetingName:
            return ["Skip"]
        case .goal:
            return ["Get Stronger", "Build Muscle", "Lose Fat", "General Fitness", "Skip"]
        case .experience:
            return ["Beginner", "Intermediate", "Advanced", "Skip"]
        case .daysPerWeek:
            return ["2", "3", "4", "5", "6", "Skip"]
        case .trainingDays:
            return (1...7).compactMap { dayLabels[$0] } + ["Skip"]
        case .equipment:
            return ["Full Gym", "Dumbbells Only", "Barbells & Rack", "Machines Only", "No Equipment", "Skip"]
        case .injuries, .injuriesCustom:
            return ["None", "Lower Back", "Knee", "Shoulder", "Hip", "Skip"]
        case .gender:
            return ["Male", "Female", "Prefer not to say", "Skip"]
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
        default: return "Message Atlas…"
        }
    }
}

struct OnboardingProgramPayload: Codable {
    let week: Int?
    let days: [OnboardingProgramDay]?
}

struct OnboardingProgramDay: Codable, Identifiable {
    var id: Int { day }
    let day: Int
    let name: String
    let exercises: [OnboardingProgramExercise]?
}

struct OnboardingProgramExercise: Codable, Identifiable {
    var id: String { name }
    let name: String
    let sets: Int?
    let reps: String?
    let rest: String?
    let notes: String?
}
