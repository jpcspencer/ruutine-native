import Foundation

enum ProgramService {
    private static let generateURL = URL(string: "https://ruutine.app/api/coach/generate")!
    private static let programURL = URL(string: "https://ruutine.app/api/program")!
    private static let programEditURL = URL(string: "https://ruutine.app/api/program/edit")!

    static func regenerateProgram(profileId: UUID) async throws {
        let body: [String: Any] = [
            "profileId": profileId.uuidString,
            "forceRegenerate": true,
        ]
        let (data, response) = try await postJSON(to: generateURL, body: body)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[ProgramService] POST coach/generate status: \(status)")
        print("[ProgramService] raw response: \(String(data: data, encoding: .utf8) ?? "")")
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ProgramServiceError.requestFailed(status: status)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            throw ProgramServiceError.server(error)
        }
    }

    static func saveProgram(profileId: UUID, programContent: [String: Any]) async throws {
        let body: [String: Any] = [
            "profileId": profileId.uuidString,
            "programContent": programContent,
        ]
        var request = URLRequest(url: programURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[ProgramService] PATCH program status: \(status)")
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ProgramServiceError.requestFailed(status: status)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            throw ProgramServiceError.server(error)
        }
    }

    static func editProgramWithAtlas(
        profileId: UUID,
        message: String,
        programContent: [String: Any]
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "profileId": profileId.uuidString,
            "message": message,
            "programContent": programContent,
        ]
        let (data, response) = try await postJSON(to: programEditURL, body: body)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[ProgramService] POST program/edit status: \(status)")
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ProgramServiceError.requestFailed(status: status)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProgramServiceError.server("Invalid response")
        }
        if let error = json["error"] as? String {
            throw ProgramServiceError.server(error)
        }
        guard let program = json["program"] as? [String: Any] else {
            throw ProgramServiceError.server("No program in response")
        }
        return program
    }

    private static func postJSON(to url: URL, body: [String: Any]) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await URLSession.shared.data(for: request)
    }
}

enum ProgramServiceError: LocalizedError {
    case requestFailed(status: Int)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let status): return "Request failed (HTTP \(status))."
        case .server(let message): return message
        }
    }
}
