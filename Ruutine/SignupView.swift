import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    let onConfirmationRequired: (String) -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var isSigningUp = false
    @State private var errorMessage: String?
    @State private var didAttemptSubmit = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
        case confirmPassword
    }

    init(onConfirmationRequired: @escaping (String) -> Void = { _ in }) {
        self.onConfirmationRequired = onConfirmationRequired
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
                        Text("Create Account")
                            .font(.bebas(40))
                            .foregroundColor(RuutineColor.foreground)

                        Text("Start your journey")
                            .font(.system(size: 16))
                            .foregroundColor(RuutineColor.muted)
                    }
                    .padding(.bottom, 8)

                    emailField

                    if let emailError {
                        Text(emailError)
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.destructive)
                    }

                    passwordField
                    confirmPasswordField

                    if let passwordMatchError {
                        Text(passwordMatchError)
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.destructive)
                    }

                    Button {
                        signUp()
                    } label: {
                        Group {
                            if isSigningUp {
                                ProgressView()
                                    .tint(RuutineColor.accentForeground)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .foregroundColor(RuutineColor.accentForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RuutineColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isSigningUp)
                    .padding(.top, 8)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.destructive)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Already have an account? Sign in")
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.muted)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
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

    private var emailError: String? {
        guard didAttemptSubmit else { return nil }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Email is required." }
        if !AuthViewModel.isValidEmail(trimmed) { return "Enter a valid email address." }
        return nil
    }

    private var passwordMatchError: String? {
        guard didAttemptSubmit else { return nil }
        if password.count < 6 { return "Password must be at least 6 characters." }
        if password != confirmPassword { return "Passwords do not match." }
        return nil
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
                    fieldBorderColor(isInvalid: emailError != nil, isFocused: focusedField == .email),
                    lineWidth: focusedField == .email || emailError != nil ? 2 : 1.5
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
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmPassword
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
                    fieldBorderColor(isInvalid: passwordMatchError != nil, isFocused: focusedField == .password),
                    lineWidth: focusedField == .password || passwordMatchError != nil ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var confirmPasswordField: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                if confirmPassword.isEmpty {
                    Text("Confirm Password")
                        .foregroundColor(RuutineColor.muted)
                        .padding(.horizontal, 16)
                }

                Group {
                    if showConfirmPassword {
                        TextField("", text: $confirmPassword)
                    } else {
                        SecureField("", text: $confirmPassword)
                    }
                }
                .foregroundColor(RuutineColor.foreground)
                .padding(.horizontal, 16)
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.go)
                .onSubmit {
                    signUp()
                }
            }

            Button {
                showConfirmPassword.toggle()
            } label: {
                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
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
                    fieldBorderColor(isInvalid: passwordMatchError != nil, isFocused: focusedField == .confirmPassword),
                    lineWidth: focusedField == .confirmPassword || passwordMatchError != nil ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func fieldBorderColor(isInvalid: Bool, isFocused: Bool) -> Color {
        if isInvalid { return RuutineColor.destructive }
        if isFocused { return RuutineColor.accent }
        return RuutineColor.border
    }

    private func signUp() {
        guard !isSigningUp else { return }
        didAttemptSubmit = true
        errorMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuthViewModel.isValidEmail(trimmedEmail) else { return }
        guard password.count >= 6 else { return }
        guard password == confirmPassword else { return }

        isSigningUp = true

        Task {
            do {
                let outcome = try await authVM.signUp(email: trimmedEmail, password: password)
                switch outcome {
                case .sessionActive:
                    break
                case .confirmationRequired(let confirmedEmail):
                    onConfirmationRequired(confirmedEmail)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningUp = false
        }
    }
}

struct EmailConfirmationView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let email: String
    let onBackToSignIn: () -> Void

    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "envelope.fill")
                    .font(.system(size: 48))
                    .foregroundColor(RuutineColor.accent)

                Text("CHECK YOUR EMAIL")
                    .font(.bebas(36))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(1)
                    .multilineTextAlignment(.center)

                Text("We sent a confirmation link to \(email). Tap it to confirm your account, then come back and sign in.")
                    .font(.system(size: 15))
                    .foregroundColor(RuutineColor.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Button(action: onBackToSignIn) {
                    Text("Back to Sign In")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(RuutineColor.accentForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RuutineColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Signup") {
    NavigationStack {
        SignupView()
            .environmentObject(AuthViewModel())
    }
}

#Preview("Email Confirmation") {
    NavigationStack {
        EmailConfirmationView(email: "you@example.com") {}
    }
}
