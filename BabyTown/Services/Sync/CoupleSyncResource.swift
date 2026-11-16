import Foundation

/// A list of couple records synced through `GET <path>?since=` and
/// `POST <path>` (upsert by id) / `DELETE <path>/:id` (soft delete).
///
/// Resources never talk to the network. They describe local records as JSON
/// bodies and apply server changes to local storage; `CoupleSyncEngine` does the rest.
///
/// Change detection is snapshot based: the engine remembers the last body it synced
/// for each record and compares it to `localRecords()`. A resource therefore only
/// needs to call `CoupleSyncEngine.shared.localDidChange()` after saving, not track
/// individual edits.
@MainActor
protocol CoupleSyncCollection: AnyObject {
    /// Stable bookkeeping key, e.g. `"special-dates"`.
    var key: String { get }
    /// API path relative to `CovelaAPIConfig.baseURL`, e.g. `"couple/special-dates"`.
    var path: String { get }

    /// Local records eligible for sync, keyed by server id (`SyncIDCodec.objectId`).
    /// Bodies contain only server-known fields, never `id` or `base_updated_at`.
    /// Must be deterministic: the same local state must produce the same bodies.
    func localRecords() -> [String: [String: Any]]

    /// The server DTO reduced to the same shape as `localRecords()` bodies, so the
    /// engine can tell whether a pulled record differs from what it last synced.
    /// Return `nil` to ignore a server record entirely.
    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]?

    /// Writes server changes into local storage. Must keep local-only fields
    /// (pins, cached media, …) on records that already exist locally.
    func applyRemote(upserts: [[String: Any]], deletedIds: [String])
}

/// A single couple document synced with `GET <path>` and `PUT`/`PATCH <path>`
/// (couple profile, pet state, pet room, tricks).
@MainActor
protocol CoupleSyncDocument: AnyObject {
    var key: String { get }
    var path: String { get }
    /// `"PUT"` or `"PATCH"`.
    var writeMethod: String { get }

    /// The local document as a server body, or `nil` when there is nothing to sync yet.
    func localBody() -> [String: Any]?

    /// The server DTO reduced to the `localBody()` shape.
    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]

    /// Whether the server copy holds real content. On the first sync of a document the
    /// server copy wins when it has content (the partner who synced first keeps theirs);
    /// otherwise the local copy is uploaded.
    func serverHasContent(_ dto: [String: Any]) -> Bool

    func applyRemote(_ dto: [String: Any])
}

/// Optional media step for a resource (BAB-67 pipeline).
///
/// Uploads run **before** change detection, so a record's body can include the
/// uploaded `*_path`; a record whose media is not uploaded yet should leave the path
/// out (or keep the previous one) rather than block. Downloads run after pulls.
@MainActor
protocol CoupleSyncMediaHandling: AnyObject {
    /// Uploads local media that has no remote path yet. Throw
    /// `SyncMediaTransfer.TransferError.offline` to stop the cycle; skip (don't throw)
    /// media the server rejects so one bad file can't block sync.
    func uploadPendingMedia() async throws

    /// Downloads partner media referenced by pulled records but missing locally.
    /// Returns `true` when anything was written, so views refresh.
    func downloadPendingMedia() async -> Bool
}

/// A sync step that doesn't fit the list/document model, e.g. the coin ledger.
/// Runs after pulls in every cycle.
@MainActor
protocol CoupleSyncTask: AnyObject {
    var key: String { get }
    func perform(token: String) async -> CoupleSyncTaskOutcome
}

enum CoupleSyncTaskOutcome {
    case ok
    /// Something changed locally; views showing the task's `key` should reload.
    case changed
    case offline
    case notPaired
}

/// Shared JSON helpers for resources.
enum SyncJSON {
    /// ISO 8601 with milliseconds, matching the server's `Date.toISOString()`.
    static func string(from date: Date) -> String {
        let rounded = Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1000).rounded() / 1000)
        return formatter.string(from: rounded)
    }

    static func date(from value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return formatter.date(from: string) ?? plainFormatter.date(from: string)
    }

    static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    static func bool(_ value: Any?) -> Bool? {
        (value as? NSNumber)?.boolValue
    }

    /// Drops `NSNull` / nil-like values so local and server bodies compare equal when
    /// one side omits an empty optional and the other sends `null`.
    static func compacted(_ body: [String: Any?]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in body {
            guard let value, !(value is NSNull) else { continue }
            result[key] = value
        }
        return result
    }

    /// Stable text form of a body, used to compare snapshots.
    static func canonical(_ body: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
