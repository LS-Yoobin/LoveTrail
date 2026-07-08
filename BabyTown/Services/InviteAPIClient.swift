import Foundation
import CryptoKit

// MARK: - Display model

/// Lightweight display-only capture passed to PartnerGiftRevealView.
/// Produced by the API response; not the full PreludeCapture model.
struct GiftRevealCapture: Identifiable {
    let id: UUID
    let type: PreludeCapture.CaptureType
    let typeIcon: String
    let noteText: String?
    let firstLabel: String?
    let reasonText: String?
    /// Permanent covela-fs S3 key for a note/first photo, when present.
    let photoPath: String?
    /// Signed, short-lived covela-fs URL for a note/first photo, when present.
    let photoURL: String?
    /// Signed, short-lived covela-fs URL for a voice memo, when present.
    let audioURL: String?
    /// Backend capture id (Mongo ObjectId string).
    let serverId: String?

    var displayText: String {
        PreludeCapture(
            type: type,
            noteText: noteText,
            firstLabel: firstLabel,
            reasonText: reasonText
        ).displayTitle
    }

    init(
        id: UUID,
        type: PreludeCapture.CaptureType,
        typeIcon: String,
        noteText: String? = nil,
        firstLabel: String? = nil,
        reasonText: String? = nil,
        photoPath: String? = nil,
        photoURL: String? = nil,
        audioURL: String? = nil,
        serverId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.typeIcon = typeIcon
        self.noteText = noteText
        self.firstLabel = firstLabel
        self.reasonText = reasonText
        self.photoPath = photoPath
        self.photoURL = photoURL
        self.audioURL = audioURL
        self.serverId = serverId
    }
}

extension GiftRevealCapture: Equatable {
    static func == (lhs: GiftRevealCapture, rhs: GiftRevealCapture) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type && lhs.typeIcon == rhs.typeIcon
            &&         lhs.noteText == rhs.noteText && lhs.firstLabel == rhs.firstLabel
            && lhs.reasonText == rhs.reasonText && lhs.photoPath == rhs.photoPath
            && lhs.photoURL == rhs.photoURL && lhs.audioURL == rhs.audioURL
            && lhs.serverId == rhs.serverId
    }
}

// MARK: - Response types

struct InviteCreatedResponse {
    let code: String
    let link: String
}

struct InviteStatusResponse {
    enum Status: String { case pending, accepted, expired, cancelled }
    /// `false` when the code does not correspond to any invite at all.
    let valid: Bool
    /// `nil` only when the code was never found.
    let status: Status?
    /// The inviter's display name, when known.
    let inviterName: String?
    /// Whether the caller (if authenticated) already has an account.
    let existingUser: Bool
}

struct InviteAcceptedResponse {
    /// Captures to show in PartnerGiftRevealView. Empty means skip the reveal screen.
    let revealCaptures: [GiftRevealCapture]
    /// The name shown in the reveal header, e.g. "Sarah's Prelude".
    let revealerName: String
}

struct PairingStatusResponse {
    /// Whether this account already belongs to an official couple on the backend,
    /// regardless of what local onboarding state says.
    let paired: Bool
    let partnerName: String?
    /// Backend couple stage when the user has a couple profile but is not paired yet.
    let relationshipStage: RelationshipStage?
    let inviteSent: Bool
}

// MARK: - Protocol

protocol InviteAPIClientProtocol {
    /// POST /create-invite
    func createInvite(inviterName: String, giftCaptureIds: [String]) async throws -> InviteCreatedResponse
    /// POST /send-invite-email
    func sendInviteEmail(partnerEmail: String, inviterName: String, code: String) async throws
    /// GET /invite/:code — validates a code and polls for partner acceptance
    func checkInviteStatus(code: String) async throws -> InviteStatusResponse
    /// POST /accept-invite — called when user enters a referral code
    func acceptInvite(code: String) async throws -> InviteAcceptedResponse
    /// GET /pairing-status — authoritative check of whether this account is
    /// already an official couple on the backend, independent of any code.
    func checkPairingStatus() async throws -> PairingStatusResponse
}

// MARK: - Friendly error mapping

enum InviteErrorMapper {
    static func message(for error: Error) -> String {
        guard let apiError = error as? CovelaAPIError else {
            return "Something went wrong. Please try again."
        }
        switch apiError {
        case .unauthorized:
            return "Please sign in again."
        case .invalidURL, .invalidResponse:
            return "Something went wrong. Please try again."
        case .server(let message):
            let lower = message.lowercased()
            if lower.contains("cannot accept your own invite") {
                return "You can't use your own code."
            } else if lower.contains("expired") {
                return "That code has expired."
            } else if lower.contains("already accepted") || lower.contains("already in an official couple") {
                return "You're already paired."
            } else if lower.contains("not found") {
                return "That code is not valid."
            }
            return message
        }
    }

