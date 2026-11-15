import Foundation

/// Moments (`moments.json` + `ThumbnailStore`) ↔ `/couple/moments` (BAB-67).
///
/// Synced: the photo (the stored thumbnail JPEG), date taken, place, coordinates,
/// caption, lock state and prompt.
///
/// Kept local:
/// - Pin state (each partner pins their own), Photos-library asset ids, "added from
///   On This Day", country.
/// - Founding moments ("When we first met" / "When we became official"). Each device
///   creates its own from its pinned photos and repairs duplicates by prompt, so
///   syncing them would duplicate them and then delete the partner's copy.
/// - Reel video. The upload client has no video upload yet, so reels sync as their
///   still thumbnail with `media_type: photo`.
/// - Moment voice notes (no playback reads them today).
@MainActor
final class MomentsSyncResource: CoupleSyncCollection, CoupleSyncMediaHandling {
    let key = "moments"
    let path = "couple/moments"

    private let dpm: DataPersistenceManager
    private let registry: SyncMediaRegistry
    private let thumbnails: ThumbnailStore
    private var signedMediaURLs: [String: String] = [:]

    init(
        dpm: DataPersistenceManager = .shared,
        registry: SyncMediaRegistry = .shared,
        thumbnails: ThumbnailStore = .shared
    ) {
        self.dpm = dpm
        self.registry = registry
        self.thumbnails = thumbnails
    }

    private static func mediaKey(_ recordId: String) -> String { "moment.\(recordId)" }
    private static func wantedMediaKey(_ recordId: String) -> String { "moment.\(recordId).wanted" }

    private static func isSynced(_ moment: Moment) -> Bool {
        !HomeViewModel.isFoundingMoment(moment)
    }

    private static func isFoundingPrompt(_ prompt: String?) -> Bool {
        guard let prompt else { return false }
        return HomeViewModel.foundingPrompts.contains(prompt)
    }

    private var syncedMoments: [Moment] {
        dpm.loadMoments().filter(Self.isSynced)
    }

    // MARK: Collection

