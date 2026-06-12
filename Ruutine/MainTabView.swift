import Auth
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var atlasService = AtlasService()
    @State private var selectedTab: Tab = .home
    @State private var homePath = NavigationPath()
    @State private var showNewWorkout = false
    @State private var showActiveWorkout = false
    @State private var showAtlasChat = false
    @State private var pendingExercises: [WorkoutExercise]?
    @State private var pendingWorkoutName: String?

    private enum Tab {
        case home
        case program
        case glossary
        case profile
    }

    private var showsAtlasFloatingButton: Bool {
        selectedTab == .home || selectedTab == .program || selectedTab == .glossary
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack(path: $homePath) {
                        HomeView(showAtlasChat: $showAtlasChat)
                    }
                case .program:
                    ProgramView(showAtlasChat: $showAtlasChat) { workoutName, exercises in
                        pendingExercises = exercises
                        pendingWorkoutName = workoutName
                        showActiveWorkout = true
                    }
                case .glossary:
                    GlossaryView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, AtlasFloatingButtonLayout.tabBarHeight)

            if showsAtlasFloatingButton {
                AtlasFloatingButton {
                    showAtlasChat = true
                }
                .padding(.trailing, AtlasFloatingButtonLayout.trailingInset)
                .padding(.bottom, AtlasFloatingButtonLayout.bottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            tabBar
        }
        .background(RuutineColor.background)
        .onChange(of: authVM.session?.user.id) { _, userId in
            if let userId {
                atlasService.setProfileId(userId)
                Task { await atlasService.loadHistory() }
            }
        }
        .onAppear {
            if let userId = authVM.session?.user.id {
                atlasService.setProfileId(userId)
                Task { await atlasService.loadHistory() }
            }
        }
        .sheet(isPresented: $showAtlasChat) {
            AtlasChatView(atlasService: atlasService)
                .environmentObject(authVM)
        }
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
            pendingWorkoutName = nil
        }) {
            ActiveWorkoutView(
                initialExercises: pendingExercises,
                workoutName: pendingWorkoutName
            ) {
                showActiveWorkout = false
                pendingExercises = nil
                pendingWorkoutName = nil
                selectedTab = .home
                homePath = NavigationPath()
                NotificationCenter.default.post(name: .workoutCompleted, object: nil)
            }
        }
    }

    private func placeholderScreen(_ title: String) -> some View {
        Text(title)
            .foregroundColor(RuutineColor.foreground)
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
                .shadow(color: RuutineColor.foreground.opacity(0.25), radius: 6, y: 2)
        }
        .offset(y: -6)
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager.shared)
}
