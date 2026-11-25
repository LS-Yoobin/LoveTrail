import Foundation

// Stand-ins for the app types the real sync files depend on. Only what
// CoupleSyncEngine, CoupleSyncState, SyncMedia and CoupleProfileSyncResource touch.
// Each simulated phone is a `Device`; switching `Device.current` switches the
// signed-in account, the storage scope and the local data the stubs read.

// MARK: - Simulated phones

final class Device {
    nonisolated(unsafe) static var current: Device!

    let userId: String
    let token: String
    let scopeDirectory: URL

    // Local data (what DataPersistenceManager would hold on that phone).
    var profile = CoupleProfile()
    var userNickname: String?
    var ownAvatar: Data?
    var ownAvatarRemovalPending = false
    var syncedPartnerNickname: String?
    var syncedPartnerAvatar: Data?
    var inviterName: String?
    var serverCoupleProfileId: String?

    init(userId: String, root: URL) {
        self.userId = userId
        self.token = "test-token-\(userId)"
        self.scopeDirectory = root.appendingPathComponent(userId)
        try? FileManager.default.createDirectory(at: scopeDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Models

enum RelationshipStage: String, Codable {
    case prelude, officialCouple, archivedCouple
}

enum ProfileNoteMood: String, CaseIterable, Codable, Equatable {
    case butterflies, giddy, smitten, playful
}

struct CoupleProfile {
    var displayName: String?
    var profileNote: String?
    var profileNoteMood: ProfileNoteMood?
    var relationshipStage: RelationshipStage = .prelude
}

// MARK: - Auth

struct AuthUser: Equatable {
    let id: String
    let email: String
}

final class AuthService {
    static let shared = AuthService()
    var currentUser: AuthUser? { Device.current.map { AuthUser(id: $0.userId, email: "") } }
    var authToken: String? { Device.current?.token }
    var isSignedIn: Bool { currentUser != nil && authToken != nil }
}

extension Notification.Name {
    static let covelaAccountDidChange = Notification.Name("covelaAccountDidChange")
}

// MARK: - Persistence

final class DataPersistenceManager {
    static let shared = DataPersistenceManager()
    private var d: Device { Device.current }

    var activeScopeId: String { d.userId }
    var currentScopeDirectory: URL { d.scopeDirectory }

    func loadCoupleProfile() -> CoupleProfile { d.profile }
    func saveCoupleProfile(_ profile: CoupleProfile) { d.profile = profile }

    func loadUserNickname() -> String? { d.userNickname }
    func loadOwnAvatarData() -> Data? { d.ownAvatar }
    var isOwnAvatarRemovalPending: Bool { d.ownAvatarRemovalPending }
    func clearOwnAvatarRemovalPending() { d.ownAvatarRemovalPending = false }

    func saveSyncedPartnerNickname(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        d.syncedPartnerNickname = trimmed
    }
    func loadSyncedPartnerNickname() -> String? { d.syncedPartnerNickname }

    func saveOtherPartnerAvatarData(_ data: Data) { d.syncedPartnerAvatar = data }
    func loadOtherPartnerAvatarData() -> Data? { d.syncedPartnerAvatar }
    func removeOtherPartnerAvatar() { d.syncedPartnerAvatar = nil }

    func saveServerCoupleProfileId(_ id: String) { d.serverCoupleProfileId = id }
}

// MARK: - Network

enum CovelaAPIError: Error { case unauthorized }

class CovelaAPIClient {
    static let shared = CovelaAPIClient()

    struct RawResponse {
        let status: Int
        let data: Data
        var isSuccess: Bool { (200..<300).contains(status) }
        var failureReason: String? {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return object["reason"] as? String
        }
        func jsonObject() -> [String: Any]? {
            try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
    }

    func send(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        token: String
    ) async throws -> RawResponse {
        // Like URLSession: a request in flight when its task is cancelled fails
        // (NSURLError -999 in the app; CancellationError here). Never reaches the server.
        if FakeServer.shared.latencyNanos > 0 {
            try await Task.sleep(nanoseconds: FakeServer.shared.latencyNanos)
        }
        if FakeServer.shared.offlineGets.contains(path), method == "GET" { throw URLError(.notConnectedToInternet) }
        return try FakeServer.shared.handle(method: method, path: path, query: query, body: body, token: token)
    }

    func signedMediaURL(forPath path: String, token: String? = nil) async throws -> URL {
        URL(string: "https://media.test/\(path)")!
    }
}

enum CovelaMediaUploadError: LocalizedError {
    case notSignedIn, invalidResponse, network, rejected(String?), serializationFailed
    case httpError(Int, String)
}

final class CovelaMediaUploadClient {
    static let shared = CovelaMediaUploadClient()
    func uploadJPEGData(_ data: Data, filename: String = "photo.jpg", quality: Int = 80) async throws -> String {
        if let error = FakeServer.shared.uploadError { throw error }
        if let forced = FakeServer.shared.uploadReturnsPath { return forced }
        return FakeServer.shared.storeMedia(data)
    }
    func uploadVideo(_ data: Data, filename: String) async throws -> String { FakeServer.shared.storeMedia(data) }
    func uploadSticker(_ data: Data, filename: String = "sticker.png") async throws -> String { FakeServer.shared.storeMedia(data) }
    func uploadVoiceMemo(_ data: Data, filename: String = "voice.m4a") async throws -> String { FakeServer.shared.storeMedia(data) }
}

/// Serves `https://media.test/<path>` from the fake server's media store, so the real
/// `SyncMediaTransfer.download` runs unchanged.
final class FakeMediaURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "media.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = String(request.url!.path.dropFirst())
        let data = FakeServer.media[path]
        let response = HTTPURLResponse(url: request.url!, statusCode: data == nil ? 404 : 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// MARK: - Engine collaborators not under test

final class ArchiveService {
    static let shared = ArchiveService()
    func refreshFromServer() async {}
}

final class CoinLedgerSync {
    static let shared = CoinLedgerSync()
    func reset() {}
}

final class LettersSyncResource {
    static let shared = LettersSyncResource()
    func reset() {}
}
