import Combine
import Foundation

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

    private var profileId: UUID?
    private var didSeedGreeting = false

    private let endpoint = URL(string: "https://ruutine.app/api/coach/chat")!

    func configure(profileId: UUID) {
        guard self.profileId != profileId || !didSeedGreeting else { return }
        self.profileId = profileId
        seedGreetingIfNeeded()
    }

    func seedGreetingIfNeeded() {
        guard !didSeedGreeting else { return }
        didSeedGreeting = true
        if messages.isEmpty {
            messages = [
                AtlasMessage(
                    role: .assistant,
                    content: "Hey, I'm Atlas. How can I help with your training today?"
                ),
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
                appendAssistantError("Unexpected response from Atlas.")
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String,
               !error.isEmpty {
                appendAssistantError(error)
                return
            }

            guard (200...299).contains(http.statusCode) else {
                appendAssistantError("Atlas request failed (HTTP \(http.statusCode)).")
                return
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reply = json["text"] as? String,
               !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append(AtlasMessage(role: .assistant, content: reply))
            } else {
                appendAssistantError("Atlas returned an empty response.")
            }
        } catch {
            print("[AtlasService] network error: \(error)")
            appendAssistantError("Couldn't reach Atlas. Check your connection and try again.")
        }
    }

    private func appendAssistantError(_ message: String) {
        messages.append(AtlasMessage(role: .assistant, content: message))
    }
}
