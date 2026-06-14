import SwiftUI

/// Themed navigation chrome — back chevrons, pills for Cancel/Save/Done. Uses `RuutineColor`.
struct RuutineNavButton: View {
    enum Kind {
        case back
        case home
        case done
        case cancel
        case save
        case confirm(text: String)
        case close
        case iconBack
        case finish(isLoading: Bool = false)
        case gear
        case custom(text: String, icon: String? = "chevron.left")
    }

    let kind: Kind
    var isDisabled: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            if usesLightImpact { Haptics.impact(.light) }
            action()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var usesLightImpact: Bool {
        switch kind {
        case .save, .confirm, .finish:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var label: some View {
        switch kind {
        case .back:
            chevronOnly(color: RuutineColor.foreground)

        case .home:
            homeCapsule

        case .done:
            pillLabel(title: "Done", style: .tertiary)

        case .cancel:
            pillLabel(title: "Cancel", style: .secondary)

        case .save:
            pillLabel(title: "Save", style: .primary)

        case .confirm(let text):
            pillLabel(title: text, style: .primary)

        case .close:
            chevronOnly(color: RuutineColor.muted, systemName: "xmark")

        case .iconBack:
            chevronOnly(color: RuutineColor.foreground)

        case .finish(let loading):
            finishPill(isLoading: loading)

        case .gear:
            Image(systemName: "gearshape.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(RuutineColor.foreground)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())

        case .custom(let text, let icon):
            if let icon {
                labeledCapsule(text: text.uppercased(), icon: icon)
            } else {
                pillLabel(title: text, style: .tertiary)
            }
        }
    }

    private func chevronOnly(color: Color, systemName: String = "chevron.left") -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private var homeCapsule: some View {
        labeledCapsule(text: "HOME", icon: "chevron.left")
    }

    private func labeledCapsule(text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(RuutineColor.accent)

            Text(text)
                .font(.bebas(16))
                .foregroundColor(RuutineColor.foreground)
                .tracking(0.6)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func pillLabel(title: String, style: RuutinePillButton.Style) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(style == .primary ? RuutineColor.accentForeground : RuutineColor.foreground)
                    .scaleEffect(0.8)
            } else {
                Text(title.uppercased())
                    .font(.bebas(16))
                    .tracking(0.6)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .foregroundColor(pillForeground(style))
        .frame(height: 36)
        .padding(.horizontal, 14)
        .background(pillBackground(style))
        .overlay {
            if style != .primary {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(RuutineColor.border, lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isDisabled ? 0.45 : 1)
    }

    private func pillForeground(_ style: RuutinePillButton.Style) -> Color {
        switch style {
        case .primary: return RuutineColor.accentForeground
        case .secondary: return RuutineColor.foreground
        case .tertiary: return RuutineColor.muted
        }
    }

    private func pillBackground(_ style: RuutinePillButton.Style) -> Color {
        switch style {
        case .primary: return RuutineColor.accent
        case .secondary: return RuutineColor.surface
        case .tertiary: return RuutineColor.surface.opacity(0.5)
        }
    }

    @ViewBuilder
    private func finishPill(isLoading: Bool) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(RuutineColor.accentForeground)
                    .scaleEffect(0.85)
            } else {
                Text("FINISH")
                    .font(.bebas(18))
                    .tracking(0.8)
                    .lineLimit(1)
            }
        }
        .foregroundColor(RuutineColor.accentForeground)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(RuutineColor.accent)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
