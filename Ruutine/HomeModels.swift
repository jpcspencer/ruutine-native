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
    let overview: String?
    let description: String?
    let rationale: String?
    let duration: String?
    let length: String?

    enum CodingKeys: String, CodingKey {
        case name, week, days, overview, description, rationale, duration, length
    }

    init(
        name: String? = nil,
        week: Int? = nil,
        days: [ProgramDay]? = nil,
        overview: String? = nil,
        description: String? = nil,
        rationale: String? = nil,
        duration: String? = nil,
        length: String? = nil
    ) {
        self.name = name
        self.week = week
        self.days = days
        self.overview = overview
        self.description = description
        self.rationale = rationale
        self.duration = duration
        self.length = length
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        week = try container.decodeIfPresent(Int.self, forKey: .week)
        days = try container.decodeIfPresent([ProgramDay].self, forKey: .days)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        length = try container.decodeIfPresent(String.self, forKey: .length)
    }

    var storedOverview: String? {
        [overview, description, rationale]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    var storedDuration: String? {
        [duration, length]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
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
    let rest: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name, sets, reps, rest, notes, cue
    }

    init(name: String, sets: Int? = nil, reps: String? = nil, rest: String? = nil, notes: String? = nil) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.rest = rest
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        sets = try container.decodeIfPresent(Int.self, forKey: .sets)
        reps = Self.decodeFlexibleString(from: container, forKey: .reps)
        rest = Self.decodeFlexibleString(from: container, forKey: .rest)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
            ?? (try container.decodeIfPresent(String.self, forKey: .cue))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(sets, forKey: .sets)
        try container.encodeIfPresent(reps, forKey: .reps)
        try container.encodeIfPresent(rest, forKey: .rest)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    private static func decodeFlexibleString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    var prescriptionLine: String {
        let setsLabel = sets.map(String.init) ?? "—"
        let repsLabel = reps ?? "—"
        let restLabel: String
        if let rest, !rest.isEmpty {
            restLabel = rest.lowercased().contains("rest") ? rest : "\(rest) rest"
        } else {
            restLabel = "— rest"
        }
        return "\(setsLabel)×\(repsLabel) · \(restLabel)"
    }
}

struct CompletedSession: Codable, Identifiable {
    let id: UUID
    let userProfileId: UUID
    let sessionName: String
    let finishedAt: Date?
    let createdAt: Date?
    let exercisesCompleted: [WorkoutSessionService.SessionExerciseCompletedJSON]?

    enum CodingKeys: String, CodingKey {
        case id
        case userProfileId = "user_profile_id"
        case sessionName = "session_name"
        case finishedAt = "finished_at"
        case createdAt = "created_at"
        case exercisesCompleted = "exercises_completed"
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
