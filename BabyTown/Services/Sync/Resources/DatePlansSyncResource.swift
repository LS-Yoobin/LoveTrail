import Foundation

/// Date plans (`DatePlanStore`) ↔ `/couple/date-plans` (BAB-126, Story 1).
///
/// Synced, text only: plan title, start day, number of days, time, notes, and each
/// itinerary stop's id, order, day, place name, address, coordinates and note.
/// Kept local: the cover photo, stop photos, stop → moment links, and the creator
/// (`createdByUserID` holds an email and is never sent).
///
/// **Not registered yet** (`isNetworkSyncEnabled`). The path, field names and the
/// formats below are assumptions taken from the other couple collections (BAB-54
/// pattern) and have not been checked against the BAB-63 endpoint:
/// - `date`: the plan's first day as `yyyy-MM-dd`, so partners in different time zones
///   see the same day.
/// - `time`: `HH:mm` (24 hour), or absent.
/// - stop `id`: `SyncIDCodec.objectId(for:)`, like record ids.
@MainActor
final class DatePlansSyncResource: CoupleSyncCollection {
    /// Turn on (and register in `CoupleSyncBootstrap`) only after the BAB-63 endpoint is
    /// verified against the assumptions above. While off, the store never notifies the
    /// engine and the engine never calls this resource.
    nonisolated static let isNetworkSyncEnabled = false

    /// Resource key, also used by views to tell date plan changes apart in
    /// `coupleSyncDidApplyRemoteChanges` notifications.
    nonisolated static let resourceKey = "date-plans"

    /// Whether a `coupleSyncDidApplyRemoteChanges` notification includes date plans.
    static func didChangeDatePlans(_ notification: Notification) -> Bool {
        (notification.userInfo?["resources"] as? Set<String>)?.contains(resourceKey) ?? false
    }

    let key = DatePlansSyncResource.resourceKey
    let path = "couple/date-plans"

    private let store: DatePlanStore

    init(store: DatePlanStore? = nil) {
        self.store = store ?? .shared
    }

    // MARK: Collection

    func localRecords() -> [String: [String: Any]] {
        var records: [String: [String: Any]] = [:]
        for plan in store.allPlans() {
            records[SyncIDCodec.objectId(for: plan.id)] = SyncedPlanFields(plan: plan).body
        }
        return records
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? {
        SyncedPlanFields(dto: dto)?.body
    }

    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {
        var plans = store.allPlans()
        let deleted = Set(deletedIds)
        if !deleted.isEmpty {
            plans.removeAll { deleted.contains(SyncIDCodec.objectId(for: $0.id)) }
        }

        for dto in upserts {
            guard let recordId = (dto["id"] as? String)?.lowercased(),
                  let fields = SyncedPlanFields(dto: dto) else { continue }
            let updatedAt = SyncJSON.date(from: dto["updated_at"]) ?? Date()

            if let index = plans.firstIndex(where: { SyncIDCodec.matches($0.id, objectId: recordId) }) {
                fields.apply(to: &plans[index])
                plans[index].updatedAt = updatedAt
            } else if let localId = SyncIDCodec.uuid(forObjectId: recordId) {
                var plan = DatePlan(
                    id: localId,
                    title: fields.title,
                    date: fields.startDay,
                    createdByUserID: "",
                    createdAt: SyncJSON.date(from: dto["created_at"]) ?? updatedAt,
                    updatedAt: updatedAt
                )
                fields.apply(to: &plan)
                plans.append(plan)
            }
        }

        store.replacePlansFromSync(plans)
    }
}

/// The synced part of a `DatePlan`, built either from a local plan or a server DTO.
/// Both directions go through `body`, so they compare equal when the text matches.
private struct SyncedPlanFields {
    struct Stop {
        let id: String
        let order: Int
        let day: Int
        let placeName: String
        let address: String?
        let latitude: Double?
        let longitude: Double?
        let note: String?
    }

    let title: String
    let day: String
    let numberOfDays: Int
    let time: String?
    let notes: String?
    let stops: [Stop]