    func localRecords() -> [String: [String: Any]] {
        var records: [String: [String: Any]] = [:]
        for moment in syncedMoments {
            let recordId = SyncIDCodec.objectId(for: moment.id)
            var body: [String: Any?] = [
                "media_type": "photo",
                "timestamp": SyncJSON.string(from: moment.dateTaken),
                "place_name": Self.nonEmpty(moment.placeName),
                "caption": moment.caption ?? "",
                "is_locked": moment.isLocked,
                "unlock_at": moment.unlockTime.map(SyncJSON.string(from:)),
                "prompt": Self.nonEmpty(moment.promptText),
            ]
            if let latitude = moment.latitude, let longitude = moment.longitude {
                body["coordinates"] = ["latitude": latitude, "longitude": longitude]
            }
            if let mediaPath = registry.remotePath(for: Self.mediaKey(recordId), fileAt: thumbnails.url(for: moment.id)) {
                body["media_path"] = mediaPath
            }
            records[recordId] = SyncJSON.compacted(body)
        }
        return records
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? {
        guard let timestamp = SyncJSON.date(from: dto["timestamp"]) else { return nil }
        let prompt = Self.nonEmpty(dto["prompt"] as? String)
        guard !Self.isFoundingPrompt(prompt) else { return nil }

        var body: [String: Any?] = [
            "media_type": "photo",
            "timestamp": SyncJSON.string(from: timestamp),
            "place_name": Self.nonEmpty(dto["place_name"] as? String),
            "caption": dto["caption"] as? String ?? "",
            "is_locked": SyncJSON.bool(dto["is_locked"]) ?? false,
            "unlock_at": SyncJSON.date(from: dto["unlock_at"]).map(SyncJSON.string(from:)),
            "prompt": prompt,
            "media_path": Self.nonEmpty(dto["media_path"] as? String),
        ]
        if let coordinates = Self.coordinates(from: dto) {
            body["coordinates"] = ["latitude": coordinates.latitude, "longitude": coordinates.longitude]
        }
        return SyncJSON.compacted(body)
    }

    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {
        var moments = dpm.loadMoments()
        let deleted = Set(deletedIds)
        let polaroidIDs = LocalPolaroidStore.storedEntryIDs()

        moments.removeAll { moment in
            guard Self.isSynced(moment) else { return false }
            let recordId = SyncIDCodec.objectId(for: moment.id)
            guard deleted.contains(recordId) else { return false }
            thumbnails.remove(for: moment.id)
            registry.remove(key: Self.mediaKey(recordId))
            registry.remove(key: Self.wantedMediaKey(recordId))
            return true
        }

        for dto in upserts {
            guard let recordId = (dto["id"] as? String)?.lowercased(),
                  let timestamp = SyncJSON.date(from: dto["timestamp"]) else { continue }
            let prompt = Self.nonEmpty(dto["prompt"] as? String)
            guard !Self.isFoundingPrompt(prompt) else { continue }

            let index = moments.firstIndex { SyncIDCodec.matches($0.id, objectId: recordId) }
            let existing = index.map { moments[$0] }
            // A Moment the server revealed from one of *this* user's polaroids (BAB-143)
            // keeps the polaroid's UUID, so the app's own 9 PM reveal recognises it
            // instead of adding a second copy.
            let polaroidId = polaroidIDs.first { SyncIDCodec.matches($0, objectId: recordId) }
            guard let localId = existing?.id ?? polaroidId ?? SyncIDCodec.uuid(forObjectId: recordId) else { continue }

            // `dateTaken` is immutable, so rebuild the value and carry local-only fields over.
            var moment = Moment(syncedId: localId, dateTaken: timestamp, copying: existing)
            moment.placeName = Self.nonEmpty(dto["place_name"] as? String)
            let caption = dto["caption"] as? String ?? ""
            moment.caption = caption.isEmpty ? nil : caption
            moment.isLocked = SyncJSON.bool(dto["is_locked"]) ?? false
            moment.unlockTime = SyncJSON.date(from: dto["unlock_at"])
            moment.promptText = prompt
            if let coordinates = Self.coordinates(from: dto) {
                moment.latitude = coordinates.latitude
                moment.longitude = coordinates.longitude
            } else {
                moment.latitude = nil
                moment.longitude = nil
            }
            if existing == nil {
                moment.isPlaceNameUserSet = moment.placeName != nil
            }

            if let index {
                moments[index] = moment
            } else {
                moments.append(moment)
            }

            if let mediaPath = Self.nonEmpty(dto["media_path"] as? String),
               registry.entry(for: Self.mediaKey(recordId))?.remotePath != mediaPath {
                registry.record(key: Self.wantedMediaKey(recordId), remotePath: mediaPath, fingerprint: nil)
                if let url = dto["media_url"] as? String { signedMediaURLs[recordId] = url }
            }
        }

        moments.sort { $0.dateTaken > $1.dateTaken }
        dpm.saveMoments(moments)
    }

    // MARK: Media

    func uploadPendingMedia() async throws {
        for moment in syncedMoments {
            let recordId = SyncIDCodec.objectId(for: moment.id)
            let fileURL = thumbnails.url(for: moment.id)
            // Cheap stat-based check first; only unchanged-unknown files are read.
            guard registry.remotePath(for: Self.mediaKey(recordId), fileAt: fileURL) == nil,
                  let data = thumbnails.fileData(for: moment.id) else { continue }
            let fingerprint = SyncMediaRegistry.fingerprint(of: data)
            do {
                let path = try await SyncMediaTransfer.uploadJPEG(data, filename: "moment.jpg")
                registry.record(
                    key: Self.mediaKey(recordId),
                    remotePath: path,
                    fingerprint: fingerprint,
                    fileStamp: SyncMediaRegistry.fileStamp(at: fileURL)
                )
            } catch SyncMediaTransfer.TransferError.rejected {
                continue
            }
        }
    }

    func downloadPendingMedia() async -> Bool {
        var wroteAny = false
        for moment in syncedMoments {
            let recordId = SyncIDCodec.objectId(for: moment.id)
            guard let wanted = registry.entry(for: Self.wantedMediaKey(recordId))?.remotePath,
                  registry.entry(for: Self.mediaKey(recordId))?.remotePath != wanted else { continue }
            let signedURL = signedMediaURLs.removeValue(forKey: recordId)
            guard let data = await SyncMediaTransfer.download(signedURL: signedURL, path: wanted) else { continue }
            thumbnails.storeDownloadedJPEG(data, for: moment.id)
            registry.record(
                key: Self.mediaKey(recordId),
                remotePath: wanted,
                fingerprint: SyncMediaRegistry.fingerprint(of: data),
                fileStamp: SyncMediaRegistry.fileStamp(at: thumbnails.url(for: moment.id))
            )
            wroteAny = true
        }
        return wroteAny
    }

    // MARK: Helpers

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private static func coordinates(from dto: [String: Any]) -> (latitude: Double, longitude: Double)? {
        guard let coordinates = dto["coordinates"] as? [String: Any],
              let latitude = SyncJSON.double(coordinates["latitude"]),
              let longitude = SyncJSON.double(coordinates["longitude"]) else { return nil }
        return (latitude, longitude)
    }
}
