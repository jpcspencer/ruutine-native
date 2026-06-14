//
//  ContentView.swift
//  Ruutine
//
//  Created by Jordan Spencer on 6/6/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            WelcomeView()
        }
    }
}

#Preview {
    ContentView()
}