    var startDay: Date {
        Self.dayFormatter.date(from: day).map { Calendar.current.startOfDay(for: $0) } ?? Date()
    }

    init(plan: DatePlan) {
        title = plan.title
        day = Self.dayFormatter.string(from: plan.date)
        numberOfDays = plan.numberOfDays
        time = plan.time.map { Self.timeFormatter.string(from: $0) }
        notes = plan.notes
        stops = plan.itinerary.map { stop in
            Stop(
                id: SyncIDCodec.objectId(for: stop.id),
                order: stop.order,
                day: stop.day,
                placeName: stop.placeName,
                address: stop.address,
                latitude: stop.latitude,
                longitude: stop.longitude,
                note: stop.note
            )
        }
    }

    init?(dto: [String: Any]) {
        guard let title = dto["title"] as? String,
              let day = dto["date"] as? String,
              Self.dayFormatter.date(from: day) != nil else { return nil }
        self.title = title
        self.day = day
        numberOfDays = min(max(SyncJSON.int(dto["number_of_days"]) ?? 1, 1), PlannerDateRange.maxDays)
        if let time = dto["time"] as? String, Self.timeFormatter.date(from: time) != nil {
            self.time = time
        } else {
            time = nil
        }
        notes = dto["notes"] as? String
        stops = (dto["itinerary"] as? [[String: Any]] ?? []).compactMap { raw in
            guard let id = (raw["id"] as? String)?.lowercased(),
                  SyncIDCodec.uuid(forObjectId: id) != nil,
                  let placeName = raw["place_name"] as? String else { return nil }
            return Stop(
                id: id,
                order: SyncJSON.int(raw["order"]) ?? 0,
                day: max(SyncJSON.int(raw["day"]) ?? 1, 1),
                placeName: placeName,
                address: raw["address"] as? String,
                latitude: SyncJSON.double(raw["latitude"]),
                longitude: SyncJSON.double(raw["longitude"]),
                note: raw["note"] as? String
            )
        }
    }

    /// Stops sorted by order, then id, so the same itinerary always gives the same body.
    private var sortedStops: [Stop] {
        stops.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    var body: [String: Any] {
        let itinerary: [[String: Any]] = sortedStops.map { stop in
            SyncJSON.compacted([
                "id": stop.id,
                "order": stop.order,
                "day": stop.day,
                "place_name": stop.placeName,
                "address": stop.address,
                "latitude": stop.latitude,
                "longitude": stop.longitude,
                "note": stop.note,
            ])
        }
        return SyncJSON.compacted([
            "title": title,
            "date": day,
            "number_of_days": numberOfDays,
            "time": time,
            "notes": notes,
            "itinerary": itinerary,
        ])
    }

    /// Writes the synced fields into `plan`, keeping its local-only fields (cover photo,
    /// creator, and each matching stop's photo and moment link).
    func apply(to plan: inout DatePlan) {
        plan.title = title
        plan.date = startDay
        plan.numberOfDays = numberOfDays
        plan.time = time.flatMap { Self.timeOfDay($0, on: startDay) }
        plan.notes = notes

        let existing = plan.itinerary
        plan.itinerary = sortedStops.compactMap { remote in
            let local = existing.first { SyncIDCodec.matches($0.id, objectId: remote.id) }
            guard let id = local?.id ?? SyncIDCodec.uuid(forObjectId: remote.id) else { return nil }
            return ItineraryStop(
                id: id,
                order: remote.order,
                day: remote.day,
                placeName: remote.placeName,
                address: remote.address,
                latitude: remote.latitude,
                longitude: remote.longitude,
                momentID: local?.momentID,
                photoData: local?.photoData,
                note: remote.note
            )
        }
    }

    private static func timeOfDay(_ time: String, on day: Date) -> Date? {
        guard let parsed = timeFormatter.date(from: time) else { return nil }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: parsed)
        return Calendar.current.date(
            bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day
        )
    }

    /// Local calendar day: the plan's day as the user picked it, independent of time zone.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
