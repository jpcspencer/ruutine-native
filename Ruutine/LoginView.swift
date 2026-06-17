import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isSigningIn = false
    @State private var signInError: SignInError?
    @State private var resendConfirmationState = ResendConfirmationState.idle
    @FocusState private var focusedField: Field?

    var onNavigateToSignUp: () -> Void = {}

    private enum Field {
        case email
        case password
    }

    private enum ResendConfirmationState: Equatable {
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
                    RuutineNavButton(kind: .iconBack) {
                        dismiss()
                    }
                    .padding(.leading, -8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back")
                            .font(.bebas(40))
                            .foregroundColor(RuutineColor.foreground)

                        Text("Sign in to continue")
                            .font(.system(size: 16))
                            .foregroundColor(RuutineColor.muted)
                    }
                    .padding(.bottom, 8)

                    emailField
                    passwordField

                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            Haptics.impact(.light)
                            print("Forgot Password tapped")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(RuutineColor.muted)
                    }

                    Button {
                        Haptics.impact(.light)
                        signIn()
                    } label: {
                        Group {
                            if isSigningIn {
                                ProgressView()
                                    .tint(RuutineColor.accentForeground)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .foregroundColor(RuutineColor.accentForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RuutineColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isSigningIn)
                    .padding(.top, 8)

                    signInErrorView
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: signInError) { _, error in
            if error != .emailNotConfirmed {
                resendConfirmationState = .idle
            }
        }
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
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }
        }
        .frame(height: 56)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    focusedField == .email ? RuutineColor.accent : RuutineColor.border,
                    lineWidth: focusedField == .email ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var passwordField: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                if password.isEmpty {
                    Text("Password")
                        .foregroundColor(RuutineColor.muted)
                        .padding(.horizontal, 16)
                }

                Group {
                    if showPassword {
                        TextField("", text: $password)
                    } else {
                        SecureField("", text: $password)
                    }
                }
                .foregroundColor(RuutineColor.foreground)
                .padding(.horizontal, 16)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    signIn()
                }
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 16))
                    .foregroundColor(RuutineColor.muted)
                    .frame(width: 44, height: 56)
            }
        }
        .frame(height: 56)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    focusedField == .password ? RuutineColor.accent : RuutineColor.border,
                    lineWidth: focusedField == .password ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var signInErrorView: some View {
        if let signInError {
            VStack(spacing: 8) {
                switch signInError {
                case .invalidCredentials:
                    signInErrorLine("Incorrect email or password.")
                    signUpPromptLine
                case .emailNotConfirmed:
                    signInErrorLine("Email not confirmed.")
                    resendConfirmationView
                case .rateLimited:
                    signInErrorLine("Too many sign-in attempts. Please wait a moment and try again.")
                case .networkUnavailable:
                    signInErrorLine("Couldn't reach Ruu. Check your connection and try again.")
                case .unknown(let message):
                    signInErrorLine(message)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var signUpPromptLine: some View {
        HStack(spacing: 0) {
            Text("Don't have an account? ")
                .foregroundColor(RuutineColor.muted)
            Button {
                Haptics.impact(.light)
                onNavigateToSignUp()
            } label: {
                Text("Sign up")
                    .foregroundColor(RuutineColor.accent)
            }
            .buttonStyle(.plain)
        }
        .font(loginMessageFont)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var resendConfirmationView: some View {
        switch resendConfirmationState {
        case .sent:
            loginMutedLine("Confirmation email sent — check your inbox (and spam).")
        case .sending:
            loginMutedLine("Sending...")
        case .idle:
            resendConfirmationLink
        case .failed(let message):
            signInErrorLine(message)
            resendConfirmationLink
        }
    }

    private var resendConfirmationLink: some View {
        Button {
            Haptics.impact(.light)
            resendConfirmation()
        } label: {
            Text("Resend confirmation email")
                .font(loginMessageFont)
                .foregroundColor(RuutineColor.accent)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func signInErrorLine(_ text: String) -> some View {
        Text(text)
            .font(loginMessageFont)
            .foregroundColor(softErrorColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private func loginMutedLine(_ text: String) -> some View {
        Text(text)
            .font(loginMessageFont)
            .foregroundColor(RuutineColor.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private var loginMessageFont: Font {
        .system(size: 16)
    }

    private var softErrorColor: Color {
        RuutineColor.destructive.opacity(0.78)
    }

    private func signIn() {
        guard !isSigningIn else { return }
        signInError = nil
        resendConfirmationState = .idle
        isSigningIn = true

        Task {
            do {
                try await authVM.signIn(email: email, password: password)
            } catch {
                signInError = SignInError.map(error)
            }
            isSigningIn = false
        }
    }

    private func resendConfirmation() {
        guard resendConfirmationState != .sending else { return }
        resendConfirmationState = .sending

        Task {
            do {
                try await authVM.resendConfirmationEmail(email: email)
                resendConfirmationState = .sent
            } catch {
                let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                resendConfirmationState = .failed(
                    message.isEmpty ? "Couldn't send confirmation email. Try again." : message
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
