import Foundation

// MARK: - Display model

/// Lightweight display-only capture passed to PartnerGiftRevealView.
/// Produced by the API response; not the full PreludeCapture model.
struct GiftRevealCapture: Identifiable {
    let id: UUID
    let type: PreludeCapture.CaptureType
    let displayText: String
    let typeIcon: String
}

extension GiftRevealCapture: Equatable {
    static func == (lhs: GiftRevealCapture, rhs: GiftRevealCapture) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type && lhs.displayText == rhs.displayText && lhs.typeIcon == rhs.typeIcon
    }
}

// MARK: - Response types

struct InviteCreatedResponse {
    let code: String
    let link: String
}

struct InviteStatusResponse {
    enum Status: String { case pending, accepted, expired, cancelled }
    let status: Status
}

struct InviteAcceptedResponse {
    /// Captures to show in PartnerGiftRevealView. Empty means skip the reveal screen.
    let revealCaptures: [GiftRevealCapture]
    /// The name shown in the reveal header, e.g. "Sarah's Prelude".
    let revealerName: String
}

// MARK: - Protocol

protocol InviteAPIClientProtocol {
    /// POST /create-invite
    func createInvite(inviterName: String) async throws -> InviteCreatedResponse
    /// GET /invite/:code — polls for partner acceptance
    func checkInviteStatus(code: String) async throws -> InviteStatusResponse
    /// POST /accept-invite — called when user enters a referral code
    func acceptInvite(code: String) async throws -> InviteAcceptedResponse
}

// MARK: - Stub (replace with real URLSession calls when backend is ready)

final class StubInviteAPIClient: InviteAPIClientProtocol {
    static let shared = StubInviteAPIClient()
    private init() {}

    func createInvite(inviterName: String) async throws -> InviteCreatedResponse {
        // TODO: POST /create-invite with body { inviterName, gift_capture_ids }
        try await Task.sleep(nanoseconds: 600_000_000)
        let code = PartnerInvite.generateCode()
        return InviteCreatedResponse(
            code: code,
            link: "https://covela.app/invite/\(code)"
        )
    }

    func checkInviteStatus(code: String) async throws -> InviteStatusResponse {
        // TODO: GET /invite/:code — check status field in response JSON
        return InviteStatusResponse(status: .pending)
    }

    func acceptInvite(code: String) async throws -> InviteAcceptedResponse {
        // TODO: POST /accept-invite with body { code }
        // On success, map inviter_gift_captures to GiftRevealCapture array.
        // If inviter had no prelude captures, return empty revealCaptures.
        try await Task.sleep(nanoseconds: 600_000_000)
        return InviteAcceptedResponse(revealCaptures: [], revealerName: "Your partner")
    }
}
