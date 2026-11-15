import Combine
import Foundation
import UserNotifications

@MainActor
final class ArchiveService: ObservableObject {

    static let shared = ArchiveService()

    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0

    private let dpm = DataPersistenceManager.shared
    private let api: ArchiveAPIClientProtocol = LiveArchiveAPIClient.shared
    /// A step-out that couldn't reach the server; retried by `refreshFromServer()`.
    private let pendingStepOutKey = "archivePendingServerStepOut"

    private init() {}

    // MARK: - Breakup

    /// Ends the relationship on the server, then archives locally with the server's
    /// dates. Returns `false` (and changes nothing) if the server can't be reached:
    /// a breakup only on this phone would leave the partner's Cove syncing as usual.
    @discardableResult
    func beginBreakup() async -> Bool {
        isUploading = true
        uploadProgress = 0
        defer { isUploading = false }

        // Send any last changes while writes are still allowed.
        await CoupleSyncEngine.shared.sync(trigger: .manual)
        uploadProgress = 0.4

        let state: ArchiveServerState
        do {
            state = try await api.startBreakup()
        } catch {
            return false
        }
        uploadProgress = 0.8

        archiveLocally(
            breakupDate: state.breakupDate ?? Date(),
            expiryDate: state.archiveExpiresAt
        )
        uploadProgress = 1
        return true
    }

    /// Snapshots the Cove into the local scrapbook and switches to the archive phase.
    private func archiveLocally(breakupDate: Date, expiryDate: Date?) {
        let expiry = expiryDate ?? Calendar.current.date(byAdding: .day, value: 30, to: breakupDate)!
        let profile = dpm.loadCoupleProfile()
        let bundle = ArchiveBundle(
            coupleId: profile.coupleId ?? "local-\(Int(breakupDate.timeIntervalSince1970))",
            breakupDate: breakupDate,
            expiryDate: expiry,
            userASteppedOut: false,
            userBSteppedOut: false,
            moments: dpm.loadMoments(),
            coupleProfile: profile,
            petState: dpm.loadPetState(),
            preludeChapter: dpm.loadPreludeChapter()
        )
        dpm.saveArchiveBundle(bundle)

        var updated = profile
        updated.relationshipStage = .archivedCouple
        updated.breakupDate = breakupDate
        updated.archiveExpiryDate = expiry
        updated.hasSteppedOut = false
        dpm.saveCoupleProfile(updated)

        scheduleRetentionNotifications(expiryDate: expiry)
    }

    // MARK: - Retention

    /// Adds 30 days on the server (which decides when the Cove is deleted) and mirrors
    /// the new expiry locally. Returns `false` if the server couldn't be reached.
    @discardableResult
    func extendRetention() async -> Bool {
        guard let state = try? await api.extendArchive(),
              let newExpiry = state.archiveExpiresAt else { return false }
        applyExpiry(newExpiry)
        return true
    }

    private func applyExpiry(_ newExpiry: Date) {
        var profile = dpm.loadCoupleProfile()
        guard profile.archiveExpiryDate != newExpiry else { return }
        profile.archiveExpiryDate = newExpiry
        dpm.saveCoupleProfile(profile)
        if var bundle = dpm.loadArchiveBundle() {
            bundle.expiryDate = newExpiry
            dpm.saveArchiveBundle(bundle)
        }
        scheduleRetentionNotifications(expiryDate: newExpiry)
    }

    // MARK: - Server state

    /// Aligns this phone with the server's view of the relationship. Call on launch,
    /// foreground, and when a breakup or dissolve push arrives.
    ///
    /// - The partner started a breakup → archive locally with the server's dates.
    /// - The window was extended on the other phone → take the new expiry.
    /// - The couple was dissolved (window ended, or both stepped out) → clear the Cove,
    ///   but only after `pairing-status` confirms it, so an auth or network glitch can
    ///   never wipe a phone.
    func refreshFromServer() async {
        guard AuthService.shared.isSignedIn else { return }

        if dpm.currentScopeDefaults.bool(forKey: pendingStepOutKey) {
            do {
                _ = try await api.stepOut()
                dpm.currentScopeDefaults.removeObject(forKey: pendingStepOutKey)
            } catch ArchiveAPIError.offline {
                // Keep it; try again next time.
            } catch {
                // 403 / 409: the server already has us stepped out, or the couple is gone.
                dpm.currentScopeDefaults.removeObject(forKey: pendingStepOutKey)
            }
        }

        let stage = dpm.loadCoupleProfile().relationshipStage
        guard stage == .officialCouple || stage == .archivedCouple else { return }

        do {
            let state = try await api.fetchArchive()
            if stage == .officialCouple {
                archiveLocally(breakupDate: state.breakupDate ?? Date(), expiryDate: state.archiveExpiresAt)
                NotificationCenter.default.post(name: AppDelegate.openScrapbookNotificationName, object: nil)
            } else if let expiry = state.archiveExpiresAt {
                applyExpiry(expiry)
            }
        } catch ArchiveAPIError.notArchived {
            // Still together on the server: nothing to do.
            return
        } catch ArchiveAPIError.noAccess {
            await endRelationshipIfServerConfirms()
        } catch {
            return
        }
    }

    /// The server deleted the couple (archive expired, or both stepped out). Clears the
    /// Cove only when `pairing-status` agrees this account is no longer in a couple.
    func endRelationshipIfServerConfirms() async {
        // Never wipe a phone that has not synced with a server couple: older installs can
        // be "official" locally without one, and "not paired" says nothing about them.
        guard dpm.loadServerCoupleProfileId() != nil else { return }
        guard let status = try? await InviteAPI.client.checkPairingStatus(),
              !status.paired,
              status.relationshipStage != .officialCouple,
              status.relationshipStage != .archivedCouple else { return }
        let stage = dpm.loadCoupleProfile().relationshipStage
        guard stage == .officialCouple || stage == .archivedCouple else { return }
        endRelationship()
    }

