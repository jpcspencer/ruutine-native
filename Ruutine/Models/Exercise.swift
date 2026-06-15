import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let difficulty: String
    let category: ExerciseCategory

    enum CodingKeys: String, CodingKey {
        case id, name, difficulty, category
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
    }

    init(
        id: String,
        name: String,
        primaryMuscle: String,
        secondaryMuscles: [String],
        difficulty: String,
        category: ExerciseCategory = .barbell
    ) {
        self.id = id
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.difficulty = difficulty
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        primaryMuscle = try container.decode(String.self, forKey: .primaryMuscle)
        secondaryMuscles = try container.decode([String].self, forKey: .secondaryMuscles)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        category = try container.decodeIfPresent(ExerciseCategory.self, forKey: .category) ?? .barbell
    }

    static func lookup(name: String) -> Exercise? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
