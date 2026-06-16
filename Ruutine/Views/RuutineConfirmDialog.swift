import SwiftUI

struct RuutineConfirmDialog: View {
    let title: String
    let message: String
    let confirmLabel: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 20) {
                Text(title.uppercased())
                    .font(.bebas(24))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(1)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(RuutineColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button {
                        onConfirm()
                    } label: {
                        Text(confirmLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(confirmForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(confirmBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(confirmBorder, lineWidth: isDestructive ? 1 : 0)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(RuutineColor.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: min(320, UIScreen.main.bounds.width - 48))
            .background(RuutineColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.35), radius: 24, y: 8)
        }
        .onAppear {
            Haptics.notify(.warning)
        }
    }

    private var confirmForeground: Color {
        isDestructive ? RuutineColor.destructive : RuutineColor.accentForeground
    }

    private var confirmBackground: Color {
        isDestructive ? RuutineColor.destructive.opacity(0.2) : RuutineColor.accent
    }

    private var confirmBorder: Color {
        isDestructive ? RuutineColor.destructive.opacity(0.85) : .clear
    }
}

private struct RuutineConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmLabel: String
    let isDestructive: Bool
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                RuutineConfirmDialog(
                    title: title,
                    message: message,
                    confirmLabel: confirmLabel,
                    isDestructive: isDestructive,
                    onConfirm: {
                        onConfirm()
                        isPresented = false
                    },
                    onCancel: {
                        isPresented = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1000)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isPresented)
    }
}

extension View {
    func ruutineConfirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmLabel: String,
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            RuutineConfirmModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmLabel: confirmLabel,
                isDestructive: isDestructive,
                onConfirm: onConfirm
            )
        )
    }
}