    // MARK: - Step Out

    /// Leaves the archive now. Everything the couple built is removed from this phone
    /// (see `DataPersistenceManager.clearCoupleData()`).
    func stepOut() {
        var profile = dpm.loadCoupleProfile()
        profile.hasSteppedOut = true
        dpm.saveCoupleProfile(profile)
        endRelationship()

        // Tell the server (it dissolves the couple once both have stepped out). Stepping
        // out never waits on the network; if offline, it is retried by `refreshFromServer`.
        let defaults = dpm.currentScopeDefaults
        defaults.set(true, forKey: pendingStepOutKey)
        Task {
            do {
                _ = try await api.stepOut()
                defaults.removeObject(forKey: pendingStepOutKey)
            } catch ArchiveAPIError.offline {
                return
            } catch {
                defaults.removeObject(forKey: pendingStepOutKey)
            }
        }
    }

    /// Ends the archive if its window has passed. Call at launch (before routing) and
    /// when the app returns to the foreground, so expiry doesn't depend on the user
    /// tapping the "archive expired" notification. Returns `true` if it ended.
    @discardableResult
    func endArchiveIfExpired(now: Date = Date()) -> Bool {
        let profile = dpm.loadCoupleProfile()
        guard profile.relationshipStage == .archivedCouple,
              let expiry = profile.archiveExpiryDate,
              expiry <= now else { return false }
        endRelationship()
        return true
    }

    /// The relationship is over and its archive window is closed: remove what the
    /// couple built and return to Prelude.
    func endRelationship() {
        dpm.clearCoupleData()
        cancelRetentionNotifications()
    }

    // MARK: - Reconnect

    func sendReconnectInvite(fromUserId: String = "local-user", toUserId: String = "partner") {
        let invite = BreakupReconnectInvite(
            id: UUID(),
            senderUserId: fromUserId,
            recipientUserId: toUserId,
            sentAt: Date(),
            status: .pending
        )
        dpm.saveReconnectInvite(invite)
    }

    func acceptReconnect() {
        var profile = dpm.loadCoupleProfile()
        profile.relationshipStage = .officialCouple
        profile.breakupDate = nil
        profile.archiveExpiryDate = nil
        profile.hasSteppedOut = false
        dpm.saveCoupleProfile(profile)
        dpm.clearReconnectInvite()
        cancelRetentionNotifications()
    }

    func declineReconnect() {
        guard var invite = dpm.loadReconnectInvite() else { return }
        invite.status = .declined
        dpm.saveReconnectInvite(invite)
    }

    // MARK: - Export

    /// Returns a plain-text export of the archive bundle for sharing.
    func generateExportText() -> String {
        guard let bundle = dpm.loadArchiveBundle() else {
            return "No archive found."
        }

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        var lines: [String] = []

        let name = bundle.coupleProfile.displayName ?? "Our Story"
        lines.append("=== \(name) — Archive ===")
        lines.append("Archived: \(fmt.string(from: bundle.breakupDate))")
        lines.append("")

        lines.append("MEMORIES (\(bundle.moments.count))")
        lines.append(String(repeating: "-", count: 32))
        for moment in bundle.moments.sorted(by: { $0.dateTaken < $1.dateTaken }) {
            var entry = "[\(fmt.string(from: moment.dateTaken))]"
            if let caption = moment.caption { entry += " \(caption)" }
            if let place = moment.placeName { entry += " @ \(place)" }
            lines.append(entry)
        }

        let dates = bundle.coupleProfile.specialDates
        if !dates.isEmpty {
            lines.append("")
            lines.append("SPECIAL DATES")
            lines.append(String(repeating: "-", count: 32))
            for d in dates { lines.append("• \(d.title): \(fmt.string(from: d.date))") }
        }

        if let chapter = bundle.preludeChapter {
            lines.append("")
            lines.append("PRELUDE CHAPTER")
            lines.append(String(repeating: "-", count: 32))
            lines.append("Started: \(fmt.string(from: chapter.startDate))")
            lines.append("Became official: \(fmt.string(from: chapter.officialDate))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Local Notifications

    func scheduleRetentionNotifications(expiryDate: Date) {
        cancelRetentionNotifications()
        let center = UNUserNotificationCenter.current()
        let sevenDay = expiryDate.addingTimeInterval(-7 * 24 * 3600)
        let threeDay = expiryDate.addingTimeInterval(-3 * 24 * 3600)

        scheduleArchiveNotification(
            center: center,
            identifier: "archive_7_day",
            title: "Your shared memories expire soon",
            body: "Your shared memories expire in 7 days. Export or extend to keep them.",
            fireDate: sevenDay
        )
        scheduleArchiveNotification(
            center: center,
            identifier: "archive_3_day",
            title: "Last chance to export",
            body: "Your shared memories expire in 3 days.",
            fireDate: threeDay
        )
        scheduleArchiveNotification(
            center: center,
            identifier: "archive_expired",
            title: "Your memories have been deleted.",
            body: "Your shared archive has expired and can no longer be recovered.",
            fireDate: expiryDate
        )
    }

    private func scheduleArchiveNotification(
        center: UNUserNotificationCenter,
        identifier: String,
        title: String,
        body: String,
        fireDate: Date
    ) {
        guard fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancelRetentionNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["archive_7_day", "archive_3_day", "archive_expired"]
        )
    }
}
