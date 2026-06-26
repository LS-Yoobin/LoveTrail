import Foundation

protocol WatchTogetherAPIClientProtocol {
    func createSession(videoURL: String) async throws -> WatchTogetherSession
    func joinSession(id: UUID) async throws -> WatchTogetherSession
    func endSession(id: UUID) async throws
    func activeSession() async throws -> WatchTogetherSession?
}

final class StubWatchTogetherAPIClient: WatchTogetherAPIClientProtocol {
    static let shared = StubWatchTogetherAPIClient()
    private var sessions: [UUID: WatchTogetherSession] = [:]
    private init() {}

    func createSession(videoURL: String) async throws -> WatchTogetherSession {
        let profile = DataPersistenceManager.shared.loadCoupleProfile()
        let session = WatchTogetherSession(
            id: UUID(),
            coupleID: profile.coupleId ?? "local-couple",
            hostUserID: DataPersistenceManager.shared.loadUserNickname() ?? "host",
            videoURL: videoURL,
            status: .waiting,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(4 * 60 * 60)
        )
        sessions[session.id] = session
        return session
    }

    func joinSession(id: UUID) async throws -> WatchTogetherSession {
        guard var session = sessions[id] else { throw URLError(.fileDoesNotExist) }
        session.status = .active
        sessions[id] = session
        return session
    }

    func endSession(id: UUID) async throws {
        sessions.removeValue(forKey: id)
    }

    func activeSession() async throws -> WatchTogetherSession? {
        sessions.values.first { $0.status != .ended && $0.expiresAt > Date() }
    }
}
