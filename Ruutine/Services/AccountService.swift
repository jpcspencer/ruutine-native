import Foundation

enum AccountService {
    private static let deleteURL = URL(string: "https://ruutine.app/api/account/delete")!

    static func deleteAccount(userId: UUID, profileId: UUID) async throws {
        let body: [String: Any] = [
            "userId": userId.uuidString,
            "profileId": profileId.uuidString,
        ]

        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[AccountService] DELETE account/delete status: \(status)")

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AccountServiceError.deleteFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["success"] as? Bool == true
        else {
            throw AccountServiceError.deleteFailed
        }
    }
}

enum AccountServiceError: LocalizedError {
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .deleteFailed:
            return "Couldn't delete your account. Please try again."
        }
    }
}
