import SwiftUI

enum RuutineColor {
    static let background = Color(hex: "#0a0a0a")
    static let surface = Color(hex: "#111111")
    static let border = Color(hex: "#1a1a1a")
    static let foreground = Color(hex: "#f0ece0")
    static let muted = Color(hex: "#888892")
    static let accent = Color(hex: "#f5c518")
    static let accentForeground = Color(hex: "#0a0a0a")
    static let destructive = Color.red
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
