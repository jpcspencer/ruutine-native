import SwiftUI

/// Themed navigation chrome — Back, Home, Done, Finish, etc. Uses `RuutineColor` (active theme).
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
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var label: some View {
        switch kind {
        case .back:
            labeledNav(text: "BACK", icon: "chevron.left")

        case .home:
            labeledNav(text: "HOME", icon: "chevron.left")

        case .done:
            Text("DONE")
                .font(.bebas(17))
                .foregroundColor(RuutineColor.foreground)
                .tracking(0.8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())

        case .cancel:
            Text("CANCEL")
                .font(.bebas(17))
                .foregroundColor(RuutineColor.muted)
                .tracking(0.8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())

        case .save:
            Text("SAVE")
                .font(.bebas(17))
                .foregroundColor(RuutineColor.accent)
                .tracking(0.8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())

        case .confirm(let text):
            Text(text.uppercased())
                .font(.bebas(17))
                .foregroundColor(RuutineColor.accent)
                .tracking(0.8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())

        case .close:
            iconButton("xmark", color: RuutineColor.muted)

        case .iconBack:
            iconButton("chevron.left", color: RuutineColor.accent)

        case .finish(let isLoading):
            finishLabel(isLoading: isLoading)

        case .gear:
            iconButton("gearshape.fill", color: RuutineColor.foreground)

        case .custom(let text, let icon):
            if let icon {
                labeledNav(text: text.uppercased(), icon: icon)
            } else {
                Text(text.uppercased())
                    .font(.bebas(17))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(0.8)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    private func labeledNav(text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(RuutineColor.accent)

            Text(text)
                .font(.bebas(17))
                .foregroundColor(RuutineColor.foreground)
                .tracking(0.8)
        }
        .padding(.horizontal, 2)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func iconButton(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func finishLabel(isLoading: Bool) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(RuutineColor.accentForeground)
                    .scaleEffect(0.85)
            } else {
                Text("FINISH")
                    .font(.bebas(20))
                    .tracking(1)
            }
        }
        .foregroundColor(RuutineColor.accentForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RuutineColor.accent)
        .clipShape(Capsule())
        .frame(minHeight: 44)
        .contentShape(Capsule())
    }
}
