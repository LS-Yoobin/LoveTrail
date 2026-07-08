import Foundation

enum PreludeAPIError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Please sign in to sync your captures."
        }
    }
}

/// Syncs local `PreludeCapture`s with the Covela backend, including uploading any
/// attached photo/voice memo to ls-file-server (covela-fs) on first sync.
final class PreludeAPIClient {
    static let shared = PreludeAPIClient()

    private let client: CovelaAPIClient
    private let mediaUploader: CovelaMediaUploadClient

    init(client: CovelaAPIClient = .shared, mediaUploader: CovelaMediaUploadClient = .shared) {
        self.client = client
        self.mediaUploader = mediaUploader
    }

    private struct CaptureIdResponse: Decodable {
        let id: String
    }

    private struct OKResponse: Decodable {
        let ok: Bool
    }

    struct ServerCaptureSummary: Decodable {
        let id: String
        let photo_path: String?
    }

    private struct ListCapturesResponse: Decodable {
        let captures: [ServerCaptureSummary]
    }

    private func requireToken() async throws -> String {
        guard let token = await AuthService.shared.authToken else {
            throw PreludeAPIError.notSignedIn
        }
        return token
    }

    /// Uploads the capture's local photo/voice memo (if any, and not already uploaded)
    /// to covela-fs, filling in `remotePhotoPath`/`remoteVoiceMemoPath`. A capture whose
    /// photo/voice attachment hasn't changed since the last sync is left alone.
    private func uploadMediaIfNeeded(_ capture: inout PreludeCapture) async throws {
        let dpm = DataPersistenceManager.shared
        let tag = "[PreludeAPIClient] capture=\(capture.id) type=\(capture.type.rawValue)"

        if capture.remotePhotoPath == nil {
            let localPhotoId: UUID? = capture.type == .note ? capture.notePhotoId : capture.firstPhotoId
            if let photoId = localPhotoId {
                if let image = dpm.loadPreludePhoto(photoId: photoId) {
                    print("\(tag) photoId=\(photoId) — loaded local photo, uploading…")
                    capture.remotePhotoPath = try await mediaUploader.uploadPhoto(image, filename: "\(photoId.uuidString).jpg")
                    print("\(tag) photoId=\(photoId) — upload succeeded, remotePhotoPath=\(capture.remotePhotoPath ?? "nil")")
                } else {
                    print("\(tag) photoId=\(photoId) — SKIPPING upload, local photo file could not be loaded (capture will sync WITHOUT a photo)")
                }
            } else {
                print("\(tag) — no local photoId set, nothing to upload")
            }
        } else {
            print("\(tag) — remotePhotoPath already set (\(capture.remotePhotoPath!)), skipping re-upload")
        }

        if capture.remoteVoiceMemoPath == nil, capture.type == .voiceMemo {
            if let fileId = capture.voiceMemoFileId {
                if let audioData = dpm.loadPreludeVoiceMemoData(fileId: fileId) {
                    print("\(tag) fileId=\(fileId) — loaded local voice memo, uploading…")
                    capture.remoteVoiceMemoPath = try await mediaUploader.uploadVoiceMemo(audioData, filename: fileId)
                    print("\(tag) fileId=\(fileId) — upload succeeded, remoteVoiceMemoPath=\(capture.remoteVoiceMemoPath ?? "nil")")
                } else {
                    print("\(tag) fileId=\(fileId) — SKIPPING upload, local voice memo data could not be loaded")
                }
            } else {
                print("\(tag) — no local voiceMemoFileId set, nothing to upload")
            }
        }
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
        if let photoPath = capture.remotePhotoPath { body["photo_path"] = photoPath }
        if let voicePath = capture.remoteVoiceMemoPath { body["voice_memo_url"] = voicePath }
        return body
    }

    /// Creates the capture on the server, uploading any attached media first.
    /// Returns the capture with `serverId` and any `remotePhotoPath`/`remoteVoiceMemoPath` filled in.
    func createCapture(_ capture: PreludeCapture) async throws -> PreludeCapture {
        var capture = capture
        try await uploadMediaIfNeeded(&capture)
        let token = try await requireToken()
        print("[PreludeAPIClient] createCapture \(capture.id) — POSTing with remotePhotoPath=\(capture.remotePhotoPath ?? "nil") remoteVoiceMemoPath=\(capture.remoteVoiceMemoPath ?? "nil")")
        let response: CaptureIdResponse = try await client.post(
            path: "prelude/captures",
            body: body(for: capture),
            token: token
        )
        capture.serverId = response.id
        print("[PreludeAPIClient] createCapture \(capture.id) — server assigned serverId=\(response.id)")
        return capture
    }

    /// Pushes the current field values for an already-synced capture, uploading any
    /// newly-attached media first. Returns the capture with remote media paths filled in.
    func updateCapture(_ capture: PreludeCapture) async throws -> PreludeCapture {
        guard let serverId = capture.serverId else {
            return try await createCapture(capture)
        }
        var capture = capture
        try await uploadMediaIfNeeded(&capture)
        let token = try await requireToken()
        print("[PreludeAPIClient] updateCapture \(capture.id) serverId=\(serverId) — PATCHing with remotePhotoPath=\(capture.remotePhotoPath ?? "nil") remoteVoiceMemoPath=\(capture.remoteVoiceMemoPath ?? "nil")")
        let _: CaptureIdResponse = try await client.patch(
            path: "prelude/captures/\(serverId)",
            body: body(for: capture),
            token: token
        )
        return capture
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

    /// True if this capture has a local photo/voice memo attached that hasn't made it to
    /// covela-fs yet — e.g. a previous sync created the capture but its media upload failed.
    private func hasPendingMediaUpload(_ capture: PreludeCapture) -> Bool {
        if capture.remotePhotoPath == nil {
            let localPhotoId: UUID? = capture.type == .note ? capture.notePhotoId : capture.firstPhotoId
            if localPhotoId != nil { return true }
        }
        if capture.remoteVoiceMemoPath == nil, capture.type == .voiceMemo, capture.voiceMemoFileId != nil {
            return true
        }
        return false
    }

    /// Fetches the signed-in user's captures from the server (used to backfill `remotePhotoPath`).
    func listOwnCaptureSummaries() async throws -> [ServerCaptureSummary] {
        let token = try await requireToken()
        let response: ListCapturesResponse = try await client.get(path: "prelude/captures", token: token)
        return response.captures
    }

    /// Uploads any captures missing a `serverId` or still missing an attached media upload,
    /// returning the array with server ids and media paths filled in. Used right before
    /// `create-invite` so `gift_capture_ids` are always valid and their media is uploaded.
    /// `onProgress` reports (completed, total) as each pending capture finishes.
    func syncAllCaptures(_ captures: [PreludeCapture], onProgress: ((Int, Int) -> Void)? = nil) async throws -> [PreludeCapture] {
        var updated = captures
        let pendingIndices = updated.indices.filter { updated[$0].serverId == nil || hasPendingMediaUpload(updated[$0]) }
        let total = pendingIndices.count
        for (completed, index) in pendingIndices.enumerated() {
            if updated[index].serverId == nil {
                updated[index] = try await createCapture(updated[index])
            } else {
                updated[index] = try await updateCapture(updated[index])
            }
            onProgress?(completed + 1, total)
        }
        return updated
    }
}
