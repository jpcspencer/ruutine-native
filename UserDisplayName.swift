import Foundation

enum UserDisplayName {
    private static let placeholderNames: Set<String> = [
        "there",
        "pending",
        "not provided",
    ]

    /// Empty, whitespace-only, or a known placeholder counts as no name.
    static func hasRealName(_ name: String?) -> Bool {
        storedName(from: name) != nil
    }

    static func isPlaceholderName(_ name: String) -> Bool {
        placeholderNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    static func firstName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.components(separatedBy: .whitespaces).first ?? trimmed
    }

    /// Trimmed name when real; nil when missing or placeholder.
    static func storedName(from name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, !isPlaceholderName(trimmed) else { return nil }
        return trimmed
    }

    /// Possessive label: `"Jordan's"` or `"Your"`.
    static func possessive(_ name: String?) -> String {
        guard hasRealName(name) else { return "Your" }
        let first = firstName(from: name!)
        if first.lowercased().hasSuffix("s") {
            return "\(first)'"
        }
        return "\(first)'s"
    }

    /// Address form: first name or `"you"`.
    static func address(_ name: String?) -> String {
        guard hasRealName(name) else { return "you" }
        return firstName(from: name!)
    }

    /// Trimmed display name when set; nil when missing or placeholder.
    static func displayName(_ name: String?) -> String? {
        storedName(from: name)
    }

    /// Value to persist on profile rows — empty when missing or placeholder.
    static func normalizedStoredName(_ name: String) -> String {
        storedName(from: name) ?? ""
    }

    /// Uppercased program page title, e.g. `"YOUR PROGRAM"` or `"JORDAN'S PROGRAM"`.
    static func possessiveProgramTitle(from name: String?) -> String {
        let possessive = possessive(name)
        if possessive == "Your" {
            return "YOUR PROGRAM"
        }
        return "\(possessive.uppercased()) PROGRAM"
    }

    /// Pulls a real name from conversational phrases like "call me Tim".
    static func extractFromMessage(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"(?i)call me ([A-Za-z][A-Za-z'-]{0,30})"#,
            #"(?i)my name(?:'s| is) ([A-Za-z][A-Za-z'-]{0,30})"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: trimmed)
            else { continue }

            let candidate = String(trimmed[range])
            if let stored = storedName(from: candidate) {
                return stored
            }
        }

        return nil
    }
}
