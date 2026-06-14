import Foundation

enum RecapMessageService {
    private static let endpoint = URL(string: "https://www.ruutine.app/api/sessions/recap-message")!

    static func fetchMessage(for data: WorkoutRecapData) async -> Result<String, Error> {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "profileId": data.profileId.uuidString,
            "sessionName": data.sessionName,
            "totalTimeSeconds": data.durationSeconds,
            "totalSets": data.totalSets,
            "totalVolumeKg": data.totalVolumeKg,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .failure(RecapMessageError.badResponse)
            }

            guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let message = json["message"] as? String,
                  !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return .failure(RecapMessageError.emptyMessage)
            }

            return .success(message)
        } catch {
            return .failure(error)
        }
    }
}

private enum RecapMessageError: Error {
    case badResponse
    case emptyMessage
}
