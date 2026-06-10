import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            Color.ruuBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.ruuForeground)
                            .frame(width: 44, height: 44, alignment: .leading)
                    }
                    .padding(.leading, -12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.ruuForeground)

                        Text("Sign in to continue")
                            .font(.system(size: 16))
                            .foregroundColor(.ruuMuted)
                    }
                    .padding(.bottom, 8)

                    emailField
                    passwordField

                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            print("Forgot Password tapped")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.ruuMuted)
                    }

                    Button {
                        signIn()
                    } label: {
                        Group {
                            if isSigningIn {
                                ProgressView()
                                    .tint(.ruuAccentForeground)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .foregroundColor(.ruuAccentForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.ruuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isSigningIn)
                    .padding(.top, 8)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
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
                    .foregroundColor(.ruuMuted)
                    .padding(.horizontal, 16)
            }

            TextField("", text: $email)
                .foregroundColor(.ruuForeground)
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
        .background(Color.ruuSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    focusedField == .email ? Color.ruuAccent : Color.ruuBorder,
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
                        .foregroundColor(.ruuMuted)
                        .padding(.horizontal, 16)
                }

                Group {
                    if showPassword {
                        TextField("", text: $password)
                    } else {
                        SecureField("", text: $password)
                    }
                }
                .foregroundColor(.ruuForeground)
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
                    .foregroundColor(.ruuMuted)
                    .frame(width: 44, height: 56)
            }
        }
        .frame(height: 56)
        .background(Color.ruuSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    focusedField == .password ? Color.ruuAccent : Color.ruuBorder,
                    lineWidth: focusedField == .password ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func signIn() {
        guard !isSigningIn else { return }
        errorMessage = nil
        isSigningIn = true

        Task {
            do {
                try await authVM.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
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
