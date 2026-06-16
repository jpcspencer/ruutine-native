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
    @FocusState private var focusedField: Field?

    var onNavigateToSignUp: () -> Void = {}

    private enum Field {
        case email
        case password
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
            switch signInError {
            case .invalidCredentials:
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Incorrect email or password. Don't have an account?")
                        .foregroundColor(RuutineColor.destructive)

                    Button {
                        Haptics.impact(.light)
                        onNavigateToSignUp()
                    } label: {
                        Text("Sign up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(RuutineColor.accent)
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
            default:
                if let message = signInError.message {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(RuutineColor.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func signIn() {
        guard !isSigningIn else { return }
        signInError = nil
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
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
