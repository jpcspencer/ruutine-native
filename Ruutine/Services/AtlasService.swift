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

    private let endpoint = URL(string: "https://www.ruutine.app/api/coach/chat")!

    static let defaultGreeting = "Hey, I'm Ruu. How can I help with your training today?"

    /// Messages before the coach greeting / active thread — used for scroll-up hint.
    var priorHistoryMessageCount: Int {
        guard !messages.isEmpty else { return 0 }

        if messages.count == 1,
           messages[0].role == .assistant,
           messages[0].content == Self.defaultGreeting {
            return 0
        }

        if let last = messages.last,
           last.role == .assistant,
           last.content == Self.defaultGreeting {
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

            if rows.isEmpty {
                messages = []
                didSeedGreeting = false
                seedGreetingIfNeeded()
            } else {
                messages = rows.compactMap { row in
                    guard let role = AtlasMessage.Role(rawValue: row.role) else { return nil }
                    return AtlasMessage(id: row.id, role: role, content: row.content)
                }
                didSeedGreeting = true
            }

            loadedProfileId = profileId
        } catch {
            print("[AtlasService] load coach_messages error: \(error)")
            seedGreetingIfNeeded()
        }
    }

    func seedGreetingIfNeeded() {
        guard !didSeedGreeting else { return }
        didSeedGreeting = true
        if messages.isEmpty {
            messages = [
                AtlasMessage(role: .assistant, content: Self.defaultGreeting),
            ]
        }
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTyping else { return }
        guard let profileId else {
            appendAssistantError("You're not signed in. Please log in and try again.")
            return
        }

        let hadOnlyGreeting = messages.count == 1
            && messages.first?.role == .assistant
            && messages.first?.content == Self.defaultGreeting

        if hadOnlyGreeting {
            messages = []
        }

        messages.append(AtlasMessage(role: .user, content: trimmed))
        isTyping = true
        defer { isTyping = false }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "profileId": profileId.uuidString,
            "message": trimmed,
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
            let rows: [CoachMessageRow] = try await SupabaseClient.shared
                .from("coach_messages")
                .select("id, role, content")
                .eq("user_profile_id", value: profileId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = rows.compactMap { row in
                guard let role = AtlasMessage.Role(rawValue: row.role) else { return nil }
                return AtlasMessage(id: row.id, role: role, content: row.content)
            }
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
