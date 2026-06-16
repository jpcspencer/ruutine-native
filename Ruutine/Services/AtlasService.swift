import Combine
import Foundation
import Supabase

struct AtlasMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    let content: String

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

@MainActor
final class AtlasService: ObservableObject {
    @Published private(set) var messages: [AtlasMessage] = []
    @Published var isTyping = false
    @Published private(set) var isLoadingHistory = false

    private var profileId: UUID?
    private var didSeedGreeting = false
    private var loadedProfileId: UUID?
    private var activeGreeting: String?

    private let endpoint = URL(string: "https://www.ruutine.app/api/coach/chat")!
    private static let systemPrompt =
        "You are Ruu, a personal training coach inside Ruutine. Introduce and refer to yourself as Ruu."

    static func coachGreeting(profileName: String?) -> String {
        if let name = UserDisplayName.storedName(from: profileName) {
            let first = UserDisplayName.firstName(from: name)
            return "Hey \(first), how can I help with your training today?"
        }
        return "Hey, how can I help with your training today?"
    }

    static func isCoachGreeting(_ content: String) -> Bool {
        let lower = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.hasPrefix("hey") && lower.contains("how can i help with your training today")
    }

    static func fetchProfileName(profileId: UUID) async -> String? {
        struct NameRow: Decodable { let name: String? }

        guard let row: NameRow = try? await SupabaseClient.shared
            .from("user_profiles")
            .select("name")
            .eq("id", value: profileId)
            .single()
            .execute()
            .value
        else { return nil }

        return UserDisplayName.storedName(from: row.name)
    }

    /// Messages before the coach greeting / active thread — used for scroll-up hint.
    var priorHistoryMessageCount: Int {
        guard !messages.isEmpty else { return 0 }

        if messages.count == 1,
           messages[0].role == .assistant,
           Self.isCoachGreeting(messages[0].content) {
            return 0
        }

        if let last = messages.last,
           last.role == .assistant,
           Self.isCoachGreeting(last.content) {
            return max(0, messages.count - 1)
        }

        return max(0, messages.count - 1)
    }

    var shouldShowScrollUpHint: Bool {
        priorHistoryMessageCount > 0
    }

    func setProfileId(_ profileId: UUID) {
        if self.profileId != profileId {
            self.profileId = profileId
            loadedProfileId = nil
            didSeedGreeting = false
            activeGreeting = nil
            messages = []
        }
    }

    func configure(profileId: UUID) {
        setProfileId(profileId)
    }

    func loadHistory() async {
        guard let profileId else { return }
        if loadedProfileId == profileId, !messages.isEmpty || didSeedGreeting { return }

        isLoadingHistory = true
        defer { isLoadingHistory = false }

        await refreshGreetingText(profileId: profileId)

        struct CoachMessageRow: Decodable {
            let id: UUID
            let role: String
            let content: String
        }

        do {
            let rows: [CoachMessageRow] = try await SupabaseClient.shared
                .from("coach_messages")
                .select("id, role, content")
                .eq("user_profile_id", value: profileId)
                .order("created_at", ascending: true)
                .execute()
                .value

            print("[AtlasService] loaded \(rows.count) coach_messages for profile \(profileId)")

            if rows.contains(where: { $0.role == AtlasMessage.Role.user.rawValue }) {
                AppPreferences.shared.hasSentCoachMessage = true
            }

            if rows.isEmpty {
                messages = []
                didSeedGreeting = false
                seedGreetingIfNeeded()
            } else {
                messages = ensureGreetingAtTop(rows.compactMap { row in
                    guard let role = AtlasMessage.Role(rawValue: row.role) else { return nil }
                    return AtlasMessage(id: row.id, role: role, content: row.content)
                })
                didSeedGreeting = true
            }

            loadedProfileId = profileId
        } catch {
            print("[AtlasService] load coach_messages error: \(error)")
            seedGreetingIfNeeded()
        }
    }

