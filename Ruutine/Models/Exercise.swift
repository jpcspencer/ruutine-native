import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let difficulty: String

    enum CodingKeys: String, CodingKey {
        case id, name, difficulty
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
    }
}
