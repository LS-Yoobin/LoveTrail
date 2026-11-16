import Foundation

/// Developing polaroids ↔ `/couple/polaroids` (BAB-67, server BAB-143).
///
/// This user's polaroids upload while they develop, with their 9 PM Pacific reveal
/// time. At that time the server turns each one into a Moment with the same id and
/// tells the partner's phone, even if this phone's app is closed. The server shows
/// undeveloped polaroids only to their author, so the partner never sees them early
/// (no teaser, by decision).
///
/// The app's own reveal (`PolaroidReveal`) and the 9 PM background refresh still run as
/// fallbacks; the server and the Moments resource avoid duplicates (same id).
///
/// A polaroid stays in the synced set after it is revealed, so the engine never sends a
/// delete for it; `is_developed` mirrors a local (or early) reveal.
@MainActor
final class PolaroidsSyncResource: CoupleSyncCollection, CoupleSyncMediaHandling {
    let key = "polaroids"
    let path = "couple/polaroids"

    private let registry: SyncMediaRegistry

    init(registry: SyncMediaRegistry = .shared) {
        self.registry = registry
    }

    private enum Media: String, CaseIterable {
        case image, video, vibe
    }

    private static func mediaKey(_ recordId: String, _ media: Media) -> String {
        "polaroid.\(recordId).\(media.rawValue)"
    }

    private static func fileURL(_ entry: PolaroidEntry, _ media: Media) -> URL? {
        switch media {
        case .image: return LocalPolaroidStore.imageFileURL(for: entry)
        case .video: return LocalPolaroidStore.videoFileURL(for: entry)
        case .vibe: return LocalPolaroidStore.vibeFileURL(for: entry)
        }
    }

    /// The uploaded path for a polaroid file. Once uploaded, the path is kept even if the
    /// file's metadata changes, so a polaroid never drops out of the synced set.
    private func uploadedPath(_ recordId: String, _ media: Media) -> String? {
        registry.entry(for: Self.mediaKey(recordId, media))?.remotePath
    }

    private static func revealTime(for entry: PolaroidEntry, known: [UUID: Date]) -> Date {
        if let time = known[entry.id] { return time }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let ninePM = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: entry.capturedAt)!
        return entry.capturedAt > ninePM ? calendar.date(byAdding: .day, value: 1, to: ninePM)! : ninePM
    }

    // MARK: Collection

    func localRecords() -> [String: [String: Any]] {
        let revealTimes = LocalPolaroidStore.storedRevealTimes()
        var records: [String: [String: Any]] = [:]
        for entry in LocalPolaroidStore.storedEntries() {
            let recordId = SyncIDCodec.objectId(for: entry.id)
            // Not synced until its photo has uploaded (the server needs something to reveal).
            guard let imagePath = uploadedPath(recordId, .image) else { continue }
            var body: [String: Any?] = [
                "image_path": imagePath,
                "short_video_path": uploadedPath(recordId, .video),
                "vibe_audio_path": uploadedPath(recordId, .vibe),
                "captured_at": SyncJSON.string(from: entry.capturedAt),
                "reveal_at": SyncJSON.string(from: Self.revealTime(for: entry, known: revealTimes)),
                "place_name": entry.placeName,
                "is_developed": entry.released,
            ]
            if let latitude = entry.latitude, let longitude = entry.longitude {
                body["coordinates"] = ["latitude": latitude, "longitude": longitude]
            }
            records[recordId] = SyncJSON.compacted(body)
        }
        return records
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? {
        // Only this user's polaroids matter here. The partner's arrive as Moments.
        guard let author = (dto["author_id"] as? String)?.lowercased(),
              author == AuthService.shared.currentUser?.id.lowercased() else { return nil }
        var body: [String: Any?] = [
            "image_path": dto["image_path"] as? String,
            "short_video_path": dto["short_video_path"] as? String,
            "vibe_audio_path": dto["vibe_audio_path"] as? String,
            "captured_at": SyncJSON.date(from: dto["captured_at"]).map(SyncJSON.string(from:)),
            "reveal_at": SyncJSON.date(from: dto["reveal_at"]).map(SyncJSON.string(from:)),
            "place_name": dto["place_name"] as? String,
            "is_developed": SyncJSON.bool(dto["is_developed"]) ?? false,
        ]
        if let coordinates = dto["coordinates"] as? [String: Any],
           let latitude = SyncJSON.double(coordinates["latitude"]),
           let longitude = SyncJSON.double(coordinates["longitude"]) {
            body["coordinates"] = ["latitude": latitude, "longitude": longitude]
        }
        return SyncJSON.compacted(body)
    }

    /// Nothing to apply: this phone is the source of its own polaroids, and the server's
    /// reveal reaches this phone as a Moment. (A server reveal does not mark the local
    /// polaroid released; the app's own 9 PM check does that and finds the Moment.)
    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {}

    // MARK: Media

    func uploadPendingMedia() async throws {
        for entry in LocalPolaroidStore.storedEntries() {
            let recordId = SyncIDCodec.objectId(for: entry.id)
            for media in Media.allCases {
                guard uploadedPath(recordId, media) == nil,
                      let url = Self.fileURL(entry, media),
                      let data = try? Data(contentsOf: url) else { continue }
                do {
                    let path: String
                    switch media {
                    case .image: path = try await SyncMediaTransfer.uploadJPEG(data, filename: "polaroid.jpg")
                    case .video:
                        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                        path = try await SyncMediaTransfer.uploadVideo(data, filename: "polaroid.\(ext)")
                    case .vibe: path = try await SyncMediaTransfer.uploadAudio(data, filename: "vibe.m4a")
                    }
                    registry.record(
                        key: Self.mediaKey(recordId, media),
                        remotePath: path,
                        fingerprint: SyncMediaRegistry.fingerprint(of: data),
                        fileStamp: SyncMediaRegistry.fileStamp(at: url)
                    )
                } catch SyncMediaTransfer.TransferError.rejected {
                    continue
                }
            }
        }
    }

    func downloadPendingMedia() async -> Bool { false }
}
