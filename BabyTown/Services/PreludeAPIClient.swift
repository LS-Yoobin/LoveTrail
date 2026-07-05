import Foundation

enum PreludeAPIError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Please sign in to sync your captures."
        }
    }
}

/// Syncs local `PreludeCapture`s with the Covela backend. MVP scope is text-only —
/// voice memo and photo uploads stay local until a media upload endpoint exists.
final class PreludeAPIClient {
    static let shared = PreludeAPIClient()

    private let client: CovelaAPIClient

    init(client: CovelaAPIClient = .shared) {
        self.client = client
    }

    private struct CaptureIdResponse: Decodable {
        let id: String
    }

    private struct OKResponse: Decodable {
        let ok: Bool
    }

    private func requireToken() async throws -> String {
        guard let token = await AuthService.shared.authToken else {
            throw PreludeAPIError.notSignedIn
        }
        return token
    }

    private func body(for capture: PreludeCapture) -> [String: Any] {
        var body: [String: Any] = [
            "capture_type": capture.type.rawValue,
            "is_gift_included": capture.isIncludedInGift
        ]
        if let noteText = capture.noteText { body["text"] = noteText }
        if let noteMood = capture.noteMood { body["mood"] = noteMood.rawValue }
        if let firstLabel = capture.firstLabel { body["first_label"] = firstLabel }
        if let firstDate = capture.firstDate {
            body["milestoneDate"] = ISO8601DateFormatter().string(from: firstDate)
        }
        if let reasonText = capture.reasonText { body["reason_text"] = reasonText }
        return body
    }

    /// Creates the capture on the server, returning its server id.
    func createCapture(_ capture: PreludeCapture) async throws -> String {
        let token = try await requireToken()
        let response: CaptureIdResponse = try await client.post(
            path: "prelude/captures",
            body: body(for: capture),
            token: token
        )
        return response.id
    }

    /// Pushes the current field values for an already-synced capture.
    func updateCapture(serverId: String, capture: PreludeCapture) async throws {
        let token = try await requireToken()
        let _: CaptureIdResponse = try await client.patch(
            path: "prelude/captures/\(serverId)",
            body: body(for: capture),
            token: token
        )
    }

    func updateGiftInclusion(serverId: String, isIncluded: Bool) async throws {
        let token = try await requireToken()
        let _: CaptureIdResponse = try await client.patch(
            path: "prelude/captures/\(serverId)",
            body: ["is_gift_included": isIncluded],
            token: token
        )
    }

    func deleteCapture(serverId: String) async throws {
        let token = try await requireToken()
        let _: OKResponse = try await client.delete(path: "prelude/captures/\(serverId)", token: token)
    }

    /// Uploads any captures missing a `serverId`, returning the array with server ids filled in.
    /// Used right before `create-invite` so `gift_capture_ids` are always valid.
    func syncAllCaptures(_ captures: [PreludeCapture]) async throws -> [PreludeCapture] {
        var updated = captures
        for index in updated.indices where updated[index].serverId == nil {
            let id = try await createCapture(updated[index])
            updated[index].serverId = id
        }
        return updated
    }
}
