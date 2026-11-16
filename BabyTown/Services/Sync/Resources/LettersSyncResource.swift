import Foundation

/// Letters ↔ `/couple/letters` (BAB-67, server BAB-142).
///
/// Letters are only ever between the two of you, so a letter is either yours or
/// `isFromPartner`. No names are shown; the mailbox uses a "new" dot for unread
/// letters from the partner and a quiet "Read" on yours once the partner opened it.
///
/// - **Your letters** (including ones written before pairing) upload with their title,
///   body, layout blocks (photos as JPEG, stickers as PNG, voice memos as m4a), writing
///   date and schedule. The server lets the writer edit only until delivery.
/// - **Partner letters** come down. Before their delivery date the server sends only the
///   date (`sealed`); the full letter arrives when it is delivered.
/// - **Read receipts:** opening a partner letter calls `POST /letters/:id/read`
///   (queued, works offline); your letters pick up the partner's `read_at`.
@MainActor
final class LettersSyncResource: CoupleSyncCollection, CoupleSyncMediaHandling, CoupleSyncTask {
    static let shared = LettersSyncResource()

    let key = "letters"
    let path = "couple/letters"

    private let dpm: DataPersistenceManager
    private let registry: SyncMediaRegistry
    private let api: CovelaAPIClient
    private var signedMediaURLs: [String: String] = [:]
    private let pendingReadsKey = "lettersPendingReads"

    init(
        dpm: DataPersistenceManager = .shared,
        registry: SyncMediaRegistry = .shared,
        api: CovelaAPIClient = .shared
    ) {
        self.dpm = dpm
        self.registry = registry
        self.api = api
    }

    private static func mediaKey(_ blockId: String) -> String { "letter-block.\(blockId)" }
    private static func wantedMediaKey(_ blockId: String) -> String { "letter-block.\(blockId).wanted" }

    private var ownUserId: String? { AuthService.shared.currentUser?.id.lowercased() }

    private func isFromPartner(_ dto: [String: Any]) -> Bool {
        guard let author = (dto["author_id"] as? String)?.lowercased(), let ownUserId else { return false }
        return author != ownUserId
    }

    // MARK: Body

    private func blockBody(_ block: LetterBlock) -> [String: Any]? {
        let blockId = SyncIDCodec.objectId(for: block.id)
        var body: [String: Any?] = ["id": blockId, "type": block.type.rawValue]
        if let fileURL = dpm.letterMediaFileURL(for: block) {
            // A block whose media hasn't uploaded yet is left out for now.
            guard let mediaPath = registry.remotePath(for: Self.mediaKey(blockId), fileAt: fileURL) else { return nil }
            body["media_path"] = mediaPath
        }
        let position: NormalizedPoint?
        switch block.type {
        case .photo:
            position = block.photoPosition
            body["rotation"] = block.photoRotation
            body["scale"] = block.photoScale.map(Double.init)
        case .sticker:
            position = block.stickerPosition
            body["rotation"] = block.stickerRotation
            body["scale"] = block.stickerScale.map(Double.init)
            body["used_subject_lift"] = block.usedSubjectLift
        case .voiceMemo:
            position = nil
        }
        if let position {
            body["position"] = ["x": Double(position.x), "y": Double(position.y)]
        }
        return SyncJSON.compacted(body)
    }

    private func letterBody(_ letter: UserLetter) -> [String: Any] {
        SyncJSON.compacted([
            "title": letter.title,
            "body": letter.body,
            "blocks": letter.blocks.compactMap(blockBody),
            "written_at": SyncJSON.string(from: letter.createdAt),
            "scheduled_delivery_date": letter.scheduledFor.map(SyncJSON.string(from:)),
            // Not written by the server from this body; included so the partner's read
            // receipt counts as a change and gets applied.
            "read_at": letter.readAt.map(SyncJSON.string(from:)),
        ])
    }

    // MARK: Collection

