import Foundation

// Memory canvas notes and photo stickers (BAB-68, server BAB-146).
//
// - A memory canvas is identified by its anchor moment, so the canvas id on the server
//   is the anchor moment's id. Each partner writes only their own handwritten note; the
//   server merges per author, so two notes written at the same time both survive.
// - Stickers are moment cutouts placed on the garden or on a memory canvas. They live in
//   `/couple/profile-stickers` (`canvas_type` garden or memory, `canvas_ref_id` = canvas).
//   Avatar stickers are not synced: which avatar sits where depends on whose phone it is.
// - Only canvases and stickers that point at a synced moment are synced (founding and
//   first-memory photos stay local, so their stickers do too).

@MainActor
private enum SyncedMoments {
    /// Local ids of moments that sync (not founding moments).
    static func ids(_ dpm: DataPersistenceManager) -> Set<UUID> {
        Set(dpm.loadMoments().filter { !HomeViewModel.isFoundingMoment($0) }.map(\.id))
    }

    /// The local moment for a server moment id, if this phone has it.
    static func localId(forObjectId objectId: String, in ids: Set<UUID>) -> UUID? {
        ids.first { SyncIDCodec.matches($0, objectId: objectId) }
    }

    static func anchorId(ofCanvasKey key: String) -> UUID? {
        guard key.hasPrefix("memory_") else { return nil }
        return UUID(uuidString: String(key.dropFirst("memory_".count)))
    }
}

// MARK: - Canvas notes

@MainActor
final class MemoryCanvasSyncResource: CoupleSyncCollection {
    let key = "memory-canvases"
    let path = "couple/memory-canvases"

    private let dpm: DataPersistenceManager

    init(dpm: DataPersistenceManager = .shared) {
        self.dpm = dpm
    }

    private static func noteBody(text: String, position: NormalizedPoint?, mood: String?) -> [String: Any] {
        SyncJSON.compacted([
            "content": text,
            "x": position.map { Double($0.x) },
            "y": position.map { Double($0.y) },
            "mood": mood,
        ])
    }

    private static func noteBody(_ note: MemoryPageNote?) -> [String: Any]? {
        guard let note, note.hasContent else { return nil }
        return noteBody(text: note.text, position: note.position, mood: note.mood?.rawValue)
    }

    func localRecords() -> [String: [String: Any]] {
        let synced = SyncedMoments.ids(dpm)
        var records: [String: [String: Any]] = [:]
        for (key, canvas) in dpm.loadMemoryCanvases() {
            guard let anchor = SyncedMoments.anchorId(ofCanvasKey: key), synced.contains(anchor) else { continue }
            // Only this user's note is written by the server from this body. The partner's
            // is included so a change to it counts as a change and gets applied.
            records[SyncIDCodec.objectId(for: anchor)] = SyncJSON.compacted([
                "handwritten_notes": [Self.noteBody(canvas.localUserNote)].compactMap { $0 },
                "partner_note": Self.noteBody(canvas.partnerNote),
            ])
        }
        return records
    }

    private func notes(from dto: [String: Any]) -> (own: [String: Any]?, partner: [String: Any]?) {
        let ownUserId = AuthService.shared.currentUser?.id.lowercased()
        var own: [String: Any]?
        var partner: [String: Any]?
        for raw in dto["handwritten_notes"] as? [[String: Any]] ?? [] {
            let text = raw["content"] as? String ?? ""
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            var position: NormalizedPoint?
            if let x = SyncJSON.double(raw["x"]), let y = SyncJSON.double(raw["y"]) {
                position = NormalizedPoint(x: CGFloat(x), y: CGFloat(y))
            }
            let body = Self.noteBody(text: text, position: position, mood: raw["mood"] as? String)
            if (raw["author_id"] as? String)?.lowercased() == ownUserId {
                own = body
            } else {
                partner = body
            }
        }
        return (own, partner)
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? {
        let notes = notes(from: dto)
        return SyncJSON.compacted([
            "handwritten_notes": [notes.own].compactMap { $0 },
            "partner_note": notes.partner,
        ])
    }

    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {
        let synced = SyncedMoments.ids(dpm)
        var canvases = dpm.loadMemoryCanvases()
        for recordId in deletedIds {
            guard let anchor = SyncedMoments.localId(forObjectId: recordId, in: synced) else { continue }
            canvases.removeValue(forKey: MemoryCanvas.memoryKey(anchorMomentId: anchor))
        }
        for dto in upserts {
            guard let recordId = (dto["id"] as? String)?.lowercased(),
                  let anchor = SyncedMoments.localId(forObjectId: recordId, in: synced) else { continue }
            let key = MemoryCanvas.memoryKey(anchorMomentId: anchor)
            var canvas = canvases[key] ?? MemoryCanvas(memoryKey: key)
            let notes = notes(from: dto)
            canvas.notes = [
                Self.note(.localUser, from: notes.own),
                Self.note(.partner, from: notes.partner),
            ].compactMap { $0 }
            canvases[key] = canvas
        }
        dpm.saveMemoryCanvases(Array(canvases.values))
    }

    private static func note(_ author: MemoryNoteAuthor, from body: [String: Any]?) -> MemoryPageNote? {
        guard let body, let text = body["content"] as? String else { return nil }
        var position: NormalizedPoint?
        if let x = SyncJSON.double(body["x"]), let y = SyncJSON.double(body["y"]) {
            position = NormalizedPoint(x: CGFloat(x), y: CGFloat(y))
        }
        return MemoryPageNote(
            author: author,
            text: text,
            position: position,
            mood: (body["mood"] as? String).flatMap(ProfileNoteMood.init(rawValue:))
        )
    }
}

// MARK: - Stickers

@MainActor
final class StickersSyncResource: CoupleSyncCollection, CoupleSyncMediaHandling {
    let key = "profile-stickers"
    let path = "couple/profile-stickers"

