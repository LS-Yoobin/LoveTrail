import Foundation

/// Server side of the Breakup phase (BAB-145, client BAB-105).
///
/// Endpoints under `/covela/api/couple`:
/// - `POST /breakup` starts the archive window (idempotent)
/// - `GET /archive` returns the shared window state (409 `not_archived` while together)
/// - `POST /archive/extend` adds 30 days
/// - `POST /step-out` leaves now; the couple dissolves when both have stepped out
///
/// Export and reconnect have no server endpoints yet and stay local.
struct ArchiveServerState: Equatable {
    let breakupDate: Date?
    let archiveExpiresAt: Date?
    /// user id → stepped-out time
    let steppedOut: [String: Date]
    /// `true` when this call dissolved the couple (both partners stepped out).
    let dissolved: Bool

    init(json: [String: Any]) {
        breakupDate = SyncJSON.date(from: json["breakup_date"])
        archiveExpiresAt = SyncJSON.date(from: json["archive_expires_at"])
        var stepped: [String: Date] = [:]
        for (userId, value) in json["stepped_out"] as? [String: Any] ?? [:] {
            if let date = SyncJSON.date(from: value) { stepped[userId.lowercased()] = date }
        }
        steppedOut = stepped
        dissolved = (json["dissolved"] as? Bool) ?? false
    }
}

enum ArchiveAPIError: Error, Equatable {
    case offline
    case signedOut
    /// The couple is not in an archive window (`not_archived`, or still together).
    case notArchived
    /// This account can no longer reach the couple (stepped out, or dissolved).
    case noAccess
    case server(Int)
}

protocol ArchiveAPIClientProtocol {
    func startBreakup() async throws -> ArchiveServerState
    func fetchArchive() async throws -> ArchiveServerState
    func extendArchive() async throws -> ArchiveServerState
    func stepOut() async throws -> ArchiveServerState
}

final class LiveArchiveAPIClient: ArchiveAPIClientProtocol {
    static let shared = LiveArchiveAPIClient()

    private let api: CovelaAPIClient

    init(api: CovelaAPIClient = .shared) {
        self.api = api
    }

    func startBreakup() async throws -> ArchiveServerState {
        try await call("POST", "couple/breakup")
    }

    func fetchArchive() async throws -> ArchiveServerState {
        try await call("GET", "couple/archive")
    }

    func extendArchive() async throws -> ArchiveServerState {
        try await call("POST", "couple/archive/extend")
    }

    func stepOut() async throws -> ArchiveServerState {
        try await call("POST", "couple/step-out")
    }

    private func call(_ method: String, _ path: String) async throws -> ArchiveServerState {
        guard let token = await AuthService.shared.authToken else { throw ArchiveAPIError.signedOut }
        let response: CovelaAPIClient.RawResponse
        do {
            response = try await api.send(
                method: method,
                path: path,
                body: method == "GET" ? nil : [:],
                token: token
            )
        } catch {
            throw ArchiveAPIError.offline
        }
        switch response.status {
        case 200..<300:
            return ArchiveServerState(json: response.jsonObject() ?? [:])
        case 401:
            throw ArchiveAPIError.signedOut
        case 403:
            throw ArchiveAPIError.noAccess
        case 409 where response.failureReason == "not_archived" || response.failureReason == "not_official_couple":
            throw ArchiveAPIError.notArchived
        default:
            throw ArchiveAPIError.server(response.status)
        }
    }
}
