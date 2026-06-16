import Auth
import Combine
import Foundation
import Supabase

enum SignUpOutcome: Equatable {
    case sessionActive
    case confirmationRequired(email: String)
}

enum AuthError: LocalizedError {
    case emailAlreadyRegistered
    case invalidEmail
    case weakPassword
    case passwordsDoNotMatch

    var errorDescription: String? {
        switch self {
        case .emailAlreadyRegistered:
            return "An account with this email already exists. Try signing in instead."
        case .invalidEmail:
            return "Enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .passwordsDoNotMatch:
            return "Passwords do not match."
        }
    }
}

enum SignInError: Equatable {
    case invalidCredentials
    case rateLimited
    case networkUnavailable
    case unknown(String)

    var message: String? {
        switch self {
        case .invalidCredentials:
            return nil
        case .rateLimited:
            return "Too many sign-in attempts. Please wait a moment and try again."
        case .networkUnavailable:
            return "Couldn't reach Ruu. Check your connection and try again."
        case .unknown(let message):
            return message
        }
    }

    static func map(_ error: Error) -> SignInError {
        if let signInError = error as? SignInError {
            return signInError
        }

        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login credentials") {
            return .invalidCredentials
        }
        if message.contains("rate limit") || message.contains("too many requests") {
            return .rateLimited
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .networkUnavailable
        }
        if message.contains("network")
            || message.contains("internet")
            || message.contains("offline")
            || message.contains("timed out")
            || message.contains("could not connect") {
            return .networkUnavailable
        }

        return .unknown(error.localizedDescription)
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true
    @Published var isCheckingOnboarding = false
    /// `nil` = unknown / not signed in; `true` = profile exists; `false` = needs onboarding.
    @Published var hasCompletedOnboarding: Bool?

    private static let emailConfirmationRedirect = URL(string: "https://ruutine.app/auth/callback")!

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

    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isValidEmail(trimmedEmail) else {
            throw AuthError.invalidEmail
        }

        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }

        let response: AuthResponse
        do {
            response = try await SupabaseClient.shared.auth.signUp(
                email: trimmedEmail,
                password: password,
                redirectTo: Self.emailConfirmationRedirect
            )
        } catch {
            throw Self.mapSignUpError(error)
        }

        if let session = response.session {
            self.session = session
            await refreshOnboardingStatus()
            return .sessionActive
        }

        let identities = response.user.identities ?? []
        if identities.isEmpty {
            throw AuthError.emailAlreadyRegistered
        }

        return .confirmationRequired(email: trimmedEmail)
    }

    func signOut() async throws {
        try await SupabaseClient.shared.auth.signOut()
        hasCompletedOnboarding = nil
        ThemeManager.shared.resetToDefault()
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }

    func refreshOnboardingStatus() async {
        guard let userId = session?.user.id else {
            hasCompletedOnboarding = nil
            ThemeManager.shared.resetToDefault()
            return
        }

        isCheckingOnboarding = true
        defer { isCheckingOnboarding = false }

        struct ProfileThemeRow: Decodable {
            let id: UUID
            let theme: String?
        }

        do {
            let profile: ProfileThemeRow = try await SupabaseClient.shared
                .from("user_profiles")
                .select("id, theme")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            hasCompletedOnboarding = true
            ThemeManager.shared.applyFromProfile(profile.theme)
        } catch {
            hasCompletedOnboarding = false
        }
    }

    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private static func mapSignUpError(_ error: Error) -> Error {
        if let authError = error as? AuthError {
            return authError
        }

        let message = error.localizedDescription.lowercased()

        if message.contains("already registered")
            || message.contains("already exists")
            || message.contains("user already registered") {
            return AuthError.emailAlreadyRegistered
        }
        if message.contains("invalid email")
            || message.contains("unable to validate email")
            || message.contains("email address") && message.contains("invalid") {
            return AuthError.invalidEmail
        }
        if message.contains("password")
            && (message.contains("weak") || message.contains("short") || message.contains("least")) {
            return AuthError.weakPassword
        }

        return error
    }
}
