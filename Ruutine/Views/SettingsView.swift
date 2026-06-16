import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var preferences = AppPreferences.shared

    var body: some View {
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

                    VStack(spacing: 10) {
                        actionRow(title: "Rate Ruutine", urlString: "https://apps.apple.com/app/id6767207604?action=write-review")
                        actionRow(title: "Help & Support", urlString: "mailto:support@ruutine.app")
                        actionRow(title: "Privacy Policy", urlString: "https://www.ruutine.app/privacy")
                    }

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
                RuutineToolbarItem(placement: .topBarLeading) {
                    RuutineNavButton(kind: .cancel) { dismiss() }
                }
            }
        }
        .tint(RuutineColor.accent)
        .presentationDragIndicator(.visible)
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
