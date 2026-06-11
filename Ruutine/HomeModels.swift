import Foundation

struct UserProfile: Codable {
    let id: UUID
    let name: String
    let trainingDays: [Int]
    let unitPreference: String?
    let biologicalSex: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case trainingDays = "training_days"
        case unitPreference = "unit_preference"
        case biologicalSex = "biological_sex"
    }

    var isImperial: Bool {
        unitPreference == "imperial"
    }
}

struct TrainingProgram: Codable {
    let id: UUID
    let userProfileId: UUID
    let weekNumber: Int
    let programContent: ProgramContent

    enum CodingKeys: String, CodingKey {
        case id
        case userProfileId = "user_profile_id"
        case weekNumber = "week_number"
        case programContent = "program_content"
    }
}

struct ProgramContent: Codable {
    let name: String?
    let week: Int?
    let days: [ProgramDay]?
}

struct ProgramDay: Codable {
    let day: Int
    let name: String
    let exercises: [ProgramExercise]?
}

struct ProgramExercise: Codable {
    let name: String
    let sets: Int?
    let reps: String?
}

struct CompletedSession: Codable, Identifiable {
    let id: UUID
    let userProfileId: UUID
    let sessionName: String
    let finishedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userProfileId = "user_profile_id"
        case sessionName = "session_name"
        case finishedAt = "finished_at"
        case createdAt = "created_at"
    }

    var effectiveDate: Date? {
        finishedAt ?? createdAt
    }
}

struct ExerciseLog: Codable {
    let sessionId: UUID?
    let weightKg: Double?
    let reps: Int?
    let exerciseName: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case weightKg = "weight_kg"
        case reps
        case exerciseName = "exercise_name"
    }
}

struct WeekProgress: Identifiable {
    let id: String
    let week: Date
    let volume: Double
    let sessions: Int

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: week)
    }
}

struct TodaySessionData {
    let day: Int
    let name: String
    let exerciseCount: Int
    let completedToday: Bool
}
