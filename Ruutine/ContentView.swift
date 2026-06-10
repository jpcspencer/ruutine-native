//
//  ContentView.swift
//  Ruutine
//
//  Created by Jordan Spencer on 6/6/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("RUUTINE")
                .font(.system(size: 48, weight: .black))
                .foregroundColor(.white)
                .tracking(4)
        }
    }
}

#Preview {
    ContentView()
}
