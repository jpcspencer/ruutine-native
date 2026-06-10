import SwiftUI

struct WelcomeView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Text("RUUTINE")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(.white)
                        .tracking(4)

                    Text("Your AI-powered workout coach")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        print("Create Account tapped")
                    } label: {
                        Text("Create Account")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        print("Sign In tapped")
                    } label: {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 1)
                            )
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
    }
}
