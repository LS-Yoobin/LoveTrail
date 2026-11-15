import Foundation

/// Special dates (`CoupleProfile.specialDates`) ↔ `/couple/special-dates`.
///
/// Synced: title, date and the optional photo. Kept local: pin state (each partner
/// pins their own) and birthday rows. Birthdays are written from each user's own
/// perspective ("my birthday" vs "partner's birthday", with fixed ids shared by every
/// install), so syncing them would duplicate them and collide across couples.
@MainActor
final class SpecialDatesSyncResource: CoupleSyncCollection, CoupleSyncMediaHandling {
    let key = "special-dates"
    let path = "couple/special-dates"

    private let dpm: DataPersistenceManager
    private let registry: SyncMediaRegistry
    /// Short-lived signed URLs from the latest pull, by record id.
    private var signedPhotoURLs: [String: String] = [:]

    init(dpm: DataPersistenceManager = .shared, registry: SyncMediaRegistry = .shared) {
        self.dpm = dpm
        self.registry = registry
    }

    private static func isSynced(_ date: SpecialDate) -> Bool {
        !date.isBirthday
    }

    /// Registry key for the photo stored locally for a record.
    private static func photoKey(_ recordId: String) -> String { "special-date.\(recordId)" }
    /// Registry key for the photo the server last reported for a record.
    private static func wantedPhotoKey(_ recordId: String) -> String { "special-date.\(recordId).wanted" }

    private var syncedDates: [SpecialDate] {
        dpm.loadCoupleProfile().specialDates.filter(Self.isSynced)
    }

    // MARK: Collection

    func localRecords() -> [String: [String: Any]] {
        var records: [String: [String: Any]] = [:]
        for date in syncedDates {
            let recordId = SyncIDCodec.objectId(for: date.id)
            var body: [String: Any] = [
                "title": date.title,
                "date": SyncJSON.string(from: date.date),
            ]
            if let data = dpm.loadSpecialDatePhotoData(id: date.id),
               let photoPath = registry.remotePath(
                   for: Self.photoKey(recordId),
                   fingerprint: SyncMediaRegistry.fingerprint(of: data)
               ) {
                body["photo_path"] = photoPath
            }
            records[recordId] = body
        }
        return records
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? {
        guard let title = dto["title"] as? String,
              let date = SyncJSON.date(from: dto["date"]),
              !SpecialDate.isBirthdayTitle(title) else { return nil }
        var body: [String: Any] = ["title": title, "date": SyncJSON.string(from: date)]
        if let photoPath = dto["photo_path"] as? String, !photoPath.isEmpty {
            body["photo_path"] = photoPath
        }
        return body
    }

    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {
        var profile = dpm.loadCoupleProfile()
        let deleted = Set(deletedIds)

        for (index, entry) in profile.specialDates.enumerated().reversed() where Self.isSynced(entry) {
            let recordId = SyncIDCodec.objectId(for: entry.id)
            guard deleted.contains(recordId) else { continue }
            profile.specialDates.remove(at: index)
            dpm.deleteSpecialDatePhoto(id: entry.id)
            registry.remove(key: Self.photoKey(recordId))
            registry.remove(key: Self.wantedPhotoKey(recordId))
        }

        for dto in upserts {
            guard let recordId = (dto["id"] as? String)?.lowercased(),
                  let title = dto["title"] as? String,
                  let date = SyncJSON.date(from: dto["date"]),
                  !SpecialDate.isBirthdayTitle(title) else { continue }

            let localId: UUID
            if let index = profile.specialDates.firstIndex(where: { SyncIDCodec.matches($0.id, objectId: recordId) }) {
                profile.specialDates[index].title = title
                profile.specialDates[index].date = date
                localId = profile.specialDates[index].id
            } else if let newId = SyncIDCodec.uuid(forObjectId: recordId) {
                profile.specialDates.append(SpecialDate(id: newId, title: title, date: date))
                localId = newId
            } else {
                continue
            }

            if let photoPath = dto["photo_path"] as? String, !photoPath.isEmpty {
                registry.record(key: Self.wantedPhotoKey(recordId), remotePath: photoPath, fingerprint: nil)
                if let url = dto["photo_url"] as? String { signedPhotoURLs[recordId] = url }
            } else if registry.entry(for: Self.photoKey(recordId)) != nil {
                // The partner removed a photo that had been synced.
                dpm.deleteSpecialDatePhoto(id: localId)
                registry.remove(key: Self.photoKey(recordId))
                registry.remove(key: Self.wantedPhotoKey(recordId))
            }
        }

        dpm.saveCoupleProfile(profile)
    }

    // MARK: Media

    func uploadPendingMedia() async throws {
        for date in syncedDates {
            guard let data = dpm.loadSpecialDatePhotoData(id: date.id) else { continue }
            let recordId = SyncIDCodec.objectId(for: date.id)
            let fingerprint = SyncMediaRegistry.fingerprint(of: data)
            guard registry.remotePath(for: Self.photoKey(recordId), fingerprint: fingerprint) == nil else { continue }
            do {
                let path = try await SyncMediaTransfer.uploadJPEG(data, filename: "special_date.jpg")
                registry.record(key: Self.photoKey(recordId), remotePath: path, fingerprint: fingerprint)
            } catch SyncMediaTransfer.TransferError.rejected {
                continue
            }
        }
    }

    func downloadPendingMedia() async -> Bool {
        var wroteAny = false
        for date in syncedDates {
            let recordId = SyncIDCodec.objectId(for: date.id)
            guard let wanted = registry.entry(for: Self.wantedPhotoKey(recordId))?.remotePath,
                  registry.entry(for: Self.photoKey(recordId))?.remotePath != wanted else { continue }
            let signedURL = signedPhotoURLs.removeValue(forKey: recordId)
            guard let data = await SyncMediaTransfer.download(signedURL: signedURL, path: wanted) else { continue }
            dpm.saveSpecialDatePhotoData(data, id: date.id)
            registry.record(
                key: Self.photoKey(recordId),
                remotePath: wanted,
                fingerprint: SyncMediaRegistry.fingerprint(of: data)
            )
            wroteAny = true
        }
        return wroteAny
    }
}
