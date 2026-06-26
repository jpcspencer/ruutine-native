import Foundation
import Supabase

struct ProfileEditDraft {
    var name: String
    var goal: String
    var experienceLevel: String
    var daysPerWeek: Int
    var trainingDays: [Int]
    var equipmentAccess: [String]
    var injuriesLimitations: String
    var biologicalSex: String
    var heightCmText: String
    var heightFeetText: String
    var heightInchesText: String
    var unitPreference: String

    init(from profile: ProfileDetail) {
        name = profile.name
        goal = profile.goal
        experienceLevel = profile.experienceLevel
        daysPerWeek = profile.daysPerWeek
        trainingDays = profile.trainingDays
        equipmentAccess = profile.equipmentAccess
        injuriesLimitations = profile.injuriesLimitations ?? ""
        biologicalSex = Self.normalizedBiologicalSex(profile.biologicalSex) ?? "prefer_not_to_say"
        unitPreference = profile.unitPreference ?? "metric"

        if let heightCm = profile.heightCm {
            heightCmText = Self.formatNumber(heightCm)
            let totalInches = heightCm / 2.54
            heightFeetText = String(Int(totalInches / 12))
            heightInchesText = String(Int(totalInches.rounded()) % 12)
        } else {
            heightCmText = ""
            heightFeetText = ""
            heightInchesText = ""
        }
    }

    var isImperial: Bool { unitPreference == "imperial" }

    func resolvedHeightCm() -> Double? {
        if isImperial {
            guard let feet = Int(heightFeetText.trimmingCharacters(in: .whitespaces)),
                  let inches = Int(heightInchesText.trimmingCharacters(in: .whitespaces)),
                  feet >= 0, inches >= 0
            else { return nil }
            let totalInches = Double(feet * 12 + inches)
            guard totalInches > 0 else { return nil }
            return (totalInches * 2.54 * 10).rounded() / 10
        }

        let trimmed = heightCmText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return (value * 10).rounded() / 10
    }

    private static func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private static func normalizedBiologicalSex(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !value.isEmpty else { return nil }
        let underscored = value.replacingOccurrences(of: " ", with: "_")
        switch underscored {
        case "male", "female", "prefer_not_to_say":
            return underscored
        default:
            return nil
        }
    }
}

private struct ProfileUpdatePayload: Encodable {
    let name: String
    let goal: String
    let experienceLevel: String
    let daysPerWeek: Int
    let trainingDays: [Int]
    let equipmentAccess: [String]
    let injuriesLimitations: String?
    let heightCm: Double?
    let unitPreference: String
    let biologicalSex: String

    enum CodingKeys: String, CodingKey {
        case name, goal
        case experienceLevel = "experience_level"
        case daysPerWeek = "days_per_week"
        case trainingDays = "training_days"
        case equipmentAccess = "equipment_access"
        case injuriesLimitations = "injuries_limitations"
        case heightCm = "height_cm"
        case unitPreference = "unit_preference"
        case biologicalSex = "biological_sex"
    }
}

private struct WeightLogInsert: Encodable {
    let userProfileId: UUID
    let weightKg: Double

    enum CodingKeys: String, CodingKey {
        case userProfileId = "user_profile_id"
        case weightKg = "weight_kg"
    }
}

extension ProfileViewModel {
    func uploadAvatar(jpegData: Data) async throws -> URL {
        let session: Session
        do {
            session = try await SupabaseClient.shared.auth.session
        } catch {
            throw AvatarUploadAuthError.notSignedIn
        }

        let userId = session.user.id
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        let bucket = SupabaseClient.shared.storage.from("avatars")

        try await bucket.upload(
            path,
            data: jpegData,
            options: FileOptions(
                contentType: "image/jpeg",
                upsert: true
            )
        )

        let publicURL = try bucket.getPublicURL(
            path: path,
            cacheNonce: UUID().uuidString
        )

        try await saveAvatarURL(publicURL, userId: userId)
        return publicURL
    }

    private func saveAvatarURL(_ avatarURL: URL, userId: UUID) async throws {
        let avatarURLString = avatarURL.absoluteString
        try await SupabaseClient.shared
            .from("user_profiles")
            .update(["avatar_url": avatarURLString])
            .eq("id", value: userId)
            .execute()

        profile = profile?.updatingAvatarUrl(avatarURLString)
    }

    private enum AvatarUploadAuthError: LocalizedError {
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Not signed in — please sign in again."
            }
        }
    }

    var currentWeightKg: Double? {
        if let latest = weightLogs.max(by: { $0.loggedAt < $1.loggedAt }) {
            return latest.weightKg
        }
        return profile?.weightKg
    }

    func saveProfile(_ draft: ProfileEditDraft, userId: UUID) async throws {
        let injuries = draft.injuriesLimitations.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ProfileUpdatePayload(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: draft.goal,
            experienceLevel: draft.experienceLevel,
            daysPerWeek: draft.daysPerWeek,
            trainingDays: draft.trainingDays.sorted(),
            equipmentAccess: draft.equipmentAccess,
            injuriesLimitations: injuries.isEmpty ? nil : injuries,
            heightCm: draft.resolvedHeightCm(),
            unitPreference: draft.unitPreference,
            biologicalSex: draft.biologicalSex
        )

        try await SupabaseClient.shared
            .from("user_profiles")
            .update(payload)
            .eq("id", value: userId)
            .execute()

        isImperial = draft.unitPreference == "imperial"
        await load(userId: userId)
    }

    func logWeight(weightKg: Double, userId: UUID) async throws {
        let roundedKg = (weightKg * 10).rounded() / 10
        try await SupabaseClient.shared
            .from("weight_logs")
            .insert(WeightLogInsert(userProfileId: userId, weightKg: roundedKg))
            .execute()

        try await SupabaseClient.shared
            .from("user_profiles")
            .update(["weight_kg": roundedKg])
            .eq("id", value: userId)
            .execute()

        await load(userId: userId)
    }
}
