import Auth
import Supabase
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject private var preferences = AppPreferences.shared
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var showDeleteConfirm = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteError = false
    @State private var isDeletingAccount = false
    @State private var isSigningOut = false
    @State private var isSavingUnits = false
    @State private var unitsErrorMessage: String?

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        toggleRow(title: "Sounds", isOn: $preferences.soundsEnabled)
                        toggleRow(title: "Haptic Feedback", isOn: $preferences.hapticsEnabled)
                        VStack(alignment: .leading, spacing: 8) {
                            toggleRow(title: "Notifications", isOn: $preferences.notificationsEnabled)
                            Text("Rest timer reminders.")
                                .font(.system(size: 12))
                                .foregroundColor(RuutineColor.muted)
                                .padding(.leading, 2)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            toggleRow(title: "Keep Screen Awake", isOn: $preferences.keepScreenAwake)
                            Text("Prevents the screen from sleeping during a workout.")
                                .font(.system(size: 12))
                                .foregroundColor(RuutineColor.muted)
                                .padding(.leading, 2)
                        }

                        unitsSection

                        VStack(spacing: 10) {
                            actionRow(title: "Rate Ruutine", urlString: "https://apps.apple.com/app/id6767207604?action=write-review")
                            actionRow(title: "Help & Support", urlString: "mailto:support@ruutine.app")
                            actionRow(title: "Privacy Policy", urlString: "https://www.ruutine.app/privacy")
                        }

                        accountSection

                        Text(versionText)
                            .font(.system(size: 12))
                            .foregroundColor(RuutineColor.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                    .padding(20)
                }
                .background(RuutineColor.background)
                .navigationBarTitleDisplayMode(.inline)
                .ruutineNavigationChrome()
                .toolbar {
                    RuutineToolbarItem(placement: .principal) {
                        Text("SETTINGS")
                            .font(.bebas(22))
                            .foregroundColor(RuutineColor.foreground)
                            .tracking(1)
                    }
                    RuutineToolbarItem(placement: .topBarTrailing) {
                        RuutineNavButton(kind: .done) { dismiss() }
                    }
                }
            }

            if isDeletingAccount {
                deletingAccountOverlay
            }

            if showDeleteConfirm {
                deleteAccountDialog
            }
        }
        .tint(RuutineColor.accent)
        .presentationDragIndicator(.visible)
        .alert("Couldn't Delete Account", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't delete your account. Please try again.")
        }
        .ruutineConfirm(
            isPresented: $showSignOutConfirm,
            title: "Sign Out?",
            message: "You'll need to log back in to use Ruutine.",
            confirmLabel: "Sign Out",
            isDestructive: false
        ) {
            guard !isSigningOut else { return }
            isSigningOut = true
            Task {
                try? await authVM.signOut()
                isSigningOut = false
            }
        }
        .task(id: authVM.session?.user.id) {
            guard let userId = authVM.session?.user.id else { return }
            await profileViewModel.load(userId: userId)
        }
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Units")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(RuutineColor.foreground)
                        Text("Weight and distance")
                            .font(.system(size: 12))
                            .foregroundColor(RuutineColor.muted)
                    }

                    Spacer()

                    if isSavingUnits {
                        ProgressView()
                            .tint(RuutineColor.accent)
                    }
                }

                HStack(spacing: 8) {
                    unitButton(title: "Metric", subtitle: "kg · km", isActive: !profileViewModel.isImperial) {
                        Task { await setUnitPreference(imperial: false) }
                    }
                    unitButton(title: "Imperial", subtitle: "lb · mi", isActive: profileViewModel.isImperial) {
                        Task { await setUnitPreference(imperial: true) }
                    }
                }
            }
            .padding(14)
            .background(RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let unitsErrorMessage {
                Text(unitsErrorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(RuutineColor.destructive)
                    .padding(.leading, 2)
            }
        }
    }

    private func unitButton(
        title: String,
        subtitle: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.85)
            }
            .foregroundColor(isActive ? RuutineColor.accentForeground : RuutineColor.foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? RuutineColor.accent : RuutineColor.background)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? RuutineColor.accent : RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isSavingUnits)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1.2)

            VStack(spacing: 10) {
                Button {
                    Haptics.impact(.light)
                    guard !isSigningOut else { return }
                    showSignOutConfirm = true
                } label: {
                    Text(isSigningOut ? "Signing out..." : "Sign Out")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RuutineColor.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RuutineColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(RuutineColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isSigningOut)

                Button {
                    Haptics.impact(.light)
                    showDeleteConfirm = true
                } label: {
                    Text("Delete Account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RuutineColor.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RuutineColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(RuutineColor.destructive, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
            }
        }
    }

    private var deletingAccountOverlay: some View {
        ZStack {
            RuutineColor.scrim
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(RuutineColor.accent)

                Text("Deleting your account…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(RuutineColor.foreground)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)
        }
    }

    private var deleteAccountDialog: some View {
        ZStack {
            RuutineColor.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    showDeleteConfirm = false
                }

            VStack(spacing: 20) {
                Text("DELETE ACCOUNT")
                    .font(.bebas(24))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(1)

                Text("This permanently deletes your account and all your data. This can't be undone.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(RuutineColor.foreground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        showDeleteConfirm = false
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(RuutineColor.foreground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RuutineColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(RuutineColor.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDeleteConfirm = false
                        Task { await deleteAccount() }
                    } label: {
                        Text("Delete")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(RuutineColor.destructive)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RuutineColor.destructive.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(RuutineColor.destructive.opacity(0.85), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: showDeleteConfirm)
    }

    private func deleteAccount() async {
        let accessToken: String
        do {
            accessToken = try await SupabaseClient.shared.auth.session.accessToken
        } catch {
            showDeleteError = true
            return
        }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await profileViewModel.deleteAccount(accessToken: accessToken)
            UserDefaults.standard.removeObject(forKey: "activeWorkoutState")
            try await authVM.signOut()
        } catch {
            showDeleteError = true
        }
    }

    private func setUnitPreference(imperial: Bool) async {
        guard let userId = authVM.session?.user.id else { return }
        guard profileViewModel.isImperial != imperial else { return }

        let previousValue = profileViewModel.isImperial
        let preference = imperial ? "imperial" : "metric"
        profileViewModel.isImperial = imperial
        unitsErrorMessage = nil
        isSavingUnits = true
        defer { isSavingUnits = false }

        do {
            try await SupabaseClient.shared
                .from("user_profiles")
                .update(["unit_preference": preference])
                .eq("id", value: userId)
                .execute()

            NotificationCenter.default.post(
                name: .unitPreferenceChanged,
                object: nil,
                userInfo: ["isImperial": imperial]
            )
        } catch {
            profileViewModel.isImperial = previousValue
            unitsErrorMessage = "Couldn't update units. Please try again."
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(RuutineColor.foreground)
        }
        .padding(14)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func actionRow(title: String, urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(RuutineColor.foreground)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(RuutineColor.muted)
                    }
                    .padding(14)
                    .background(RuutineColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(RuutineColor.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Ruutine \(shortVersion) (\(build))"
    }
}