    /// Keeps the coach greeting as the first message when it isn't already present.
    private func ensureGreetingAtTop(_ list: [AtlasMessage]) -> [AtlasMessage] {
        let greeting = activeGreeting ?? Self.coachGreeting(profileName: nil)

        if list.first?.role == .assistant, Self.isCoachGreeting(list.first?.content ?? "") {
            return list
        }
        if list.contains(where: { $0.role == .assistant && Self.isCoachGreeting($0.content) }) {
            return list
        }
        return [AtlasMessage(role: .assistant, content: greeting)] + list
    }

    private func refreshGreetingText(profileId: UUID) async {
        let name = await Self.fetchProfileName(profileId: profileId)
        activeGreeting = Self.coachGreeting(profileName: name)
    }

    func seedGreetingIfNeeded() {
        guard !didSeedGreeting else { return }
        didSeedGreeting = true
        if activeGreeting == nil {
            activeGreeting = Self.coachGreeting(profileName: nil)
        }
        messages = ensureGreetingAtTop(messages)
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTyping else { return }
        guard let profileId else {
            appendAssistantError("You're not signed in. Please log in and try again.")
            return
        }

        messages.append(AtlasMessage(role: .user, content: trimmed))
        if !AppPreferences.shared.hasSentCoachMessage {
            AppPreferences.shared.hasSentCoachMessage = true
        }
        isTyping = true
        defer { isTyping = false }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "profileId": profileId.uuidString,
            "message": trimmed,
            "systemPrompt": Self.systemPrompt,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            print("[AtlasService] POST \(endpoint.absoluteString)")
            print("[AtlasService] request body: \(bodyString)")

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            print("[AtlasService] HTTP status: \(status)")
            print("[AtlasService] raw response: \(raw)")

            guard let http = response as? HTTPURLResponse else {
                appendAssistantError("Unexpected response from Ruu.")
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String,
               !error.isEmpty {
                appendAssistantError(error)
                return
            }

            guard (200...299).contains(http.statusCode) else {
                appendAssistantError("Ruu request failed (HTTP \(http.statusCode)).")
                return
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reply = json["text"] as? String,
               !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append(AtlasMessage(role: .assistant, content: reply))
                // coach/chat route persists user + assistant rows to coach_messages.
                await reloadHistoryAfterSend(profileId: profileId)
            } else {
                appendAssistantError("Ruu returned an empty response.")
            }
        } catch {
            print("[AtlasService] network error: \(error)")
            appendAssistantError("Couldn't reach Ruu. Check your connection and try again.")
        }
    }

    func clearChat() async throws {
        guard let profileId else { return }

        print("[AtlasService] deleting coach_messages for profile \(profileId)")
        try await SupabaseClient.shared
            .from("coach_messages")
            .delete()
            .eq("user_profile_id", value: profileId)
            .execute()

        messages = []
        didSeedGreeting = false
        loadedProfileId = profileId
        await refreshGreetingText(profileId: profileId)
        seedGreetingIfNeeded()
        print("[AtlasService] coach chat cleared")
    }

    private func reloadHistoryAfterSend(profileId: UUID) async {
        struct CoachMessageRow: Decodable {
            let id: UUID
            let role: String
            let content: String
        }

        do {
            await refreshGreetingText(profileId: profileId)

            let rows: [CoachMessageRow] = try await SupabaseClient.shared
                .from("coach_messages")
                .select("id, role, content")
                .eq("user_profile_id", value: profileId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = ensureGreetingAtTop(rows.compactMap { row in
                guard let role = AtlasMessage.Role(rawValue: row.role) else { return nil }
                return AtlasMessage(id: row.id, role: role, content: row.content)
            })
            didSeedGreeting = true
            loadedProfileId = profileId
        } catch {
            print("[AtlasService] reload after send error: \(error)")
        }
    }

    private func appendAssistantError(_ message: String) {
        messages.append(AtlasMessage(role: .assistant, content: message))
    }
}
