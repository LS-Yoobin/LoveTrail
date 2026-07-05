import Foundation

struct AppleAuthResponse: Decodable {
    let token: String
    let userId: String
    let isNewUser: Bool
}

enum CovelaAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API configuration."
        case .invalidResponse: return "Unexpected server response."
        case .unauthorized: return "Please sign in again."
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

        return try await request(method: "POST", path: "auth/apple", body: body, token: nil)
    }

    // MARK: - Generic authenticated methods

    func get<T: Decodable>(path: String, token: String? = nil) async throws -> T {
        try await request(method: "GET", path: path, body: nil, token: token)
    }

    func post<T: Decodable>(path: String, body: [String: Any] = [:], token: String? = nil) async throws -> T {
        try await request(method: "POST", path: path, body: body, token: token)
    }

    func patch<T: Decodable>(path: String, body: [String: Any], token: String? = nil) async throws -> T {
        try await request(method: "PATCH", path: path, body: body, token: token)
    }

    func delete<T: Decodable>(path: String, token: String? = nil) async throws -> T {
        try await request(method: "DELETE", path: path, body: nil, token: token)
    }

    // MARK: - Core request

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: [String: Any]?,
        token: String?
    ) async throws -> T {
        let base = CovelaAPIConfig.baseURL
        let url = base.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var bodyData: Data?
        if let body {
            bodyData = try JSONSerialization.data(withJSONObject: body)
            urlRequest.httpBody = bodyData
        }

        let valueLengths = (body ?? [:]).mapValues { value -> Int in
            (value as? String)?.count ?? -1
        }
        print("[CovelaAPIClient] \(method) \(url.absoluteString) bodyKeys=\(Array((body ?? [:]).keys)) valueLengths=\(valueLengths) bodyBytes=\(bodyData?.count ?? 0) authed=\(token != nil)")

        let (data, response) = try await session.data(for: urlRequest)
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

        if token != nil, http.statusCode == 401 {
            throw CovelaAPIError.unauthorized
        }

        if let serverError = try? decoder.decode([String: String].self, from: data),
           let message = serverError["error"] {
            throw CovelaAPIError.server(message)
        }

        throw CovelaAPIError.server("Request failed (\(http.statusCode)).")
    }
}
