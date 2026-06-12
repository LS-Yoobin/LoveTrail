import Foundation

// MARK: - Protocol

protocol ArchiveAPIClientProtocol {
    /// Uploads photo/video data for a single moment. Called once per moment during breakup initiation.
    func uploadMomentMedia(_ moment: Moment) async throws
    /// Creates the archive bundle on the server. Called after all media is uploaded.
    func createArchiveBundle(_ bundle: ArchiveBundle) async throws
    /// Resets the archive expiry date to `newExpiry` on the server.
    func extendRetention(coupleId: String, newExpiry: Date) async throws
    /// Marks this user as stepped out on the server and revokes their access.
    func stepOut(coupleId: String) async throws
    /// Requests a server-generated ZIP export. Returns a download URL.
    func generateExportZip(coupleId: String) async throws -> URL
    /// Creates a reconnect invite on the server and returns it.
    func sendReconnectInvite(coupleId: String) async throws -> BreakupReconnectInvite
    /// Accepts a reconnect invite; server transitions both users back to officialCouple.
    func acceptReconnectInvite(inviteId: UUID, coupleId: String) async throws
}

// MARK: - Stub (replace with real URLSession calls when backend is ready)

final class StubArchiveAPIClient: ArchiveAPIClientProtocol {
    static let shared = StubArchiveAPIClient()
    private init() {}

    func uploadMomentMedia(_ moment: Moment) async throws {
        // TODO: POST media bytes to /archive/media/{moment.id}
        try await Task.sleep(nanoseconds: 10_000_000) // simulate 10ms per photo
    }

    func createArchiveBundle(_ bundle: ArchiveBundle) async throws {
        // TODO: POST encoded bundle to /archive/couples/{bundle.coupleId}
    }

    func extendRetention(coupleId: String, newExpiry: Date) async throws {
        // TODO: PATCH /archive/couples/{coupleId}/expiry with newExpiry
    }

    func stepOut(coupleId: String) async throws {
        // TODO: POST /archive/couples/{coupleId}/step-out
    }

    func generateExportZip(coupleId: String) async throws -> URL {
        // TODO: POST /archive/couples/{coupleId}/export -> returns presigned ZIP URL
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("export.zip")
    }

    func sendReconnectInvite(coupleId: String) async throws -> BreakupReconnectInvite {
        // TODO: POST /archive/couples/{coupleId}/reconnect-invite -> returns invite JSON
        return BreakupReconnectInvite(
            senderUserId: "stub-sender",
            recipientUserId: "stub-recipient"
        )
    }

    func acceptReconnectInvite(inviteId: UUID, coupleId: String) async throws {
        // TODO: POST /archive/reconnect-invites/{inviteId}/accept
    }
}
