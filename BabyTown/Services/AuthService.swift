import Foundation
import Combine
import AuthenticationServices

// MARK: - AuthUser

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case invalidEmail
    case networkError(String)
    case appleSignInCancelled
    case appleSignInFailed

    var errorDescription: String? {
        switch self {
        case .invalidEmail:            return "Please enter a valid email address."
        case .networkError(let msg):   return msg
        case .appleSignInCancelled:    return nil
        case .appleSignInFailed:       return "Apple Sign In failed. Please try again."
        }
    }
}

// MARK: - AuthService

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var authToken: String?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var isSignedIn: Bool { currentUser != nil && authToken != nil }

    private let apiClient: CovelaAPIClient

    private init(apiClient: CovelaAPIClient = .shared) {
        self.apiClient = apiClient
        restoreSession()
    }

    // MARK: - Session

    private func restoreSession() {
        guard let session = KeychainTokenStore.load() else { return }
        authToken = session.token
        currentUser = AuthUser(id: session.userId, email: session.email ?? "")
    }

    private func persistSession(userId: String, email: String?, token: String) throws {
        let session = AuthSession(userId: userId, email: email, token: token)
        try KeychainTokenStore.save(session)
        authToken = token
        currentUser = AuthUser(id: userId, email: email ?? "")
        if let deviceToken = AppDelegate.lastDeviceTokenHex {
            Task { await DeviceAPIClient.shared.registerPushToken(deviceToken) }
        }
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return false
            }
            errorMessage = AuthError.appleSignInFailed.errorDescription
            return false

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("[AuthService] Apple credential cast failed: \(type(of: authorization.credential))")
                errorMessage = AuthError.appleSignInFailed.errorDescription
                return false
            }

            print("[AuthService] Apple credential user=\(credential.user) hasIdentityToken=\(credential.identityToken != nil) hasAuthCode=\(credential.authorizationCode != nil) realUserStatus=\(credential.realUserStatus.rawValue)")

            guard let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  !identityToken.isEmpty else {
                print("[AuthService] identityToken missing or empty after decode. tokenDataBytes=\(credential.identityToken?.count ?? -1)")
                errorMessage = AuthError.appleSignInFailed.errorDescription
                return false
            }

            print("[AuthService] identityToken decoded, length=\(identityToken.count), prefix=\(identityToken.prefix(12))...")

            let authorizationCode = credential.authorizationCode
                .flatMap { String(data: $0, encoding: .utf8) }
            if let authorizationCode {
                print("[AuthService] authorizationCode decoded, length=\(authorizationCode.count)")
            } else {
                print("[AuthService] authorizationCode is nil or failed to decode as UTF-8")
            }

            let displayName = Self.formatAppleFullName(credential.fullName)

            do {
                let response = try await apiClient.signInWithApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    displayName: displayName.isEmpty ? nil : displayName
                )
                try persistSession(userId: response.userId, email: nil, token: response.token)
                return true
            } catch let error as CovelaAPIError {
                errorMessage = error.errorDescription
                return false
            } catch {
                errorMessage = AuthError.networkError(error.localizedDescription).errorDescription
                return false
            }
        }
    }

    private static func formatAppleFullName(_ name: PersonNameComponents?) -> String {
        guard let name else { return "" }
        return PersonNameComponentsFormatter.localizedString(from: name, style: .default)
    }

    // MARK: - Email Auth

    /// Creates a new account with email and password.
    func createAccount(email: String, password: String, displayName: String? = nil) async throws -> AuthUser {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await apiClient.registerWithEmail(email: email, password: password, displayName: displayName)
            try persistSession(userId: response.userId, email: email, token: response.token)
            return AuthUser(id: response.userId, email: email)
        } catch let error as CovelaAPIError {
            errorMessage = error.errorDescription
            throw error
        } catch {
            errorMessage = AuthError.networkError(error.localizedDescription).errorDescription
            throw error
        }
    }

    /// Signs in with email and password.
    func signIn(email: String, password: String) async throws -> AuthUser {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await apiClient.loginWithEmail(email: email, password: password)
            try persistSession(userId: response.userId, email: email, token: response.token)
            return AuthUser(id: response.userId, email: email)
        } catch let error as CovelaAPIError {
            errorMessage = error.errorDescription
            throw error
        } catch {
            errorMessage = AuthError.networkError(error.localizedDescription).errorDescription
            throw error
        }
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainTokenStore.clear()
        currentUser = nil
        authToken = nil
        errorMessage = nil
    }

    // MARK: - Delete Account

    /// Permanently deletes the signed-in account on the server, then clears local auth state.
    func deleteAccount() async throws {
        guard let token = authToken else {
            throw CovelaAPIError.unauthorized
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await apiClient.deleteAccount(token: token)
            guard response.success else {
                throw CovelaAPIError.server("Account deletion failed.")
            }
            signOut()
        } catch let error as CovelaAPIError {
            errorMessage = error.errorDescription
            throw error
        } catch {
            errorMessage = AuthError.networkError(error.localizedDescription).errorDescription
            throw error
        }
    }

    // MARK: - Validation

    func isValidEmail(_ email: String) -> Bool {
        let regex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        return email.range(of: regex, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

// MARK: - Google Sign In (activate when UI stub is removed)
// 1. Add GoogleSignIn Swift package via SPM.
// 2. Add GIDClientID to Info.plist (from Google Cloud Console OAuth credentials).
// 3. Register URL scheme in Info.plist for the OAuth redirect.
// 4. In AppDelegate / App.onOpenURL, call GIDSignIn.sharedInstance.handle(url).
// 5. Implement signInWithGoogle() here using GoogleAuthManager pattern from Bloggo.
// 6. Exchange Google ID token with backend — POST /auth/google { idToken }.
