import Foundation
import Combine

// MARK: - AuthUser

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case invalidEmail
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:            return "Please enter a valid email address."
        case .networkError(let msg):   return msg
        }
    }
}

// MARK: - AuthService

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var isSignedIn: Bool { currentUser != nil }

    private init() {}

    // MARK: - Email Auth

    /// Creates a new account with email and password.
    /// TODO: Replace stub with real API call — POST /auth/signup { email, password }
    func createAccount(email: String, password: String) async throws -> AuthUser {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        // Simulate 0.8s network round-trip — remove when wiring real API.
        try await Task.sleep(nanoseconds: 800_000_000)
        let user = AuthUser(id: UUID().uuidString, email: email)
        currentUser = user
        return user
    }

    /// Signs in with email and password.
    /// TODO: Replace stub with real API call — POST /auth/signin { email, password }
    func signIn(email: String, password: String) async throws -> AuthUser {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        // Simulate 0.8s network round-trip — remove when wiring real API.
        try await Task.sleep(nanoseconds: 800_000_000)
        let user = AuthUser(id: UUID().uuidString, email: email)
        currentUser = user
        return user
    }

    // MARK: - Sign Out

    func signOut() {
        currentUser = nil
    }

    // MARK: - Validation

    func isValidEmail(_ email: String) -> Bool {
        let regex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        return email.range(of: regex, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

// MARK: - Apple Sign In (activate when UI stub is removed)
// 1. Add "Sign in with Apple" capability in Xcode → Signing & Capabilities.
// 2. Import AuthenticationServices.
// 3. Implement handleAppleSignIn(result: Result<ASAuthorization, Error>) here.
// 4. Exchange Apple identity token with backend — POST /auth/apple { id_token }.
// 5. Store returned JWT and set currentUser from response payload.

// MARK: - Google Sign In (activate when UI stub is removed)
// 1. Add GoogleSignIn Swift package via SPM.
// 2. Add GIDClientID to Info.plist (from Google Cloud Console OAuth credentials).
// 3. Register URL scheme in Info.plist for the OAuth redirect.
// 4. In AppDelegate / App.onOpenURL, call GIDSignIn.sharedInstance.handle(url).
// 5. Implement signInWithGoogle() here using GoogleAuthManager pattern from Bloggo.
// 6. Exchange Google ID token with backend — POST /auth/google { idToken }.
