import Combine
import Foundation

final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private static let soundsKey = "ruutine.soundsEnabled"
    private static let hapticsKey = "ruutine.hapticsEnabled"
    private static let notificationsKey = "ruutine.notificationsEnabled"
    private static let keepScreenAwakeKey = "ruutine.keepScreenAwake"

    @Published var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: Self.soundsKey) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Self.hapticsKey) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey) }
    }

    @Published var keepScreenAwake: Bool {
        didSet { UserDefaults.standard.set(keepScreenAwake, forKey: Self.keepScreenAwakeKey) }
    }

    private init() {
        soundsEnabled = Self.bool(forKey: Self.soundsKey)
        hapticsEnabled = Self.bool(forKey: Self.hapticsKey)
        notificationsEnabled = Self.bool(forKey: Self.notificationsKey)
        keepScreenAwake = Self.bool(forKey: Self.keepScreenAwakeKey)
    }

    private static func bool(forKey key: String) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
}
