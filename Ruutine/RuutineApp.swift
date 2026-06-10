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
                        RuutineColor.background.ignoresSafeArea()
                        Text("RUUTINE")
                            .font(.bebas(56))
                            .foregroundColor(RuutineColor.foreground)
                            .tracking(4)
                    }
                } else if authVM.session != nil {
                    MainTabView()
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
