import Combine
import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case onyx, chalk, bloom, slate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onyx: return "Onyx"
        case .chalk: return "Chalk"
        case .bloom: return "Bloom"
        case .slate: return "Slate"
        }
    }

    var isLight: Bool { self == .chalk }

    static func from(storedValue raw: String?) -> AppTheme {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .onyx
        }
        let migrated = raw == "ember" ? AppTheme.bloom.rawValue : raw
        return AppTheme(rawValue: migrated) ?? .onyx
    }
}

struct ThemePalette {
    let background, surface, surfaceElevated, border, foreground, muted, accent, accentForeground, destructive: Color
}

extension AppTheme {
    var palette: ThemePalette {
        switch self {
        case .onyx:
            return ThemePalette(
                background: Color(hex: "0A0A0A"),
                surface: Color(hex: "111111"),
                surfaceElevated: Color(hex: "161616"),
                border: Color(hex: "242424"),
                foreground: Color(hex: "F0ECE0"),
                muted: Color(hex: "888892"),
                accent: Color(hex: "F5C518"),
                accentForeground: Color(hex: "0A0A0A"),
                destructive: Color(hex: "EF4444")
            )
        case .chalk:
            return ThemePalette(
                background: Color(hex: "F4F1E9"),
                surface: Color(hex: "FBF9F3"),
                surfaceElevated: Color(hex: "FFFFFF"),
                border: Color(hex: "E2DCCF"),
                foreground: Color(hex: "1C1A15"),
                muted: Color(hex: "78726A"),
                accent: Color(hex: "D99A0A"),
                accentForeground: Color(hex: "1C1A15"),
                destructive: Color(hex: "D33A2C")
            )
        case .bloom:
            return ThemePalette(
                background: Color(hex: "1A1020"),
                surface: Color(hex: "241730"),
                surfaceElevated: Color(hex: "2C1D3A"),
                border: Color(hex: "3C2B4C"),
                foreground: Color(hex: "F4E9F1"),
                muted: Color(hex: "A98FB4"),
                accent: Color(hex: "F58FB4"),
                accentForeground: Color(hex: "1A1020"),
                destructive: Color(hex: "F43F5E")
            )
        case .slate:
            return ThemePalette(
                background: Color(hex: "0E1622"),
                surface: Color(hex: "16202F"),
                surfaceElevated: Color(hex: "1B2738"),
                border: Color(hex: "283446"),
                foreground: Color(hex: "E3E9F2"),
                muted: Color(hex: "8593A6"),
                accent: Color(hex: "5B9DFF"),
                accentForeground: Color(hex: "0E1622"),
                destructive: Color(hex: "EF4444")
            )
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let storageKey = "ruutine.selectedTheme"

    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: storageKey) }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey) {
            let migrated = raw == "ember" ? AppTheme.bloom.rawValue : raw
            if let saved = AppTheme(rawValue: migrated) {
                current = saved
                if migrated != raw {
                    UserDefaults.standard.set(migrated, forKey: storageKey)
                }
                return
            }
        }
        current = .onyx
    }

    func setTheme(_ theme: AppTheme) { current = theme }

    func applyFromProfile(_ themeValue: String?) {
        setTheme(AppTheme.from(storedValue: themeValue))
    }

    func resetToDefault() {
        setTheme(.onyx)
    }
}

enum RuutineColor {
    private static var p: ThemePalette { ThemeManager.shared.current.palette }

    static var background: Color { p.background }
    static var surface: Color { p.surface }
    static var surfaceElevated: Color { p.surfaceElevated }
    static var border: Color { p.border }
    static var foreground: Color { p.foreground }
    static var muted: Color { p.muted }
    static var accent: Color { p.accent }
    static var accentForeground: Color { p.accentForeground }
    static var destructive: Color { p.destructive }

    /// Modal overlay scrim — theme-aware instead of hardcoded black.
    static var scrim: Color { p.foreground.opacity(0.55) }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var ruuHexString: String {
        UIColor(self).ruuHexString
    }
}

extension UIColor {
    var ruuHexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

struct RuuCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func ruuCard(padding: CGFloat = 16) -> some View {
        modifier(RuuCardModifier(padding: padding))
    }
}