    func localRecords() -> [String: [String: Any]] {
        var records: [String: [String: Any]] = [:]
        for letter in dpm.loadUserLetters() where !letter.isFromPartner {
            records[SyncIDCodec.objectId(for: letter.id)] = letterBody(letter)
        }
        return records
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? {
        guard !isFromPartner(dto) else {
            // Partner letters are never pushed back; any change is applied.
            return ["received": SyncJSON.canonical(dto)]
        }
        var blocks: [[String: Any]] = []
        for raw in dto["blocks"] as? [[String: Any]] ?? [] {
            var block: [String: Any?] = [
                "id": (raw["id"] as? String)?.lowercased(),
                "type": raw["type"] as? String,
                "media_path": raw["media_path"] as? String,
                "rotation": SyncJSON.double(raw["rotation"]),
                "scale": SyncJSON.double(raw["scale"]),
                "used_subject_lift": SyncJSON.bool(raw["used_subject_lift"]),
            ]
            if let position = raw["position"] as? [String: Any],
               let x = SyncJSON.double(position["x"]), let y = SyncJSON.double(position["y"]) {
                block["position"] = ["x": x, "y": y]
            }
            blocks.append(SyncJSON.compacted(block))
        }
        return SyncJSON.compacted([
            "title": dto["title"] as? String ?? "",
            "body": dto["body"] as? String ?? "",
            "blocks": blocks,
            "written_at": SyncJSON.date(from: dto["written_at"]).map(SyncJSON.string(from:)),
            "scheduled_delivery_date": SyncJSON.date(from: dto["scheduled_delivery_date"]).map(SyncJSON.string(from:)),
            "read_at": SyncJSON.date(from: dto["read_at"]).map(SyncJSON.string(from:)),
        ])
    }

    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {
        var letters = dpm.loadUserLetters()
        let deleted = Set(deletedIds)
        letters.removeAll { letter in
            guard deleted.contains(SyncIDCodec.objectId(for: letter.id)) else { return false }
            removeMedia(of: letter)
            return true
        }

        for dto in upserts {
            guard let recordId = (dto["id"] as? String)?.lowercased() else { continue }
            let index = letters.firstIndex { SyncIDCodec.matches($0.id, objectId: recordId) }

            if !isFromPartner(dto) {
                // Our own letter: the only thing the server adds is the read receipt.
                if let index {
                    letters[index].readAt = SyncJSON.date(from: dto["read_at"])
                }
                continue
            }

            guard let letterId = index.map({ letters[$0].id }) ?? SyncIDCodec.uuid(forObjectId: recordId) else { continue }
            let received = receivedLetter(id: letterId, recordId: recordId, from: dto, existing: index.map { letters[$0] })
            if let index {
                letters[index] = received
            } else {
                letters.append(received)
            }
        }
        dpm.saveUserLetters(letters)
    }

    private func receivedLetter(id: UUID, recordId: String, from dto: [String: Any], existing: UserLetter?) -> UserLetter {
        let writtenAt = SyncJSON.date(from: dto["written_at"]) ?? Date()
        let scheduled = SyncJSON.date(from: dto["scheduled_delivery_date"])
        let sealed = (dto["sealed"] as? Bool) ?? false

        var blocks: [LetterBlock] = []
        if !sealed {
            for raw in dto["blocks"] as? [[String: Any]] ?? [] {
                guard let blockId = (raw["id"] as? String)?.lowercased(),
                      let typeRaw = raw["type"] as? String,
                      let type = LetterBlockType(rawValue: typeRaw),
                      let localBlockId = SyncIDCodec.uuid(forObjectId: blockId) else { continue }
                let position = (raw["position"] as? [String: Any]).flatMap { point -> NormalizedPoint? in
                    guard let x = SyncJSON.double(point["x"]), let y = SyncJSON.double(point["y"]) else { return nil }
                    return NormalizedPoint(x: CGFloat(x), y: CGFloat(y))
                }
                let rotation = SyncJSON.double(raw["rotation"])
                let scale = SyncJSON.double(raw["scale"]).map { CGFloat($0) }
                let block = LetterBlock(
                    id: localBlockId,
                    type: type,
                    voiceMemoFileId: type == .voiceMemo ? "\(localBlockId.uuidString).m4a" : nil,
                    photoImageId: type == .photo ? localBlockId : nil,
                    photoPosition: type == .photo ? position : nil,
                    photoRotation: type == .photo ? rotation : nil,
                    photoScale: type == .photo ? scale : nil,
                    stickerImageId: type == .sticker ? localBlockId : nil,
                    stickerPosition: type == .sticker ? position : nil,
                    stickerRotation: type == .sticker ? rotation : nil,
                    stickerScale: type == .sticker ? scale : nil,
                    usedSubjectLift: SyncJSON.bool(raw["used_subject_lift"])
                )
                blocks.append(block)
                if let mediaPath = raw["media_path"] as? String, !mediaPath.isEmpty,
                   registry.entry(for: Self.mediaKey(blockId))?.remotePath != mediaPath {
                    registry.record(key: Self.wantedMediaKey(blockId), remotePath: mediaPath, fingerprint: nil)
                    if let url = raw["media_url"] as? String { signedMediaURLs[blockId] = url }
                }
            }
        }

        var letter = UserLetter(
            id: id,
            title: sealed ? "" : (dto["title"] as? String ?? ""),
            body: sealed ? "" : (dto["body"] as? String ?? ""),
            blocks: blocks,
            createdAt: writtenAt,
            scheduledFor: scheduled,
            // Delivered letters are no longer "scheduled" in the existing UI.
            sentAt: sealed ? nil : (scheduled ?? writtenAt)
        )
        letter.isFromPartner = true
        letter.isSealed = sealed
        // Keep a local "opened" that hasn't reached the server yet.
        letter.readAt = SyncJSON.date(from: dto["read_at"]) ?? existing?.readAt
        return letter
    }

    private func removeMedia(of letter: UserLetter) {
        for block in letter.blocks {
            if let url = dpm.letterMediaFileURL(for: block) {
                try? FileManager.default.removeItem(at: url)
            }
            let blockId = SyncIDCodec.objectId(for: block.id)
            registry.remove(key: Self.mediaKey(blockId))
            registry.remove(key: Self.wantedMediaKey(blockId))
        }
    }

    // MARK: Media

    func uploadPendingMedia() async throws {
        for letter in dpm.loadUserLetters() where !letter.isFromPartner {
            for block in letter.blocks {
                let blockId = SyncIDCodec.objectId(for: block.id)
                guard let fileURL = dpm.letterMediaFileURL(for: block),
                      registry.remotePath(for: Self.mediaKey(blockId), fileAt: fileURL) == nil,
                      let data = try? Data(contentsOf: fileURL) else { continue }
                do {
                    let path: String
                    switch block.type {
                    case .photo: path = try await SyncMediaTransfer.uploadJPEG(data, filename: "letter_photo.jpg")
                    case .sticker: path = try await SyncMediaTransfer.uploadPNG(data, filename: "letter_sticker.png")
                    case .voiceMemo: path = try await SyncMediaTransfer.uploadAudio(data, filename: "letter_voice.m4a")
                    }
                    registry.record(
                        key: Self.mediaKey(blockId),
                        remotePath: path,
                        fingerprint: SyncMediaRegistry.fingerprint(of: data),
                        fileStamp: SyncMediaRegistry.fileStamp(at: fileURL)
                    )
                } catch SyncMediaTransfer.TransferError.rejected {
                    continue
                }
            }
        }
    }

    func downloadPendingMedia() async -> Bool {
        var wroteAny = false
        for letter in dpm.loadUserLetters() where letter.isFromPartner {
            for block in letter.blocks {
                let blockId = SyncIDCodec.objectId(for: block.id)
                guard let wanted = registry.entry(for: Self.wantedMediaKey(blockId))?.remotePath,
                      registry.entry(for: Self.mediaKey(blockId))?.remotePath != wanted else { continue }
                let signedURL = signedMediaURLs.removeValue(forKey: blockId)
                guard let data = await SyncMediaTransfer.download(signedURL: signedURL, path: wanted) else { continue }
                dpm.saveLetterMediaData(data, for: block)
                registry.record(
                    key: Self.mediaKey(blockId),
                    remotePath: wanted,
                    fingerprint: SyncMediaRegistry.fingerprint(of: data),
                    fileStamp: dpm.letterMediaFileURL(for: block).flatMap(SyncMediaRegistry.fileStamp(at:))
                )
                wroteAny = true
            }
        }
        return wroteAny
    }

    // MARK: Read receipts

    /// Marks a partner letter as opened: shown read at once, sent to the server with the
    /// next sync (queued, so it works offline).
    func markOpened(_ letter: UserLetter) {
        guard letter.isFromPartner, !letter.isSealed, letter.readAt == nil else { return }
        var updated = letter
        updated.readAt = Date()
        dpm.updateUserLetter(updated)
        var pending = Set(dpm.currentScopeDefaults.stringArray(forKey: pendingReadsKey) ?? [])
        pending.insert(SyncIDCodec.objectId(for: letter.id))
        dpm.currentScopeDefaults.set(Array(pending), forKey: pendingReadsKey)
    }

    func perform(token: String) async -> CoupleSyncTaskOutcome {
        var pending = dpm.currentScopeDefaults.stringArray(forKey: pendingReadsKey) ?? []
        guard !pending.isEmpty else { return .ok }
        for recordId in pending {
            do {
                let response = try await api.send(method: "POST", path: "\(path)/\(recordId)/read", body: [:], token: token)
                if response.status == 401 || response.status == 403 { return .notPaired }
                // Done, or refused for good (deleted, not delivered): either way stop retrying.
                pending.removeAll { $0 == recordId }
                dpm.currentScopeDefaults.set(pending, forKey: pendingReadsKey)
            } catch {
                return .offline
            }
        }
        return .ok
    }

    /// Forgets queued read receipts (end of a relationship).
    func reset() {
        dpm.currentScopeDefaults.removeObject(forKey: pendingReadsKey)
    }

    /// Partner letters delivered and not yet opened, for the Home mailbox badge.
    func newLetterCount() -> Int {
        dpm.loadUserLetters().filter(\.isNewFromPartner).count
    }
}
