import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    let prefilledEmail: String

    @State private var email: String
    @State private var submitState = SubmitState.idle
    @FocusState private var isEmailFocused: Bool

    init(prefilledEmail: String = "") {
        self.prefilledEmail = prefilledEmail
        _email = State(initialValue: prefilledEmail)
    }

    private enum SubmitState: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if submitState == .sent {
                        successContent
                    } else {
                        formContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDragIndicator(.visible)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reset Password")
                    .font(.bebas(40))
                    .foregroundColor(RuutineColor.foreground)

                Text("Enter your email and we'll send you a reset link.")
                    .font(.system(size: 16))
                    .foregroundColor(RuutineColor.muted)
            }
            .padding(.bottom, 8)

            emailField

            Button {
                Haptics.impact(.light)
                sendResetLink()
            } label: {
                Group {
                    if submitState == .sending {
                        ProgressView()
                            .tint(RuutineColor.accentForeground)
                    } else {
                        Text("Send Reset Link")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundColor(RuutineColor.accentForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RuutineColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.45)
            .padding(.top, 8)

            if case .failed(let message) = submitState {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.destructive.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    private var successContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reset Password")
                    .font(.bebas(40))
                    .foregroundColor(RuutineColor.foreground)

                Text("If an account exists for that email, we've sent a reset link. Check your inbox (and spam).")
                    .font(.system(size: 16))
                    .foregroundColor(RuutineColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Haptics.impact(.light)
                dismiss()
            } label: {
                Text("Back to Sign In")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(RuutineColor.accentForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(RuutineColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var emailField: some View {
        ZStack(alignment: .leading) {
            if email.isEmpty {
                Text("Email")
                    .foregroundColor(RuutineColor.muted)
                    .padding(.horizontal, 16)
            }

            TextField("", text: $email)
                .foregroundColor(RuutineColor.foreground)
                .padding(.horizontal, 16)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .focused($isEmailFocused)
                .submitLabel(.go)
                .onSubmit {
                    if canSend {
                        sendResetLink()
                    }
                }
        }
        .frame(height: 56)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isEmailFocused ? RuutineColor.accent : RuutineColor.border,
                    lineWidth: isEmailFocused ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(submitState == .sending)
    }

    private var canSend: Bool {
        guard submitState != .sending else { return false }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.contains("@")
    }

    private func sendResetLink() {
        guard canSend else { return }
        submitState = .sending

        Task {
            do {
                try await authVM.resetPassword(email: email)
                submitState = .sent
            } catch {
                submitState = .failed(mapResetError(error))
            }
        }
    }

    private func mapResetError(_ error: Error) -> String {
        let signInError = SignInError.map(error)
        if let message = signInError.message {
            return message
        }
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "Couldn't send reset link. Try again." : message
    }
}

#Preview {
    ForgotPasswordView(prefilledEmail: "you@example.com")
        .environmentObject(AuthViewModel())
}
