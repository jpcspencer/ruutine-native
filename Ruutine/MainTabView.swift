import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var showNewWorkout = false
    @State private var showActiveWorkout = false
    @State private var pendingExercises: [WorkoutExercise]?

    private enum Tab {
        case home
        case program
        case glossary
        case profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .program:
                    placeholderScreen("Program")
                case .glossary:
                    placeholderScreen("Glossary")
                case .profile:
                    placeholderScreen("Profile")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 72)

            tabBar
        }
        .background(Color.ruuBackground)
        .sheet(isPresented: $showNewWorkout) {
            NewWorkoutView { exercises in
                pendingExercises = exercises
                showNewWorkout = false
            }
        }
        .onChange(of: showNewWorkout) { _, isPresented in
            if !isPresented, pendingExercises != nil {
                showActiveWorkout = true
            }
        }
        .fullScreenCover(isPresented: $showActiveWorkout, onDismiss: {
            pendingExercises = nil
        }) {
            ActiveWorkoutView(initialExercises: pendingExercises)
        }
    }

    private func placeholderScreen(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ruuBackground)
    }

    private var tabBar: some View {
        HStack {
            tabItem(tab: .home, icon: "house.fill", label: "Home")
            tabItem(tab: .program, icon: "list.bullet", label: "Program")

            centerButton

            tabItem(tab: .glossary, icon: "book.fill", label: "Glossary")
            tabItem(tab: .profile, icon: "person.fill", label: "Profile")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Color.ruuBackground
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.ruuBorder)
                        .frame(height: 1)
                }
        )
        .safeAreaPadding(.bottom, 4)
    }

    private func tabItem(tab: Tab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedTab == tab ? .ruuAccent : .ruuMuted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button {
            pendingExercises = nil
            showNewWorkout = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.ruuAccentForeground)
                .frame(width: 56, height: 56)
                .background(Color.ruuAccent)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
        .offset(y: -20)
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
