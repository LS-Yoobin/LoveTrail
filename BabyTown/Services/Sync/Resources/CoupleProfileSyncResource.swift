import Foundation

/// Couple profile ↔ `GET`/`PATCH /couple/profile` (BAB-68).
///
/// Shared fields: the garden profile note and its mood.
/// Per partner (server `partner_profiles`, each user may only write their own entry):
/// this user's nickname and avatar go up; the other partner's come down.
///
/// Kept local: garden mood (expires after 24h on each device), canvas positions and
/// scales, relationship stage, breakup dates. The server has no fields for those.
@MainActor
final class CoupleProfileSyncResource: CoupleSyncDocument, CoupleSyncServerOwnedFields, CoupleSyncMediaHandling {
    let key = "profile"
    let path = "couple/profile"
    let writeMethod = "PATCH"

    private static let ownAvatarKey = "avatar.me"
    /// The partner avatar path stored locally.
    private static let partnerAvatarKey = "avatar.partner"
    /// The partner avatar path the server last reported. Persisted, so a failed
    /// download is retried on the next sync rather than forgotten.
    private static let partnerAvatarWantedKey = "avatar.partner.wanted"
    /// This user's avatar path as the server last reported it ("" = no photo). Echoed
    /// back while there is no local change to send, so a photo that is missing locally
    /// or still uploading is neither cleared nor re-sent on every sync (BAB-147).
    private static let ownAvatarServerKey = "avatar.me.server"

    private let dpm: DataPersistenceManager
    private let registry: SyncMediaRegistry
    /// Signed URL from the latest pull (short-lived, so not persisted).
    private var partnerAvatarSignedURL: String?

    init(dpm: DataPersistenceManager = .shared, registry: SyncMediaRegistry = .shared) {
        self.dpm = dpm
        self.registry = registry
    }

    private var ownUserId: String? {
        AuthService.shared.currentUser?.id.lowercased()
    }

    private var ownNickname: String {
        dpm.loadUserNickname() ?? dpm.loadCoupleProfile().displayName ?? ""
    }

    // MARK: Document

    func localBody() -> [String: Any]? {
        let profile = dpm.loadCoupleProfile()
        var own: [String: Any] = ["nickname": ownNickname]
        if let avatar = ownAvatarBodyValue() {
            own["avatar_path"] = avatar
        }
        return [
            "note": profile.profileNote ?? "",
            "mood": profile.profileNoteMood?.rawValue ?? "",
            "partner_profile": own,
        ]
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any] {
        let own = partnerEntry(in: dto, own: true)
        var ownBody: [String: Any] = ["nickname": own?["nickname"] as? String ?? ""]
        // Same form `localBody()` produces: a valid path, else no key. An empty or
        // invalid server value has no key here, so it never reads as a local edit.
        if let path = own?["avatar_path"] as? String, CovelaMediaPath.isValidRemoteMediaPath(path) {
            ownBody["avatar_path"] = path
        }
        return [
            "note": dto["note"] as? String ?? "",
            "mood": dto["mood"] as? String ?? "",
            "partner_profile": ownBody,
        ]
    }

    func serverHasContent(_ dto: [String: Any]) -> Bool {
        let note = dto["note"] as? String ?? ""
        let mood = dto["mood"] as? String ?? ""
        return !note.isEmpty || !mood.isEmpty
    }

    func applyRemote(_ dto: [String: Any]) {
        var profile = dpm.loadCoupleProfile()
        let note = dto["note"] as? String ?? ""
        profile.profileNote = note.isEmpty ? nil : note
        profile.profileNoteMood = ProfileNoteMood(rawValue: dto["mood"] as? String ?? "")
        dpm.saveCoupleProfile(profile)
        // The partner's entry is applied by `applyServerOwnedFields`, on every pull.
    }

    // MARK: Own avatar (BAB-147)

    /// What `partner_profile.avatar_path` should say, or `nil` to leave the key out:
    /// - local photo uploaded → its permanent server key;
    /// - the user removed their photo → `""` (the backend's "remove"; `null` is a 400);
    /// - anything else (photo not uploaded yet, upload failed or rejected, photo missing
    ///   on this phone) → the server's current value, so nothing changes there.
    /// Never a local file path or URL.
    private func ownAvatarBodyValue() -> String? {
        if let data = dpm.loadOwnAvatarData() {
            if let path = registry.remotePath(for: Self.ownAvatarKey, fingerprint: SyncMediaRegistry.fingerprint(of: data)),
               CovelaMediaPath.isValidRemoteMediaPath(path) {
                return path
            }
            return serverOwnAvatarPath
        }
        if dpm.isOwnAvatarRemovalPending {
            // The server already reported no photo: nothing left to remove.
            if registry.entry(for: Self.ownAvatarServerKey)?.remotePath == "" { return nil }
            return ""
        }
        return serverOwnAvatarPath
    }

    /// The server's valid avatar path for this user; `nil` when it has none, an
    /// invalid one, or no pull has reported it yet.
    private var serverOwnAvatarPath: String? {
        guard let path = registry.entry(for: Self.ownAvatarServerKey)?.remotePath,
              CovelaMediaPath.isValidRemoteMediaPath(path) else { return nil }
        return path
    }

