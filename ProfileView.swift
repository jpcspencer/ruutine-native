import Auth
import Charts
import PhotosUI
import Supabase
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var showDeleteConfirm = false
    @State private var showDeleteError = false
    @State private var isDeletingAccount = false
    @State private var isSigningOut = false
    @State private var showEditProfile = false
    @State private var showWeightLogSheet = false

    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(RuutineColor.accent)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(RuutineColor.muted)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        reload()
                    }
                    .foregroundColor(RuutineColor.accent)
                }
                .padding(24)
            } else if let profile = viewModel.profile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        profileCard(profile)
                        weightHistorySection
                        themeSection
                        dangerZone
                        signOutButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }

            if isDeletingAccount {
                deletingAccountOverlay
            }

            if showDeleteConfirm {
                deleteAccountDialog
            }
        }
        .task(id: authVM.session?.user.id) {
            reload()
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                await loadAvatar(from: item)
            }
        }
        .alert("Couldn't Delete Account", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't delete your account. Please try again.")
        }
        .sheet(isPresented: $showEditProfile) {
            if let profile = viewModel.profile, let userId = authVM.session?.user.id {
                ProfileEditView(profile: profile) { draft in
                    try await viewModel.saveProfile(draft, userId: userId)
                }
                .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showWeightLogSheet) {
            if let userId = authVM.session?.user.id {
                WeightLogSheet(isImperial: viewModel.isImperial) { weightKg in
                    try await viewModel.logWeight(weightKg: weightKg, userId: userId)
                }
                .environmentObject(themeManager)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROFILE")
                .font(.bebas(40))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)

            Text("Your training profile and preferences")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)
        }
    }

    private func profileCard(_ profile: ProfileDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(RuutineColor.border)
                            .frame(width: 56, height: 56)

                        if let avatarImage {
                            avatarImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundColor(RuutineColor.muted)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    if let displayName = UserDisplayName.displayName(profile.name) {
                        Text(displayName.uppercased())
                            .font(.bebas(24))
                            .foregroundColor(RuutineColor.foreground)
                            .tracking(1)
                    }

                    Text("Your training profile")
                        .font(.system(size: 13))
                        .foregroundColor(RuutineColor.muted)
                }

                Spacer()

                Button("Edit") {
                    showEditProfile = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(RuutineColor.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            infoSection(title: "GOAL", value: ProfileLabels.goal(profile.goal))
            infoSection(title: "EXPERIENCE", value: ProfileLabels.experience(profile.experienceLevel))
            infoSection(title: "DAYS PER WEEK", value: "\(profile.daysPerWeek)")
            infoSection(title: "TRAINING DAYS", value: ProfileLabels.trainingDays(profile.trainingDays))
            infoSection(title: "EQUIPMENT", value: ProfileLabels.equipmentList(profile.equipmentAccess))
            infoSection(
                title: "INJURIES / LIMITATIONS",
                value: profile.injuriesLimitations?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (profile.injuriesLimitations ?? "None")
                    : "None"
            )

            infoSection(
                title: "HEIGHT",
                value: ProfileLabels.heightDisplay(heightCm: profile.heightCm, isImperial: viewModel.isImperial)
            )
        }
        .padding(16)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func infoSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1.2)

            Text(value)
                .font(.system(size: 15))
                .foregroundColor(RuutineColor.foreground)
        }
    }

    private func unitPill(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? RuutineColor.accentForeground : RuutineColor.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? RuutineColor.accent : RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? Color.clear : RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var weightHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("BODY WEIGHT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
                    .tracking(1.2)

                Spacer()

                Button {
                    showWeightLogSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(RuutineColor.accentForeground)
                        .frame(width: 32, height: 32)
                        .background(RuutineColor.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log weight")
            }

            HStack(spacing: 8) {
                unitPill(title: "Metric", isActive: !viewModel.isImperial) {
                    Task { await setUnitPreference(imperial: false) }
                }
                unitPill(title: "Imperial", isActive: viewModel.isImperial) {
                    Task { await setUnitPreference(imperial: true) }
                }
            }

            if let currentKg = viewModel.currentWeightKg {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(RuutineColor.muted)
                        .tracking(1)

                    Text(ProfileLabels.weightValue(currentKg, isImperial: viewModel.isImperial))
                        .font(.bebas(28))
                        .foregroundColor(RuutineColor.foreground)
                }
            }

            if viewModel.weightLogs.count >= 2 {
                VStack(spacing: 8) {
                    if !viewModel.chartWeightRange.isEmpty {
                        Text(viewModel.chartWeightRange)
                            .font(.system(size: 11))
                            .foregroundColor(RuutineColor.muted)
                            .frame(maxWidth: .infinity)
                    }

                    Chart(viewModel.weightLogs) { log in
                        LineMark(
                            x: .value("Date", log.loggedAt),
                            y: .value("Weight", viewModel.displayWeight(log.weightKg))
                        )
                        .foregroundStyle(RuutineColor.accent)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", log.loggedAt),
                            y: .value("Weight", viewModel.displayWeight(log.weightKg))
                        )
                        .foregroundStyle(RuutineColor.accent)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 100)

                    HStack {
                        if let first = viewModel.weightLogs.first {
                            Text(ProfileLabels.chartStartDate(first.loggedAt))
                                .font(.system(size: 10))
                                .foregroundColor(RuutineColor.muted)
                        }
                        Spacer()
                        Text("Today")
                            .font(.system(size: 10))
                            .foregroundColor(RuutineColor.muted)
                    }
                }
                .padding(12)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Tap + to log your first weigh-in and track progress over time.")
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RuutineColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(RuutineColor.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(spacing: 10) {
                ForEach(viewModel.recentWeightLogs) { log in
                    HStack {
                        Text(ProfileLabels.logDate(log.loggedAt))
                            .font(.system(size: 13))
                            .foregroundColor(RuutineColor.muted)

                        Spacer()

                        Text(ProfileLabels.weightValue(log.weightKg, isImperial: viewModel.isImperial))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(RuutineColor.foreground)
                    }
                }
            }
        }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THEME")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1.2)

            HStack(spacing: 8) {
                ForEach(AppTheme.allCases) { theme in
                    let isActive = themeManager.current == theme
                    Button {
                        themeManager.setTheme(theme)
                        guard let userId = authVM.session?.user.id else { return }
                        Task {
                            try? await viewModel.saveTheme(theme, userId: userId)
                        }
                    } label: {
                        Text(theme.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isActive ? RuutineColor.accent : RuutineColor.foreground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RuutineColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isActive ? RuutineColor.accent : RuutineColor.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
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

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DANGER ZONE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1.2)

            Button {
                showDeleteConfirm = true
            } label: {
                Text("Delete Account")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(RuutineColor.destructive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(RuutineColor.destructive, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var signOutButton: some View {
        Button {
            guard !isSigningOut else { return }
            isSigningOut = true
            Task {
                try? await authVM.signOut()
                isSigningOut = false
            }
        } label: {
            Text(isSigningOut ? "Signing out..." : "Sign out")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(RuutineColor.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isSigningOut)
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
            try await viewModel.deleteAccount(accessToken: accessToken)
            UserDefaults.standard.removeObject(forKey: "activeWorkoutState")
            try await authVM.signOut()
        } catch {
            showDeleteError = true
        }
    }

    private func setUnitPreference(imperial: Bool) async {
        guard let userId = authVM.session?.user.id else { return }
        viewModel.isImperial = imperial
        let preference = imperial ? "imperial" : "metric"
        try? await SupabaseClient.shared
            .from("user_profiles")
            .update(["unit_preference": preference])
            .eq("id", value: userId)
            .execute()
    }

    private func reload() {
        guard let userId = authVM.session?.user.id else { return }
        Task {
            await viewModel.load(userId: userId)
        }
    }

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data)
        else { return }

        avatarImage = Image(uiImage: uiImage)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager.shared)
}
