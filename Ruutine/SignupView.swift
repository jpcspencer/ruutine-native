import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var isSigningUp = false
    @State private var errorMessage: String?
    @State private var passwordMismatchError = false
    @State private var showEmailConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
        case confirmPassword
    }

    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(RuutineColor.foreground)
                            .frame(width: 44, height: 44, alignment: .leading)
                    }
                    .padding(.leading, -12)

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
                    passwordField
                    confirmPasswordField

                    if passwordMismatchError {
                        Text("Passwords do not match")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
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
                            .foregroundColor(.red)
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
        .navigationDestination(isPresented: $showEmailConfirmation) {
            EmailConfirmationView()
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
                    focusedField == .password ? RuutineColor.accent : RuutineColor.border,
                    lineWidth: focusedField == .password ? 2 : 1.5
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
                    focusedField == .confirmPassword ? RuutineColor.accent : RuutineColor.border,
                    lineWidth: focusedField == .confirmPassword ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func signUp() {
        guard !isSigningUp else { return }
        errorMessage = nil
        passwordMismatchError = false

        guard password == confirmPassword else {
            passwordMismatchError = true
            return
        }

        isSigningUp = true

        Task {
            do {
                try await authVM.signUp(email: email, password: password)
                showEmailConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningUp = false
        }
    }
}

struct EmailConfirmationView: View {
    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()
            Text("Check your email to confirm your account")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(RuutineColor.foreground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SignupView()
            .environmentObject(AuthViewModel())
    }
}
