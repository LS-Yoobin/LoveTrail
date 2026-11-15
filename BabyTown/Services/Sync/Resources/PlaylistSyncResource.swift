import Foundation

/// Couple playlist ("our songs") ↔ `/couple/playlist/tracks` (BAB-70).
///
/// Synced: each imported song's name, order and audio file (`.m4a`, uploaded as-is).
/// Kept local: the bundled default song (every install adds its own copy) and the
/// playback preferences (now playing, repeat, shuffle).
@MainActor
final class PlaylistSyncResource: CoupleSyncCollection, CoupleSyncMediaHandling {
    let key = "playlist"
    let path = "couple/playlist/tracks"

    private let registry: SyncMediaRegistry
    private var signedAudioURLs: [String: String] = [:]

    init(registry: SyncMediaRegistry = .shared) {
        self.registry = registry
    }

    private static func audioKey(_ recordId: String) -> String { "playlist.\(recordId)" }
    private static func wantedAudioKey(_ recordId: String) -> String { "playlist.\(recordId).wanted" }

    private var syncedTracks: [CouplePlaylistTrack] {
        CouplePlaylistStore.storedTracksForSync().filter { !CouplePlaylistStore.isBundledDefault($0) }
    }

    // MARK: Collection

    func localRecords() -> [String: [String: Any]] {
        var records: [String: [String: Any]] = [:]
        for track in syncedTracks {
            let recordId = SyncIDCodec.objectId(for: track.id)
            var body: [String: Any] = [
                "display_name": track.displayName,
                "sort_order": track.sortOrder,
            ]
            if let audioPath = registry.remotePath(
                for: Self.audioKey(recordId),
                fileAt: CouplePlaylistStore.audioURL(for: track)
            ) {
                body["media_path"] = audioPath
            }
            records[recordId] = body
        }
        return records
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? {
        guard let name = dto["display_name"] as? String else { return nil }
        var body: [String: Any] = [
            "display_name": name,
            "sort_order": SyncJSON.int(dto["sort_order"]) ?? 0,
        ]
        if let audioPath = dto["media_path"] as? String, !audioPath.isEmpty {
            body["media_path"] = audioPath
        }
        return body
    }

    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {
        let current = CouplePlaylistStore.storedTracksForSync()
        let deleted = Set(deletedIds)
        let removedIDs = Set(current.filter { track in
            !CouplePlaylistStore.isBundledDefault(track)
                && deleted.contains(SyncIDCodec.objectId(for: track.id))
        }.map(\.id))
        for id in removedIDs {
            let recordId = SyncIDCodec.objectId(for: id)
            registry.remove(key: Self.audioKey(recordId))
            registry.remove(key: Self.wantedAudioKey(recordId))
        }

        var incoming: [CouplePlaylistTrack] = []
        for dto in upserts {
            guard let recordId = (dto["id"] as? String)?.lowercased(),
                  let name = dto["display_name"] as? String else { continue }
            let sortOrder = SyncJSON.int(dto["sort_order"]) ?? 0
            if let existing = current.first(where: { SyncIDCodec.matches($0.id, objectId: recordId) }) {
                var updated = existing
                updated.displayName = name
                updated.sortOrder = sortOrder
                incoming.append(updated)
            } else if let localId = SyncIDCodec.uuid(forObjectId: recordId) {
                incoming.append(CouplePlaylistTrack(
                    id: localId,
                    displayName: name,
                    fileName: "\(localId.uuidString).m4a",
                    addedAt: SyncJSON.date(from: dto["created_at"]) ?? Date(),
                    sortOrder: sortOrder
                ))
            }
            if let audioPath = dto["media_path"] as? String, !audioPath.isEmpty,
               registry.entry(for: Self.audioKey(recordId))?.remotePath != audioPath {
                registry.record(key: Self.wantedAudioKey(recordId), remotePath: audioPath, fingerprint: nil)
                if let url = dto["media_url"] as? String { signedAudioURLs[recordId] = url }
            }
        }

        CouplePlaylistStore.applySynced(upserting: incoming, removing: removedIDs)
    }

    // MARK: Media

    func uploadPendingMedia() async throws {
        for track in syncedTracks {
            let recordId = SyncIDCodec.objectId(for: track.id)
            let fileURL = CouplePlaylistStore.audioURL(for: track)
            guard registry.remotePath(for: Self.audioKey(recordId), fileAt: fileURL) == nil,
                  let data = try? Data(contentsOf: fileURL) else { continue }
            do {
                let path = try await SyncMediaTransfer.uploadAudio(data, filename: "song.m4a")
                registry.record(
                    key: Self.audioKey(recordId),
                    remotePath: path,
                    fingerprint: SyncMediaRegistry.fingerprint(of: data),
                    fileStamp: SyncMediaRegistry.fileStamp(at: fileURL)
                )
            } catch SyncMediaTransfer.TransferError.rejected {
                continue
            }
        }
    }

    func downloadPendingMedia() async -> Bool {
        var wroteAny = false
        for track in syncedTracks {
            let recordId = SyncIDCodec.objectId(for: track.id)
            guard let wanted = registry.entry(for: Self.wantedAudioKey(recordId))?.remotePath,
                  registry.entry(for: Self.audioKey(recordId))?.remotePath != wanted else { continue }
            let signedURL = signedAudioURLs.removeValue(forKey: recordId)
            guard let data = await SyncMediaTransfer.download(signedURL: signedURL, path: wanted) else { continue }
            CouplePlaylistStore.storeSyncedAudio(data, for: track)
            registry.record(
                key: Self.audioKey(recordId),
                remotePath: wanted,
                fingerprint: SyncMediaRegistry.fingerprint(of: data),
                fileStamp: SyncMediaRegistry.fileStamp(at: CouplePlaylistStore.audioURL(for: track))
            )
            wroteAny = true
        }
        return wroteAny
    }
}
