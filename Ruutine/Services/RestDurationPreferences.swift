import Foundation

enum RestDurationPreferences {
    static let presets = [30, 60, 90, 120, 180]
    static let minimumSeconds = 15
    static let fallbackSeconds = 90
    private static let userDefaultsKey = "defaultRestDurationSeconds"

    static var defaultSeconds: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: userDefaultsKey)
            return stored > 0 ? stored : fallbackSeconds
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
        }
    }

    static func formatted(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
