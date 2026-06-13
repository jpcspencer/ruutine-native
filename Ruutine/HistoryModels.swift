import Foundation

struct ExerciseLogDetail: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID?
    let exerciseName: String?
    let weightKg: Double?
    let reps: Int?
    let setNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case exerciseName = "exercise_name"
        case weightKg = "weight_kg"
        case reps
        case setNumber = "set_number"
    }
}

struct BestSet: Equatable {
    let weightKg: Double
    let reps: Int

    var volume: Double {
        weightKg * Double(reps)
    }
}

struct HistorySessionItem: Identifiable {
    let id: UUID
    let sessionName: String
    let date: Date
    let volume: Double
    let exercises: [String]
    let bestSets: [String: BestSet]
}

struct HistoryMonthGroup: Identifiable {
    let id: String
    let title: String
    let sessions: [HistorySessionItem]
}

enum HistoryFormatting {
    static func monthHeader(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).uppercased()
    }

    static func sessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    static func detailDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date).uppercased()
    }

    static func detailTimeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    static func detailDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    static func volumeLabel(_ volume: Double, isImperial: Bool) -> String {
        let value = isImperial ? volume * 2.20462 : volume
        let unit = isImperial ? "lb" : "kg"
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
        return "🏆 \(formatted) \(unit)"
    }

    static func bestSetLabel(_ best: BestSet?, isImperial: Bool) -> String {
        guard let best else { return "—" }
        if best.weightKg > 0 {
            let weight = isImperial ? best.weightKg * 2.20462 : best.weightKg
            let unit = isImperial ? "lb" : "kg"
            let weightText = weight.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", weight)
                : String(format: "%.1f", weight)
            return "\(weightText) \(unit) × \(best.reps) reps"
        }
        return "\(best.reps) reps"
    }

    static func setLine(weightKg: Double?, reps: Int?, isImperial: Bool) -> String {
        let weight = weightKg ?? 0
        let repCount = reps ?? 0
        if weight > 0 {
            let display = isImperial ? weight * 2.20462 : weight
            let unit = isImperial ? "lb" : "kg"
            let weightText = display.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", display)
                : String(format: "%.1f", display)
            return "\(weightText) \(unit) × \(repCount) reps"
        }
        return "\(repCount) reps"
    }
}

enum ExerciseLogDeduper {
    static func dedupe<T: Identifiable>(_ rows: [T], key: (T) -> String, prefer: (T, T) -> T) -> [T] {
        var best: [String: T] = [:]
        for row in rows {
            let rowKey = key(row)
            if let existing = best[rowKey] {
                best[rowKey] = prefer(existing, row)
            } else {
                best[rowKey] = row
            }
        }
        return Array(best.values)
    }

    static func dedupeLogs(_ logs: [ExerciseLogDetail]) -> [ExerciseLogDetail] {
        dedupe(logs, key: { log in
            "\(log.exerciseName ?? "")-\(log.setNumber ?? 0)"
        }, prefer: { existing, row in
            if existing.weightKg == nil, row.weightKg != nil {
                return row
            }
            return existing
        })
    }
}