    private func recordServerOwnAvatar(in dto: [String: Any]) {
        // Only from a well-formed answer; a missing own entry means "no photo yet".
        guard ownUserId != nil, dto["partner_profiles"] is [[String: Any]] else { return }
        let raw = partnerEntry(in: dto, own: true)?["avatar_path"] as? String ?? ""
        if raw.isEmpty {
            // Server has no photo for this user: a pending removal is done.
            if dpm.isOwnAvatarRemovalPending {
                dpm.clearOwnAvatarRemovalPending()
                CoupleSyncLog.event("profile own avatar removal confirmed")
            }
        } else if !CovelaMediaPath.isValidRemoteMediaPath(raw) {
            CoupleSyncLog.event("profile own avatar_path on server is invalid; not echoed")
        }
        if registry.entry(for: Self.ownAvatarServerKey)?.remotePath != raw {
            registry.record(key: Self.ownAvatarServerKey, remotePath: raw, fingerprint: nil)
        }
    }

    // MARK: Server-owned fields (BAB-147)

    /// The other partner's nickname and avatar. They are not part of `comparableBody`
    /// (that only covers what this user writes), so a change to them alone used to go
    /// unnoticed; the engine now calls this on every successful pull.
    /// Only ever writes the partner slots, never this user's own nickname or photo.
    func applyServerOwnedFields(_ dto: [String: Any]) -> Bool {
        recordServerOwnAvatar(in: dto)
        let entryCount = (dto["partner_profiles"] as? [[String: Any]])?.count ?? -1
        let hasOwn = partnerEntry(in: dto, own: true) != nil
        // No partner entry yet (the partner has not synced): keep what is stored.
        guard let partner = partnerEntry(in: dto, own: false) else {
            CoupleSyncLog.event("profile pulled entries=\(entryCount) own=\(hasOwn) partner=false")
            return false
        }
        var changed = false

        let nickname = (partner["nickname"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !nickname.isEmpty, nickname != dpm.loadSyncedPartnerNickname() {
            dpm.saveSyncedPartnerNickname(nickname)
            changed = true
        }

        let log = { (avatar: String) in
            CoupleSyncLog.event("profile pulled entries=\(entryCount) own=\(hasOwn) partner=true nicknameChanged=\(changed) partnerAvatar=\(avatar)")
        }

        let path = partner["avatar_path"] as? String ?? ""
        if path.isEmpty {
            // The partner removed their photo: drop our copy so it can't linger.
            let hadAvatar = registry.entry(for: Self.partnerAvatarWantedKey) != nil
                || registry.entry(for: Self.partnerAvatarKey) != nil
            guard hadAvatar else { log("none"); return changed }
            registry.remove(key: Self.partnerAvatarWantedKey)
            registry.remove(key: Self.partnerAvatarKey)
            partnerAvatarSignedURL = nil
            dpm.removeOtherPartnerAvatar()
            log("removed")
            return true
        }
        guard CovelaMediaPath.isValidRemoteMediaPath(path) else {
            // e.g. a `file://` path the backend accepted from a client: it can never be
            // downloaded. Keep whatever photo is stored instead of retrying it forever.
            log("invalid")
            return changed
        }

        if registry.entry(for: Self.partnerAvatarWantedKey)?.remotePath != path {
            registry.record(key: Self.partnerAvatarWantedKey, remotePath: path, fingerprint: nil)
            log("new")
        } else {
            log("same")
        }
        // Fresh signed URL for the download step; the photo itself changes (and views
        // are notified) only once `downloadPendingMedia` has written the new bytes.
        partnerAvatarSignedURL = partner["avatar_url"] as? String
        return changed
    }

    private func partnerEntry(in dto: [String: Any], own: Bool) -> [String: Any]? {
        guard let ownUserId,
              let entries = dto["partner_profiles"] as? [[String: Any]] else { return nil }
        return entries.first { entry in
            let isOwn = (entry["user_id"] as? String)?.lowercased() == ownUserId
            return own ? isOwn : !isOwn
        }
    }

    // MARK: Media

    func uploadPendingMedia() async throws {
        guard let data = dpm.loadOwnAvatarData() else { return }
        let fingerprint = SyncMediaRegistry.fingerprint(of: data)
        if let existing = registry.remotePath(for: Self.ownAvatarKey, fingerprint: fingerprint),
           CovelaMediaPath.isValidRemoteMediaPath(existing) { return }
        do {
            let path = try await SyncMediaTransfer.uploadJPEG(data, filename: "avatar.jpg")
            // Only a permanent server key may become `avatar_path`. Anything else is
            // not recorded, so the PATCH keeps the server's current photo.
            guard CovelaMediaPath.isValidRemoteMediaPath(path) else {
                CoupleSyncLog.event("profile own avatar upload returned an invalid path; not used")
                return
            }
            registry.record(key: Self.ownAvatarKey, remotePath: path, fingerprint: fingerprint)
            CoupleSyncLog.event("profile own avatar uploaded")
        } catch SyncMediaTransfer.TransferError.rejected {
            CoupleSyncLog.event("profile own avatar upload rejected; server photo kept")
            return
        } catch {
            CoupleSyncLog.event("profile own avatar upload offline; cycle stops before PATCH")
            throw error
        }
    }

    func downloadPendingMedia() async -> Bool {
        guard let wanted = registry.entry(for: Self.partnerAvatarWantedKey)?.remotePath,
              registry.entry(for: Self.partnerAvatarKey)?.remotePath != wanted else { return false }
        let signedURL = partnerAvatarSignedURL
        partnerAvatarSignedURL = nil
        guard let data = await SyncMediaTransfer.download(signedURL: signedURL, path: wanted) else {
            return false
        }
        dpm.saveOtherPartnerAvatarData(data)
        registry.record(
            key: Self.partnerAvatarKey,
            remotePath: wanted,
            fingerprint: SyncMediaRegistry.fingerprint(of: data)
        )
        return true
    }
}
