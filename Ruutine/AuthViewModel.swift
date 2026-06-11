import Auth
import Combine
import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true
    @Published var isCheckingOnboarding = false
    /// `nil` = unknown / not signed in; `true` = profile exists; `false` = needs onboarding.
    @Published var hasCompletedOnboarding: Bool?

    private var authStateTask: Task<Void, Never>?

    init() {
        authStateTask = Task {
            do {
                session = try await SupabaseClient.shared.auth.session
            } catch {
                session = nil
            }
            isLoading = false
            await refreshOnboardingStatus()

            for await (_, newSession) in SupabaseClient.shared.auth.authStateChanges {
                session = newSession
                await refreshOnboardingStatus()
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
        hasCompletedOnboarding = nil
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }

    func refreshOnboardingStatus() async {
        guard let userId = session?.user.id else {
            hasCompletedOnboarding = nil
            return
        }

        isCheckingOnboarding = true
        defer { isCheckingOnboarding = false }

        struct ProfileIDRow: Decodable {
            let id: UUID
        }

        do {
            let _: ProfileIDRow = try await SupabaseClient.shared
                .from("user_profiles")
                .select("id")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            hasCompletedOnboarding = true
        } catch {
            hasCompletedOnboarding = false
        }
    }
}
