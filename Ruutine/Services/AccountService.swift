import Foundation

enum AccountService {
    private static let deleteURL = URL(string: "https://www.ruutine.app/api/account/delete")!

    static func deleteAccount(accessToken: String) async throws {
        var request = URLRequest(url: deleteURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[AccountService] POST account/delete status: \(status)")

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
