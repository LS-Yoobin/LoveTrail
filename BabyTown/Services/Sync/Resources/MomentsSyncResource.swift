import AVFoundation
import Foundation
import UIKit

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
/// Reels sync as video (`media_type: video`, uploaded through the file server's
/// `video` field). The server keeps one media file per moment, so the partner's phone
/// makes the thumbnail from the video.
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
    /// Marks a wanted media entry as a video (stored in the entry's unused fingerprint).
    private static let wantedVideoMarker = "type:video"

    /// The file that represents this moment on the server: the reel video if there is
    /// one, otherwise the stored photo.
    private func mediaFile(for moment: Moment) -> (url: URL, type: String) {
        if let videoURL = moment.resolvedVideoURL {
            return (videoURL, "video")
        }
        return (thumbnails.url(for: moment.id), "photo")
    }
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
            let media = mediaFile(for: moment)
            var body: [String: Any?] = [
                "media_type": media.type,
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
            if let mediaPath = registry.remotePath(for: Self.mediaKey(recordId), fileAt: media.url) {
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
            "media_type": (dto["media_type"] as? String) == "video" ? "video" : "photo",
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
                let isVideo = (dto["media_type"] as? String) == "video"
                registry.record(
                    key: Self.wantedMediaKey(recordId),
                    remotePath: mediaPath,
                    fingerprint: isVideo ? Self.wantedVideoMarker : nil
                )
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
            let media = mediaFile(for: moment)
            // Cheap stat-based check first; only new or changed files are read.
            guard registry.remotePath(for: Self.mediaKey(recordId), fileAt: media.url) == nil else { continue }
            let data: Data?
            if media.type == "video" {
                data = try? Data(contentsOf: media.url)
            } else {
                data = thumbnails.fileData(for: moment.id)
            }
            guard let data else { continue }
            do {
                let path: String
                if media.type == "video" {
                    let ext = media.url.pathExtension.isEmpty ? "mov" : media.url.pathExtension
                    path = try await SyncMediaTransfer.uploadVideo(data, filename: "moment.\(ext)")
                } else {
                    path = try await SyncMediaTransfer.uploadJPEG(data, filename: "moment.jpg")
                }
                registry.record(
                    key: Self.mediaKey(recordId),
                    remotePath: path,
                    fingerprint: SyncMediaRegistry.fingerprint(of: data),
                    fileStamp: SyncMediaRegistry.fileStamp(at: media.url)
                )
            } catch SyncMediaTransfer.TransferError.rejected {
                continue
            }
        }
    }

    func downloadPendingMedia() async -> Bool {
        var wroteAny = false
        var reelIDs: [UUID] = []
        for moment in syncedMoments {
            let recordId = SyncIDCodec.objectId(for: moment.id)
            guard let wantedEntry = registry.entry(for: Self.wantedMediaKey(recordId)),
                  registry.entry(for: Self.mediaKey(recordId))?.remotePath != wantedEntry.remotePath else { continue }
            let wanted = wantedEntry.remotePath
            let signedURL = signedMediaURLs.removeValue(forKey: recordId)
            guard let data = await SyncMediaTransfer.download(signedURL: signedURL, path: wanted) else { continue }

            let storedURL: URL
            if wantedEntry.fingerprint == Self.wantedVideoMarker {
                MomentVideoStore.shared.storeDownloadedVideo(data, for: moment.id)
                storedURL = MomentVideoStore.shared.url(for: moment.id)
                if let poster = await Self.posterImage(forVideoAt: storedURL),
                   let jpeg = poster.jpegData(compressionQuality: 0.8) {
                    thumbnails.storeDownloadedJPEG(jpeg, for: moment.id)
                }
                reelIDs.append(moment.id)
            } else {
                thumbnails.storeDownloadedJPEG(data, for: moment.id)
                storedURL = thumbnails.url(for: moment.id)
            }
            registry.record(
                key: Self.mediaKey(recordId),
                remotePath: wanted,
                fingerprint: SyncMediaRegistry.fingerprint(of: data),
                fileStamp: SyncMediaRegistry.fileStamp(at: storedURL)
            )
            wroteAny = true
        }

        // Point the moments at their downloaded reels, and tell HomeViewModel right away
        // (before any further network wait) so it can't save its stale copy over this.
        if !reelIDs.isEmpty {
            var moments = dpm.loadMoments()
            for index in moments.indices where reelIDs.contains(moments[index].id) {
                moments[index].videoFileName = MomentVideoStore.shared.fileName(for: moments[index].id)
            }
            dpm.saveMoments(moments)
            NotificationCenter.default.post(
                name: .coupleSyncDidApplyRemoteChanges,
                object: nil,
                userInfo: ["resources": Set([key])]
            )
        }
        return wroteAny
    }

    /// First frame of a downloaded reel, used as its thumbnail.
    private static func posterImage(forVideoAt url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1200, height: 1200)
        guard let (cgImage, _) = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: cgImage)
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
