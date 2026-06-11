import SwiftUI

private enum AuthRoute: Hashable {
    case login
    case signup
    case emailConfirmation(String)
}

struct WelcomeView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                RuutineColor.background.ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        Text("RUUTINE")
                            .font(.bebas(56))
                            .foregroundColor(RuutineColor.foreground)
                            .tracking(4)

                        Text("Your AI workout coach")
                            .font(.system(size: 15))
                            .foregroundColor(RuutineColor.muted)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            path.append(AuthRoute.login)
                        } label: {
                            Text("Sign In")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(RuutineColor.accentForeground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(RuutineColor.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        Button {
                            path.append(AuthRoute.signup)
                        } label: {
                            Text("Create Account")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(RuutineColor.foreground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(RuutineColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .login:
                    LoginView()
                case .signup:
                    SignupView { email in
                        path.append(AuthRoute.emailConfirmation(email))
                    }
                case .emailConfirmation(let email):
                    EmailConfirmationView(email: email) {
                        path = NavigationPath([AuthRoute.login])
                    }
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthViewModel())
}
