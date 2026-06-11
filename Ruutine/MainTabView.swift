import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var homePath = NavigationPath()
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
                    NavigationStack(path: $homePath) {
                        HomeView()
                    }
                case .program:
                    placeholderScreen("Program")
                case .glossary:
                    GlossaryView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 72)

            tabBar
        }
        .background(RuutineColor.background)
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
            ActiveWorkoutView(initialExercises: pendingExercises) {
                showActiveWorkout = false
                pendingExercises = nil
                selectedTab = .home
                homePath = NavigationPath()
                NotificationCenter.default.post(name: .workoutCompleted, object: nil)
            }
        }
    }

    private func placeholderScreen(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RuutineColor.background)
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
            RuutineColor.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RuutineColor.border)
                        .frame(height: 1)
                }
        )
        .safeAreaPadding(.bottom, 4)
    }

    private func tabItem(tab: Tab, icon: String, label: String) -> some View {
        Button {
            if tab == .home {
                homePath = NavigationPath()
            }
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedTab == tab ? RuutineColor.accent : RuutineColor.muted)
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
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(RuutineColor.accentForeground)
                .frame(width: 52, height: 52)
                .background(RuutineColor.accent)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
        .offset(y: -6)
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
