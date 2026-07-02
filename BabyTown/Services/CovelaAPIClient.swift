import Foundation

struct AppleAuthResponse: Decodable {
    let token: String
    let userId: String
    let isNewUser: Bool
}

enum CovelaAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API configuration."
        case .invalidResponse: return "Unexpected server response."
        case .server(let message): return message
        }
    }
}

final class CovelaAPIClient {
    static let shared = CovelaAPIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        displayName: String?
    ) async throws -> AppleAuthResponse {
        var body: [String: Any] = ["identityToken": identityToken]
        if let authorizationCode { body["authorizationCode"] = authorizationCode }
        if let displayName, !displayName.isEmpty { body["displayName"] = displayName }

        return try await post(path: "auth/apple", body: body)
    }

    private func post<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        let base = CovelaAPIConfig.baseURL
        let url = base.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData

        let valueLengths = body.mapValues { value -> Int in
            (value as? String)?.count ?? -1
        }
        print("[CovelaAPIClient] POST \(url.absoluteString) bodyKeys=\(Array(body.keys)) valueLengths=\(valueLengths) bodyBytes=\(bodyData.count)")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CovelaAPIError.invalidResponse
        }

        let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        print("[CovelaAPIClient] \(url.path) -> status=\(http.statusCode) body=\(rawBody)")

        if (200..<300).contains(http.statusCode) {
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw CovelaAPIError.invalidResponse
            }
        }

        if let serverError = try? decoder.decode([String: String].self, from: data),
           let message = serverError["error"] {
            throw CovelaAPIError.server(message)
        }

        throw CovelaAPIError.server("Sign in failed (\(http.statusCode)).")
    }
}
