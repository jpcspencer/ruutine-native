import Foundation
import Supabase

enum CoachMessageService {
    private struct InsertRow: Encodable {
        let userProfileId: UUID
        let role: String
        let content: String

        enum CodingKeys: String, CodingKey {
            case role, content
            case userProfileId = "user_profile_id"
        }
    }

    private struct IdRow: Decodable {
        let id: UUID
    }

    /// Saves onboarding chat to `coach_messages` once, then appends the coach greeting as the newest row.
    static func persistOnboardingConversation(
        profileId: UUID,
        messages: [AtlasMessage]
    ) async {
        let filtered = messages.filter { message in
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            if message.role == .assistant, OnboardingService.isGeneratingHandoffMessage(trimmed) {
                return false
            }
            return true
        }

        guard !filtered.isEmpty else { return }

        do {
            let existing: [IdRow] = try await SupabaseClient.shared
                .from("coach_messages")
                .select("id")
                .eq("user_profile_id", value: profileId)
                .limit(1)
                .execute()
                .value

            guard existing.isEmpty else { return }

            var rows = filtered.map {
                InsertRow(userProfileId: profileId, role: $0.role.rawValue, content: $0.content)
            }
            rows.append(
                InsertRow(
                    userProfileId: profileId,
                    role: AtlasMessage.Role.assistant.rawValue,
                    content: AtlasService.defaultGreeting
                )
            )

            try await SupabaseClient.shared
                .from("coach_messages")
                .insert(rows)
                .execute()

            print("[CoachMessageService] persisted \(rows.count) coach_messages (onboarding + greeting)")
        } catch {
            print("[CoachMessageService] persist onboarding error: \(error)")
        }
    }
}
