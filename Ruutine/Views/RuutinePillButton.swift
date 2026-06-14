import SwiftUI

/// Shared pill action buttons — primary (Save), secondary (Cancel), tertiary (Done).
struct RuutinePillButton: View {
    enum Style {
        case primary
        case secondary
        case tertiary
    }

    let title: String
    let style: Style
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    private let height: CGFloat = 36
    private let cornerRadius: CGFloat = 10

    var body: some View {
        Button {
            if !isDisabled && !isLoading {
                Haptics.impact(.light)
            }
            action()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.45 : 1)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var label: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(foregroundColor)
                    .scaleEffect(0.8)
            } else {
                Text(title.uppercased())
                    .font(.bebas(16))
                    .tracking(0.6)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .foregroundColor(foregroundColor)
        .frame(height: height)
        .padding(.horizontal, 14)
        .background(backgroundColor)
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(RuutineColor.border, lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return RuutineColor.accentForeground
        case .secondary: return RuutineColor.foreground
        case .tertiary: return RuutineColor.muted
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return RuutineColor.accent
        case .secondary: return RuutineColor.surface
        case .tertiary: return RuutineColor.surface.opacity(0.5)
        }
    }

    private var showsBorder: Bool {
        style == .secondary || style == .tertiary
    }
}

/// Toolbar item without the iOS 26 Liquid Glass shared background bubble.
struct RuutineToolbarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder let content: () -> Content

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement, content: content)
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement, content: content)
        }
    }
}

extension View {
    /// Themed navigation bar — accent tint, no system blue; opaque background.
    func ruutineNavigationChrome() -> some View {
        tint(RuutineColor.accent)
            .toolbarBackground(RuutineColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