    /// True when the server rejected the call because this account (or the
    /// couple behind the code) is already an official couple — the caller
    /// should stop offering invite/join actions and route to Home instead of
    /// just displaying the error text.
    static func isAlreadyPaired(_ error: Error) -> Bool {
        guard let apiError = error as? CovelaAPIError, case .server(let message) = apiError else { return false }
        let lower = message.lowercased()
        return lower.contains("already accepted") || lower.contains("already in an official couple")
    }
}

// MARK: - Live implementation

final class LiveInviteAPIClient: InviteAPIClientProtocol {
    private let client: CovelaAPIClient

    init(client: CovelaAPIClient = .shared) {
        self.client = client
    }

    private struct CreateInviteResponse: Decodable {
        let code: String
        let link: String
    }

    func createInvite(inviterName: String, giftCaptureIds: [String]) async throws -> InviteCreatedResponse {
        guard let token = await AuthService.shared.authToken else {
            throw CovelaAPIError.unauthorized
        }
        let response: CreateInviteResponse = try await client.post(
            path: "create-invite",
            body: ["inviter_name": inviterName, "gift_capture_ids": giftCaptureIds],
            token: token
        )
        return InviteCreatedResponse(code: response.code, link: response.link)
    }

    func sendInviteEmail(partnerEmail: String, inviterName: String, code: String) async throws {
        throw CovelaAPIError.server("Email invites aren't available yet. Share the code instead.")
    }

    private struct InviteLookupResponse: Decodable {
        let valid: Bool
        let status: String?
        let inviterName: String?
        let existingUser: Bool?

        enum CodingKeys: String, CodingKey {
            case valid, status
            case inviterName = "inviter_name"
            case existingUser = "existing_user"
        }
    }

    func checkInviteStatus(code: String) async throws -> InviteStatusResponse {
        let token = await AuthService.shared.authToken
        let response: InviteLookupResponse = try await client.get(path: "invite/\(code)", token: token)
        return InviteStatusResponse(
            valid: response.valid,
            status: response.status.flatMap(InviteStatusResponse.Status.init(rawValue:)),
            inviterName: response.inviterName,
            existingUser: response.existingUser ?? false
        )
    }

    private struct BackendCaptureDTO: Decodable {
        let id: String
        let type: String
        let noteText: String?
        let firstLabel: String?
        let reasonText: String?
        let notePhotoUrl: String?
        let firstPhotoUrl: String?
        let photoUrl: String?
        let photoPath: String?
        let voiceMemoUrl: String?

        enum CodingKeys: String, CodingKey {
            case id, type
            case noteText = "note_text"
            case firstLabel = "first_label"
            case reasonText = "reason_text"
            case notePhotoUrl = "note_photo_url"
            case firstPhotoUrl = "first_photo_url"
            case photoUrl = "photo_url"
            case photoPath = "photo_path"
            case voiceMemoUrl = "voice_memo_url"
        }
    }

    private struct AcceptInviteResponse: Decodable {
        let coupleId: String
        let inviterName: String
        let partnerHadPrelude: Bool
        let inviterGiftCaptures: [BackendCaptureDTO]
        let partnerGiftCaptures: [BackendCaptureDTO]

        enum CodingKeys: String, CodingKey {
            case coupleId = "couple_id"
            case inviterName = "inviter_name"
            case partnerHadPrelude = "partner_had_prelude"
            case inviterGiftCaptures = "inviter_gift_captures"
            case partnerGiftCaptures = "partner_gift_captures"
        }
    }

    private func mapCaptureType(_ raw: String) -> PreludeCapture.CaptureType? {
        switch raw {
        case "voice_memo": return .voiceMemo
        default: return PreludeCapture.CaptureType(rawValue: raw)
        }
    }

    private func photoURL(from dto: BackendCaptureDTO, type: PreludeCapture.CaptureType) -> String? {
        switch type {
        case .first:
            return dto.firstPhotoUrl ?? dto.notePhotoUrl ?? dto.photoUrl
        case .note:
            return dto.notePhotoUrl ?? dto.photoUrl
        default:
            return nil
        }
    }

