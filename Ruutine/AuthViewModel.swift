import Auth
import Combine
import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true

    private var authStateTask: Task<Void, Never>?

    init() {
        authStateTask = Task {
            do {
                session = try await SupabaseClient.shared.auth.session
            } catch {
                session = nil
            }
            isLoading = false

            for await (_, newSession) in SupabaseClient.shared.auth.authStateChanges {
                session = newSession
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    func signIn(email: String, password: String) async throws {
        try await SupabaseClient.shared.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        try await SupabaseClient.shared.auth.signUp(email: email, password: password)
    }

    func signOut() async throws {
        try await SupabaseClient.shared.auth.signOut()
    }
}
