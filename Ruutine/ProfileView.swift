import Auth
import Charts
import PhotosUI
import Supabase
import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var isUploadingAvatar = false
    @State private var avatarErrorMessage: String?
    @State private var showEditProfile = false
    @State private var showWeightLogSheet = false
    @State private var showSettings = false
    @State private var defaultRestSeconds = RestDurationPreferences.defaultSeconds

    var body: some View {
        Group {
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
            } else if viewModel.profile != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        if let profile = viewModel.profile {
                            profileCard(profile)
                        }
                        weightHistorySection
                        themeSection
                        restDurationSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RuutineColor.background.ignoresSafeArea())
        .task(id: authVM.session?.user.id) {
            defaultRestSeconds = RestDurationPreferences.defaultSeconds
            reload()
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                await loadAvatar(from: item)
            }
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(themeManager)
                .environmentObject(authVM)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text("PROFILE")
                    .font(.bebas(40))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(1)

                Spacer()

                RuutineNavButton(kind: .gear) {
                    showSettings = true
                }
                .accessibilityLabel("Settings")
            }

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

                        avatarContent(for: profile)

                        if isUploadingAvatar {
                            Circle()
                                .fill(RuutineColor.background.opacity(0.62))
                                .frame(width: 56, height: 56)
                            ProgressView()
                                .tint(RuutineColor.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isUploadingAvatar)

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
                    Haptics.impact(.light)
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

            if let avatarErrorMessage {
                Text(avatarErrorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.destructive.opacity(0.85))
                    .multilineTextAlignment(.leading)
            }

            infoSection(title: "GOAL", value: ProfileLabels.goal(profile.goal))
            infoSection(title: "EXPERIENCE", value: ProfileLabels.experience(profile.experienceLevel))
            infoSection(title: "GENDER", value: ProfileLabels.gender(profile.biologicalSex))
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

    @ViewBuilder
    private func avatarContent(for profile: ProfileDetail) -> some View {
        if let avatarUrl = profile.avatarUrl,
           let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    avatarImageView(image)
                case .failure:
                    avatarFallbackImage
                case .empty:
                    if let avatarImage {
                        avatarImageView(avatarImage)
                    } else {
                        ProgressView()
                            .tint(RuutineColor.accent)
                    }
                @unknown default:
                    avatarFallbackImage
                }
            }
        } else if let avatarImage {
            avatarImageView(avatarImage)
        } else {
            avatarFallbackImage
        }
    }

    private func avatarImageView(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(Circle())
    }

    private var avatarFallbackImage: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 24))
            .foregroundColor(RuutineColor.muted)
    }

    private func unitPill(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
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
                    Haptics.impact(.light)
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
                        Haptics.selection()
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

    private var restDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEFAULT REST")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1.2)

            HStack(spacing: 8) {
                ForEach(RestDurationPreferences.presets, id: \.self) { seconds in
                    let isActive = defaultRestSeconds == seconds
                    Button {
                        Haptics.selection()
                        RestDurationPreferences.defaultSeconds = seconds
                        defaultRestSeconds = seconds
                    } label: {
                        Text(RestDurationPreferences.formatted(seconds))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isActive ? RuutineColor.accentForeground : RuutineColor.foreground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isActive ? RuutineColor.accent : RuutineColor.surface)
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
        guard let item else { return }
        guard let userId = authVM.session?.user.id else {
            avatarErrorMessage = "Sign in again to update your profile picture."
            return
        }

        isUploadingAvatar = true
        avatarErrorMessage = nil
        defer {
            isUploadingAvatar = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data)
            else {
                throw AvatarUploadError.invalidImage
            }

            let jpegData = try resizedAvatarJPEGData(from: uiImage)
            _ = try await viewModel.uploadAvatar(jpegData: jpegData)
            avatarImage = Image(uiImage: UIImage(data: jpegData) ?? uiImage)
        } catch {
            avatarErrorMessage = avatarErrorMessage(for: error)
            Haptics.notify(.error)
        }
    }

    private func resizedAvatarJPEGData(from image: UIImage) throws -> Data {
        let maxDimension: CGFloat = 512
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
        let targetSize = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw AvatarUploadError.compressionFailed
        }
        return data
    }

    private func avatarErrorMessage(for error: Error) -> String {
        if let error = error as? AvatarUploadError {
            return error.localizedDescription
        }
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "Couldn't save profile picture. Try again." : message
    }

    private enum AvatarUploadError: LocalizedError {
        case invalidImage
        case compressionFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Couldn't read that image. Try another photo."
            case .compressionFailed:
                return "Couldn't prepare that image. Try another photo."
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager.shared)
}
