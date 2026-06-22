import Combine
import Foundation
import UserNotifications

@MainActor
final class ArchiveService: ObservableObject {

    static let shared = ArchiveService()

    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0

    private let dpm = DataPersistenceManager.shared

    private init() {}

    // MARK: - Breakup

    /// Creates a local ArchiveBundle snapshot from current device state and simulates an upload.
    /// Updates CoupleProfile to .archivedCouple on completion.
    func beginBreakup() async {
        isUploading = true
        uploadProgress = 0

        let profile = dpm.loadCoupleProfile()
        let moments = dpm.loadMoments()
        let petState = dpm.loadPetState()
        let preludeChapter = dpm.loadPreludeChapter()
        let breakupDate = Date()
        let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: breakupDate)!

        let bundle = ArchiveBundle(
            coupleId: "local-\(profile.displayName ?? "couple")-\(Int(breakupDate.timeIntervalSince1970))",
            breakupDate: breakupDate,
            expiryDate: expiryDate,
            userASteppedOut: false,
            userBSteppedOut: false,
            moments: moments,
            coupleProfile: profile,
            petState: petState,
            preludeChapter: preludeChapter
        )

        // Simulate upload: 10 steps × 0.2s = 2s total
        for step in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            uploadProgress = Double(step) / 10.0
        }

        dpm.saveArchiveBundle(bundle)

        var updated = profile
        updated.relationshipStage = .archivedCouple
        updated.breakupDate = breakupDate
        updated.archiveExpiryDate = expiryDate
        updated.hasSteppedOut = false
        dpm.saveCoupleProfile(updated)

        scheduleRetentionNotifications(expiryDate: expiryDate)

        isUploading = false
    }

    // MARK: - Retention

    func extendRetention() {
        let newExpiry = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        var profile = dpm.loadCoupleProfile()
        profile.archiveExpiryDate = newExpiry
        dpm.saveCoupleProfile(profile)

        if var bundle = dpm.loadArchiveBundle() {
            bundle.expiryDate = newExpiry
            dpm.saveArchiveBundle(bundle)
        }

        scheduleRetentionNotifications(expiryDate: newExpiry)
    }

    // MARK: - Step Out

    func stepOut() {
        var profile = dpm.loadCoupleProfile()
        profile.hasSteppedOut = true
        profile.relationshipStage = .prelude
        profile.breakupDate = nil
        profile.archiveExpiryDate = nil
        dpm.saveCoupleProfile(profile)
        dpm.deleteArchiveBundle()
        dpm.clearReconnectInvite()
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