    private let dpm: DataPersistenceManager
    private let registry: SyncMediaRegistry
    private var signedImageURLs: [String: String] = [:]

    init(dpm: DataPersistenceManager = .shared, registry: SyncMediaRegistry = .shared) {
        self.dpm = dpm
        self.registry = registry
    }

    private static func imageKey(_ recordId: String) -> String { "sticker.\(recordId)" }
    private static func wantedImageKey(_ recordId: String) -> String { "sticker.\(recordId).wanted" }

    /// A local sticker and where it sits.
    private struct Placed {
        let sticker: ProfileSticker
        /// `nil` for the garden; the anchor moment for a memory canvas.
        let canvasAnchor: UUID?
    }

    private func syncedStickers() -> [Placed] {
        let synced = SyncedMoments.ids(dpm)
        func eligible(_ sticker: ProfileSticker) -> Bool {
            sticker.kind == .moment && UUID(uuidString: sticker.sourceKey).map(synced.contains) == true
        }
        var placed = dpm.loadCoupleProfile().stickers.filter(eligible).map { Placed(sticker: $0, canvasAnchor: nil) }
        for (key, canvas) in dpm.loadMemoryCanvases() {
            guard let anchor = SyncedMoments.anchorId(ofCanvasKey: key), synced.contains(anchor) else { continue }
            placed += canvas.stickers.filter(eligible).map { Placed(sticker: $0, canvasAnchor: anchor) }
        }
        return placed
    }

    private static func body(
        canvasAnchor: String?,
        kind: String,
        imagePath: String,
        position: NormalizedPoint,
        scale: Double,
        rotation: Double,
        sourceMoment: String?,
        usedSubjectLift: Bool
    ) -> [String: Any] {
        SyncJSON.compacted([
            "canvas_type": canvasAnchor == nil ? "garden" : "memory",
            "canvas_ref_id": canvasAnchor,
            "sticker_type": kind,
            "image_path": imagePath,
            "x": Double(position.x),
            "y": Double(position.y),
            "scale": scale,
            "rotation": rotation,
            "source_moment_id": sourceMoment,
            "used_subject_lift": usedSubjectLift,
        ])
    }