    private func permanentPhotoPath(from dto: BackendCaptureDTO) -> String? {
        CovelaMediaPath.normalizePermanentPath(dto.photoPath)
            ?? CovelaMediaPath.normalizePermanentPath(dto.notePhotoUrl)
            ?? CovelaMediaPath.normalizePermanentPath(dto.firstPhotoUrl)
            ?? CovelaMediaPath.normalizePermanentPath(dto.photoUrl)
    }

    private func mapToGiftRevealCapture(_ dto: BackendCaptureDTO) -> GiftRevealCapture? {
        guard let type = mapCaptureType(dto.type) else { return nil }
        let placeholder = PreludeCapture(
            type: type,
            noteText: dto.noteText,
            firstLabel: dto.firstLabel,
            reasonText: dto.reasonText
        )
        return GiftRevealCapture(
            id: dto.id.deterministicUUID,
            type: type,
            typeIcon: placeholder.typeIcon,
            noteText: dto.noteText,
            firstLabel: dto.firstLabel,
            reasonText: dto.reasonText,
            photoPath: permanentPhotoPath(from: dto),
            photoURL: photoURL(from: dto, type: type),
            audioURL: dto.voiceMemoUrl,
            serverId: dto.id
        )
    }

    func acceptInvite(code: String) async throws -> InviteAcceptedResponse {
        guard let token = await AuthService.shared.authToken else {
            throw CovelaAPIError.unauthorized
        }
        let response: AcceptInviteResponse = try await client.post(
            path: "accept-invite",
            body: ["code": code],
            token: token
        )
        let captures = response.inviterGiftCaptures.compactMap(mapToGiftRevealCapture)
        return InviteAcceptedResponse(revealCaptures: captures, revealerName: response.inviterName)
    }

    private struct PairingStatusDTO: Decodable {
        let paired: Bool
        let partnerName: String?
        let relationshipStage: String?
        let inviteSent: Bool?

        enum CodingKeys: String, CodingKey {
            case paired
            case partnerName = "partner_name"
            case relationshipStage = "relationship_stage"
            case inviteSent = "invite_sent"
        }
    }

    func checkPairingStatus() async throws -> PairingStatusResponse {
        guard let token = await AuthService.shared.authToken else {
            throw CovelaAPIError.unauthorized
        }
        let response: PairingStatusDTO = try await client.get(path: "pairing-status", token: token)
        return PairingStatusResponse(
            paired: response.paired,
            partnerName: response.partnerName,
            relationshipStage: response.relationshipStage.flatMap(RelationshipStage.init(rawValue:)),
            inviteSent: response.inviteSent ?? false
        )
    }
}

// MARK: - Dependency injection

enum InviteAPI {
    static var client: InviteAPIClientProtocol = makeDefaultClient()

    private static func makeDefaultClient() -> InviteAPIClientProtocol {
        #if DEBUG
        if ProcessInfo.processInfo.environment["USE_STUB_INVITE_API"] == "1" {
            return StubInviteAPIClient.shared
        }
        #endif
        return LiveInviteAPIClient()
    }
}

// MARK: - Stub (offline UI work — enable with env var USE_STUB_INVITE_API=1)

final class StubInviteAPIClient: InviteAPIClientProtocol {
    static let shared = StubInviteAPIClient()
    private init() {}

    func createInvite(inviterName: String, giftCaptureIds: [String]) async throws -> InviteCreatedResponse {
        try await Task.sleep(nanoseconds: 600_000_000)
        let code = PartnerInvite.generateCode()
        let encodedName = inviterName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? inviterName
        return InviteCreatedResponse(
            code: code,
            link: "https://covela.app/invite/\(code)?from=\(encodedName)"
        )
    }

    func sendInviteEmail(partnerEmail: String, inviterName: String, code: String) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    func checkInviteStatus(code: String) async throws -> InviteStatusResponse {
        return InviteStatusResponse(valid: true, status: .pending, inviterName: "Your partner", existingUser: false)
    }

    func acceptInvite(code: String) async throws -> InviteAcceptedResponse {
        try await Task.sleep(nanoseconds: 600_000_000)
        return InviteAcceptedResponse(revealCaptures: [], revealerName: "Your partner")
    }

    func checkPairingStatus() async throws -> PairingStatusResponse {
        PairingStatusResponse(paired: false, partnerName: nil, relationshipStage: nil, inviteSent: false)
    }
}

// MARK: - Deterministic UUID helper

private extension String {
    /// Deterministic UUID derived from an arbitrary identifier string (e.g. a Mongo ObjectId),
    /// so server ids can be used as SwiftUI `Identifiable` ids across app launches.
    var deterministicUUID: UUID {
        let digest = Insecure.MD5.hash(data: Data(self.utf8))
        let bytes = Array(digest)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
