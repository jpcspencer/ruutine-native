import SwiftUI

struct WelcomeView: View {
    var body: some View {
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
                    NavigationLink {
                        LoginView()
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

                    NavigationLink {
                        SignupView()
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
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
            .environmentObject(AuthViewModel())
    }
}