    func localRecords() -> [String: [String: Any]] {
        var records: [String: [String: Any]] = [:]
        for placed in syncedStickers() {
            let sticker = placed.sticker
            let recordId = SyncIDCodec.objectId(for: sticker.id)
            // Not synced until its cutout has uploaded; once uploaded it never drops out.
            guard let imagePath = registry.entry(for: Self.imageKey(recordId))?.remotePath else { continue }
            records[recordId] = Self.body(
                canvasAnchor: placed.canvasAnchor.map(SyncIDCodec.objectId(for:)),
                kind: sticker.kind.rawValue,
                imagePath: imagePath,
                position: sticker.position,
                scale: Double(sticker.scale),
                rotation: sticker.rotation,
                sourceMoment: UUID(uuidString: sticker.sourceKey).map(SyncIDCodec.objectId(for:)),
                usedSubjectLift: sticker.usedSubjectLift
            )
        }
        return records
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? {
        guard let imagePath = dto["image_path"] as? String,
              let x = SyncJSON.double(dto["x"]), let y = SyncJSON.double(dto["y"]) else { return nil }
        let isMemory = (dto["canvas_type"] as? String) == "memory"
        return Self.body(
            canvasAnchor: isMemory ? (dto["canvas_ref_id"] as? String)?.lowercased() : nil,
            kind: dto["sticker_type"] as? String ?? ProfileSticker.Kind.moment.rawValue,
            imagePath: imagePath,
            position: NormalizedPoint(x: CGFloat(x), y: CGFloat(y)),
            scale: SyncJSON.double(dto["scale"]) ?? 1,
            rotation: SyncJSON.double(dto["rotation"]) ?? 0,
            sourceMoment: (dto["source_moment_id"] as? String)?.lowercased(),
            usedSubjectLift: SyncJSON.bool(dto["used_subject_lift"]) ?? false
        )
    }

    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {
        let synced = SyncedMoments.ids(dpm)
        var profile = dpm.loadCoupleProfile()
        var canvases = dpm.loadMemoryCanvases()
        let deleted = Set(deletedIds)

        func isDeleted(_ sticker: ProfileSticker) -> Bool {
            deleted.contains(SyncIDCodec.objectId(for: sticker.id))
        }
        for sticker in profile.stickers where isDeleted(sticker) { dpm.deleteStickerImage(id: sticker.id) }
        profile.stickers.removeAll(where: isDeleted)
        for key in canvases.keys {
            canvases[key]?.stickers.removeAll(where: isDeleted)
        }

        for dto in upserts {
            guard let recordId = (dto["id"] as? String)?.lowercased(),
                  let sourceObjectId = (dto["source_moment_id"] as? String)?.lowercased(),
                  let source = SyncedMoments.localId(forObjectId: sourceObjectId, in: synced),
                  let x = SyncJSON.double(dto["x"]), let y = SyncJSON.double(dto["y"]) else { continue }

            // Remove it wherever it was (it may have moved), then place it.
            let existing = profile.stickers.first { SyncIDCodec.matches($0.id, objectId: recordId) }
                ?? canvases.values.flatMap(\.stickers).first { SyncIDCodec.matches($0.id, objectId: recordId) }
            guard let stickerId = existing?.id ?? SyncIDCodec.uuid(forObjectId: recordId) else { continue }
            profile.stickers.removeAll { $0.id == stickerId }
            for key in canvases.keys { canvases[key]?.stickers.removeAll { $0.id == stickerId } }

            let sticker = ProfileSticker(
                id: stickerId,
                kind: ProfileSticker.Kind(rawValue: dto["sticker_type"] as? String ?? "") ?? .moment,
                sourceKey: source.uuidString,
                position: NormalizedPoint(x: CGFloat(x), y: CGFloat(y)),
                rotation: SyncJSON.double(dto["rotation"]) ?? 0,
                scale: CGFloat(SyncJSON.double(dto["scale"]) ?? 1),
                usedSubjectLift: SyncJSON.bool(dto["used_subject_lift"]) ?? false
            )
            if (dto["canvas_type"] as? String) == "memory" {
                guard let canvasObjectId = (dto["canvas_ref_id"] as? String)?.lowercased(),
                      let anchor = SyncedMoments.localId(forObjectId: canvasObjectId, in: synced) else { continue }
                let key = MemoryCanvas.memoryKey(anchorMomentId: anchor)
                var canvas = canvases[key] ?? MemoryCanvas(memoryKey: key)
                canvas.stickers.append(sticker)
                canvases[key] = canvas
            } else {
                profile.stickers.append(sticker)
            }

            if let imagePath = dto["image_path"] as? String, !imagePath.isEmpty,
               registry.entry(for: Self.imageKey(recordId))?.remotePath != imagePath {
                registry.record(key: Self.wantedImageKey(recordId), remotePath: imagePath, fingerprint: nil)
                if let url = dto["image_url"] as? String { signedImageURLs[recordId] = url }
            }
        }

        dpm.saveMemoryCanvases(Array(canvases.values))
        dpm.saveCoupleProfile(profile)
    }

    // MARK: Media

    func uploadPendingMedia() async throws {
        for placed in syncedStickers() {
            let recordId = SyncIDCodec.objectId(for: placed.sticker.id)
            let fileURL = dpm.stickerImageFileURL(id: placed.sticker.id)
            guard registry.entry(for: Self.imageKey(recordId)) == nil,
                  let data = try? Data(contentsOf: fileURL) else { continue }
            do {
                let path = try await SyncMediaTransfer.uploadPNG(data, filename: "sticker.png")
                registry.record(
                    key: Self.imageKey(recordId),
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
        for placed in syncedStickers() {
            let recordId = SyncIDCodec.objectId(for: placed.sticker.id)
            guard let wanted = registry.entry(for: Self.wantedImageKey(recordId))?.remotePath,
                  registry.entry(for: Self.imageKey(recordId))?.remotePath != wanted else { continue }
            let signedURL = signedImageURLs.removeValue(forKey: recordId)
            guard let data = await SyncMediaTransfer.download(signedURL: signedURL, path: wanted) else { continue }
            dpm.saveStickerImageData(data, id: placed.sticker.id)
            registry.record(
                key: Self.imageKey(recordId),
                remotePath: wanted,
                fingerprint: SyncMediaRegistry.fingerprint(of: data),
                fileStamp: SyncMediaRegistry.fileStamp(at: dpm.stickerImageFileURL(id: placed.sticker.id))
            )
            wroteAny = true
        }
        return wroteAny
    }
}
