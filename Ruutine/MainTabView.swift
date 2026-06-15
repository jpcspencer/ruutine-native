import Auth
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var atlasService = AtlasService()
    @StateObject private var workout = ActiveWorkoutCoordinator()
    @State private var selectedTab: Tab = .home
    @State private var homePath = NavigationPath()
    @State private var showNewWorkout = false
    @State private var showAtlasChat = false
    @State private var pendingExercises: [WorkoutExercise]?

    private enum Tab {
        case home
        case program
        case glossary
        case profile
    }

    private var showsAtlasFloatingButton: Bool {
        selectedTab == .home || selectedTab == .program || selectedTab == .glossary
    }

    private var showsMinimizedWorkoutBar: Bool {
        workout.viewModel != nil && !workout.isExpanded
    }

    private var minimizedBarHeight: CGFloat {
        showsMinimizedWorkoutBar ? MinimizedWorkoutBarLayout.height : 0
    }

    private var tabContentBottomPadding: CGFloat {
        AtlasFloatingButtonLayout.tabBarHeight + minimizedBarHeight
    }

    private var atlasBottomPadding: CGFloat {
        AtlasFloatingButtonLayout.bottomInset + minimizedBarHeight
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
                    ProgramView { workoutName, exercises in
                        workout.start(initialExercises: exercises, workoutName: workoutName)
                    }
                case .glossary:
                    GlossaryView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, tabContentBottomPadding)

            if showsMinimizedWorkoutBar, let viewModel = workout.viewModel {
                MinimizedWorkoutBar(viewModel: viewModel) {
                    Haptics.impact(.light)
                    workout.expand()
                }
                .padding(.bottom, AtlasFloatingButtonLayout.tabBarHeight)
            }

            if showsAtlasFloatingButton {
                AtlasFloatingButton {
                    showAtlasChat = true
                }
                .padding(.trailing, AtlasFloatingButtonLayout.trailingInset)
                .padding(.bottom, atlasBottomPadding)
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
                workout.start(initialExercises: pendingExercises, workoutName: nil)
                pendingExercises = nil
            }
        }
        .onChange(of: workout.isExpanded) { _, isShowing in
            if isShowing { Haptics.impact(.medium) }
        }
        .fullScreenCover(isPresented: $workout.isExpanded) {
            if let viewModel = workout.viewModel {
                ActiveWorkoutView(
                    viewModel: viewModel,
                    onMinimize: { workout.minimize() },
                    onEnd: {
                        workout.end()
                        selectedTab = .home
                        homePath = NavigationPath()
                        NotificationCenter.default.post(name: .workoutCompleted, object: nil)
                    }
                )
                .environmentObject(authVM)
                .environmentObject(themeManager)
            }
        }
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
            if selectedTab != tab {
                Haptics.selection()
            }
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
            Haptics.impact(.medium)
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
