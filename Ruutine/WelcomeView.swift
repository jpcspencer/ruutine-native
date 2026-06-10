import SwiftUI

struct WelcomeView: View {
    var body: some View {
        ZStack {
            Color.ruuBackground.ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Text("RUUTINE")
                        .font(.system(size: 52, weight: .black))
                        .foregroundColor(.ruuForeground)
                        .tracking(6)

                    Text("Your AI workout coach")
                        .font(.system(size: 15))
                        .foregroundColor(.ruuMuted)
                }

                Spacer()

                VStack(spacing: 12) {
                    NavigationLink {
                        LoginView()
                    } label: {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.ruuAccentForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.ruuAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Button {
                        print("Create Account tapped")
                    } label: {
                        Text("Create Account")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.ruuForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.ruuSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
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
