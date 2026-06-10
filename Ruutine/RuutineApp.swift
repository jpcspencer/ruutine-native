//
//  RuutineApp.swift
//  Ruutine
//
//  Created by Jordan Spencer on 6/6/26.
//

import SwiftUI

@main
struct RuutineApp: App {
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isLoading {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Text("RUUTINE")
                            .font(.system(size: 48, weight: .black))
                            .foregroundColor(.white)
                            .tracking(4)
                    }
                } else if authVM.session != nil {
                    Text("Home — coming soon")
                        .foregroundColor(.ruuForeground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.ruuBackground)
                } else {
                    NavigationStack {
                        WelcomeView()
                    }
                }
            }
            .environmentObject(authVM)
        }
    }
}
