import Foundation
import GardenCore

@MainActor
final class ArchiveService {
    static let shared = ArchiveService()

    private let persistence = DataPersistenceManager.shared
    private let api: ArchiveAPIClientProtocol = StubArchiveAPIClient.shared

    private init() {}

    // MARK: - Breakup Initiation

    /// Uploads all media, creates the server-side archive bundle, and transitions the
    /// local profile to `archivedCouple`. `progress` is called with 0.0–1.0 as
    /// each moment is uploaded.
    func initiateBreakup(progress: @escaping @Sendable (Double) -> Void) async throws {
        let moments = persistence.loadMoments()
        let profile = persistence.loadCoupleProfile()
        let petState = persistence.loadPetState()
        let gardenState = persistence.loadGardenState()
        let playlist = CouplePlaylistStore.tracks
        let preludeChapter = persistence.loadPreludeChapter()

        let total = max(moments.count, 1)
        for (index, moment) in moments.enumerated() {
            try await api.uploadMomentMedia(moment)
            let fraction = Double(index + 1) / Double(total)
            progress(fraction)
        }

        let breakupDate = Date()
        let expiryDate = breakupDate.addingTimeInterval(30 * 24 * 60 * 60)

        let bundle = ArchiveBundle(
            coupleId: profile.coupleId ?? "",
            breakupDate: breakupDate,
            expiryDate: expiryDate,
            moments: moments,
            coupleProfile: profile,
            petState: petState,
            gardenState: gardenState,
            playlist: playlist,
            preludeChapter: preludeChapter
        )
        try await api.createArchiveBundle(bundle)
        persistence.saveArchiveBundle(bundle)

        var updated = profile
        updated.relationshipStage = .archivedCouple
        updated.breakupDate = breakupDate
        updated.archiveExpiryDate = expiryDate
        updated.hasSteppedOut = false
        persistence.saveCoupleProfile(updated)
    }

    // MARK: - Extend Retention

    /// Silently resets the retention clock to `now + 30 days`.
    func extendRetention() async throws {
        guard var bundle = persistence.loadArchiveBundle() else { return }
        let newExpiry = Date().addingTimeInterval(30 * 24 * 60 * 60)
        try await api.extendRetention(coupleId: bundle.coupleId, newExpiry: newExpiry)
        bundle.expiryDate = newExpiry
        persistence.saveArchiveBundle(bundle)

        var profile = persistence.loadCoupleProfile()
        profile.archiveExpiryDate = newExpiry
        persistence.saveCoupleProfile(profile)
    }

    // MARK: - Step Out

    /// Revokes server access, clears local archive, and transitions the profile to `.prelude`.
    func stepOut() async throws {
        let profile = persistence.loadCoupleProfile()
        try await api.stepOut(coupleId: profile.coupleId ?? "")
        persistence.deleteArchiveBundle()

        var updated = profile
        updated.relationshipStage = .prelude
        updated.hasSteppedOut = true
        updated.breakupDate = nil
        updated.archiveExpiryDate = nil
        persistence.saveCoupleProfile(updated)
    }

    // MARK: - Export

    /// Requests a server-generated ZIP and returns the download URL for the share sheet.
    func requestExportURL() async throws -> URL {
        let profile = persistence.loadCoupleProfile()
        return try await api.generateExportZip(coupleId: profile.coupleId ?? "")
    }

    // MARK: - Reconnect

    func sendReconnectInvite() async throws -> BreakupReconnectInvite {
        let profile = persistence.loadCoupleProfile()
        return try await api.sendReconnectInvite(coupleId: profile.coupleId ?? "")
    }

    /// Accepts an incoming reconnect invite and restores the couple to `officialCouple`.
    /// Garden and pet resume from their frozen archive snapshots.
    func acceptReconnectInvite(inviteId: UUID) async throws {
        let profile = persistence.loadCoupleProfile()
        try await api.acceptReconnectInvite(inviteId: inviteId, coupleId: profile.coupleId ?? "")

        if let bundle = persistence.loadArchiveBundle() {
            persistence.savePetState(bundle.petState)
            persistence.saveGardenState(bundle.gardenState)
        }
        persistence.deleteArchiveBundle()

        var updated = profile
        updated.relationshipStage = .officialCouple
        updated.hasSteppedOut = false
        updated.breakupDate = nil
        updated.archiveExpiryDate = nil
        persistence.saveCoupleProfile(updated)
    }
}
