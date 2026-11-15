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
final class CoupleProfileSyncResource: CoupleSyncDocument, CoupleSyncMediaHandling {
    let key = "profile"
    let path = "couple/profile"
    let writeMethod = "PATCH"

    private static let ownAvatarKey = "avatar.me"
    /// The partner avatar path stored locally.
    private static let partnerAvatarKey = "avatar.partner"
    /// The partner avatar path the server last reported. Persisted, so a failed
    /// download is retried on the next sync rather than forgotten.
    private static let partnerAvatarWantedKey = "avatar.partner.wanted"

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
        if let data = dpm.loadOwnAvatarData(),
           let path = registry.remotePath(for: Self.ownAvatarKey, fingerprint: SyncMediaRegistry.fingerprint(of: data)) {
            own["avatar_path"] = path
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
        if let path = own?["avatar_path"] as? String, !path.isEmpty {
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

        if let partner = partnerEntry(in: dto, own: false) {
            if let nickname = partner["nickname"] as? String {
                dpm.saveSyncedPartnerNickname(nickname)
            }
            if let path = partner["avatar_path"] as? String, !path.isEmpty {
                registry.record(key: Self.partnerAvatarWantedKey, remotePath: path, fingerprint: nil)
                partnerAvatarSignedURL = partner["avatar_url"] as? String
            }
        }
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
        guard registry.remotePath(for: Self.ownAvatarKey, fingerprint: fingerprint) == nil else { return }
        do {
            let path = try await SyncMediaTransfer.uploadJPEG(data, filename: "avatar.jpg")
            registry.record(key: Self.ownAvatarKey, remotePath: path, fingerprint: fingerprint)
        } catch SyncMediaTransfer.TransferError.rejected {
            return
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
