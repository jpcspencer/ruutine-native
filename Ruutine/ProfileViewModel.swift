import Combine
import Foundation
import Supabase

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: ProfileDetail?
    @Published var weightLogs: [WeightLog] = []
    @Published var isImperial = false
    @Published var selectedTheme = "onyx"
    @Published var isLoading = true
    @Published var errorMessage: String?

    var chartWeightRange: String {
        guard weightLogs.count >= 2 else { return "" }
        let values = weightLogs.map { displayWeight($0.weightKg) }
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        let unit = isImperial ? "lb" : "kg"
        return String(format: "%.1f – %.1f %@", min, max, unit)
    }

    var recentWeightLogs: [WeightLog] {
        Array(weightLogs.sorted { $0.loggedAt > $1.loggedAt }.prefix(5))
    }

    func load(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let profile: ProfileDetail = try await SupabaseClient.shared
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            let logs: [WeightLog] = try await SupabaseClient.shared
                .from("weight_logs")
                .select("id, weight_kg, logged_at")
                .eq("user_profile_id", value: userId)
                .order("logged_at", ascending: true)
                .execute()
                .value

            self.profile = profile
            self.weightLogs = logs
            self.isImperial = profile.unitPreference == "imperial"
            self.selectedTheme = profile.theme ?? "onyx"
            ThemeManager.shared.applyFromProfile(profile.theme)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func displayWeight(_ kg: Double) -> Double {
        WeightUnits.kgToDisplay(kg, isImperial: isImperial)
    }

    func saveTheme(_ theme: AppTheme, userId: UUID) async throws {
        try await SupabaseClient.shared
            .from("user_profiles")
            .update(["theme": theme.rawValue])
            .eq("id", value: userId)
            .execute()
        selectedTheme = theme.rawValue
    }

    func deleteAccount(accessToken: String) async throws {
        try await AccountService.deleteAccount(accessToken: accessToken)
    }
}
