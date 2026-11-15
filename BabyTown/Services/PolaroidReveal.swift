import Foundation
import UIKit

/// The daily polaroid reveal (9 PM Pacific), shared by Home and the background
/// refresh so it works even when no screen is on.
///
/// Revealing turns each polaroid into a Moment with the same id. If the server
/// already revealed it (BAB-143) and sync pulled that Moment, the existing Moment is
/// kept and only gets this phone's full-quality photo and video.
@MainActor
enum PolaroidReveal {
    /// Polaroids whose developing time has passed: removes their processing cards and
    /// marks them released. Returns the entries to turn into moments.
    static func takeDueEntries(from store: LocalPolaroidStore, now: Date = Date()) -> [PolaroidEntry] {
        let unlocked = store.processingMemories.filter { $0.unlockTime <= now }
        var due: [PolaroidEntry] = []
        for memory in unlocked {
            guard let entry = store.entries.first(where: { $0.id == memory.id }) else { continue }
            due.append(entry)
            store.removeProcessingMemory(memory.id)
        }
        if !due.isEmpty {
            store.releaseEntries(due)
        }
        return due
    }

    /// Adds a Moment for each revealed polaroid to `moments` (newest first, no duplicates).
    static func apply(_ entries: [PolaroidEntry], store: LocalPolaroidStore, to moments: inout [Moment]) {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone

        var newMoments: [Moment] = []
        for entry in entries {
            if let index = moments.firstIndex(where: { $0.id == entry.id }) {
                if !ThumbnailStore.shared.hasFile(for: entry.id),
                   let image = store.loadImage(for: entry) {
                    ThumbnailStore.shared.store(image, for: entry.id)
                }
                if let polaroidVideoFileName = entry.videoFileName {
                    MomentVideoStore.shared.importFromPolaroid(
                        momentId: entry.id,
                        polaroidFileName: polaroidVideoFileName
                    )
                    moments[index].videoFileName = MomentVideoStore.shared.fileName(for: entry.id)
                }
                continue
            }

            guard let image = store.loadImage(for: entry) else { continue }

            // Revealed early by hand: the moment stays locked until tonight's 9 PM.
            var isLocked = false
            var unlockTime: Date?
            if let manualReleaseTime = entry.manuallyReleasedAt {
                let captureDay = laCalendar.startOfDay(for: entry.capturedAt)
                var releaseComponents = laCalendar.dateComponents([.year, .month, .day], from: captureDay)
                releaseComponents.hour = 21
                releaseComponents.minute = 0
                releaseComponents.second = 0
                if let scheduledUnlockTime = laCalendar.date(from: releaseComponents),
                   manualReleaseTime < scheduledUnlockTime {
                    isLocked = true
                    unlockTime = scheduledUnlockTime
                }
            }

            var videoFileName: String?
            if let polaroidVideoFileName = entry.videoFileName {
                MomentVideoStore.shared.importFromPolaroid(
                    momentId: entry.id,
                    polaroidFileName: polaroidVideoFileName
                )
                videoFileName = MomentVideoStore.shared.fileName(for: entry.id)
            }

            newMoments.append(Moment(
                id: entry.id,
                dateTaken: entry.capturedAt,
                assetIdentifier: nil,
                thumbnail: image,
                placeName: entry.placeName,
                isLocked: isLocked,
                unlockTime: unlockTime,
                latitude: entry.latitude,
                longitude: entry.longitude,
                videoFileName: videoFileName,
                dateAddedToApp: Date()
            ))
        }

        var seen = Set<UUID>()
        moments = (moments + newMoments).filter { seen.insert($0.id).inserted }
        moments.sort { $0.dateTaken > $1.dateTaken }
    }

    /// Headless reveal for the background refresh: reveals due polaroids straight into
    /// `moments.json`. Returns `true` if anything was revealed.
    @discardableResult
    static func revealDueInBackground() -> Bool {
        let store = LocalPolaroidStore()
        let due = takeDueEntries(from: store)
        guard !due.isEmpty else { return false }
        var moments = DataPersistenceManager.shared.loadMoments()
        apply(due, store: store, to: &moments)
        DataPersistenceManager.shared.saveMoments(moments)
        // If the app process (and HomeViewModel) is alive, reload its in-memory moments
        // before it can save its stale copy over this one.
        NotificationCenter.default.post(
            name: .coupleSyncDidApplyRemoteChanges,
            object: nil,
            userInfo: ["resources": Set(["moments"])]
        )
        return true
    }
}
