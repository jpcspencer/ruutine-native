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
}
