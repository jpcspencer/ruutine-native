import SwiftUI

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

    static let ruuBackground = Color(hex: "#0a0a0a")
    static let ruuSurface = Color(hex: "#111111")
    static let ruuBorder = Color(hex: "#1a1a1a")
    static let ruuForeground = Color(hex: "#f0ece0")
    static let ruuMuted = Color(hex: "#888892")
    static let ruuAccent = Color(hex: "#f5c518")
    static let ruuAccentForeground = Color(hex: "#0a0a0a")
}

extension Font {
    static func ruuBebas(_ size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size)
    }
}

struct RuuCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.ruuSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ruuBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func ruuCard(padding: CGFloat = 16) -> some View {
        modifier(RuuCardModifier(padding: padding))
    }
}
