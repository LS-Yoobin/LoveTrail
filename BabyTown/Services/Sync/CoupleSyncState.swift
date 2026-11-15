import Foundation

/// One local change waiting to reach the server. Survives app kill (persisted with
/// `CoupleSyncState`). At most one entry exists per (resource, record): a newer
/// change replaces the older one in place.
struct SyncOutboxEntry: Codable, Identifiable, Equatable {
    enum Operation: String, Codable {
        /// `POST <path>` with `id`; creates or updates.
        case upsert
        /// `DELETE <path>/:id`.
        case delete
        /// `PUT`/`PATCH <path>` for a single document.
        case write
    }

    let id: UUID
    let resource: String
    let recordId: String
    var operation: Operation
    /// JSON body (without `id` / `base_updated_at`, which are added at send time).
    var body: Data?
    var enqueuedAt: Date
    var attempts: Int
}

/// Per-account sync bookkeeping, stored at `CovelaUserData/<scope>/couple_sync_state.json`.
struct CoupleSyncState: Codable, Equatable {
    static let documentRecordId = "_doc"

    var outbox: [SyncOutboxEntry] = []
    /// resource → `next_since` from the last completed pull.
    var cursors: [String: String] = [:]
    /// resource → record id → canonical body last synced (or queued). The basis for
    /// change detection; a record missing locally but present here was deleted locally.
    var snapshots: [String: [String: String]] = [:]
    /// resource → record id → server `updated_at`, sent as `base_updated_at` so the
    /// server can reject a stale write with 409 instead of silently overwriting.
    var serverUpdatedAt: [String: [String: String]] = [:]

    func hasPendingChange(resource: String, recordId: String) -> Bool {
        outbox.contains { $0.resource == resource && $0.recordId == recordId }
    }

    mutating func enqueue(resource: String, recordId: String, operation: SyncOutboxEntry.Operation, body: [String: Any]?) {
        let data = body.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) }
        if let index = outbox.firstIndex(where: { $0.resource == resource && $0.recordId == recordId }) {
            outbox[index].operation = operation
            outbox[index].body = data
            outbox[index].attempts = 0
            return
        }
        outbox.append(SyncOutboxEntry(
            id: UUID(),
            resource: resource,
            recordId: recordId,
            operation: operation,
            body: data,
            enqueuedAt: Date(),
            attempts: 0
        ))
    }

    mutating func removeOutboxEntry(_ entryId: UUID) {
        outbox.removeAll { $0.id == entryId }
    }
}

/// Loads and saves `CoupleSyncState` for the active account.
@MainActor
enum CoupleSyncStateStore {
    private static let fileName = "couple_sync_state.json"

    private static var fileURL: URL {
        DataPersistenceManager.shared.currentScopeDirectory.appendingPathComponent(fileName)
    }

    static func load() -> CoupleSyncState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(CoupleSyncState.self, from: data) else {
            return CoupleSyncState()
        }
        return state
    }

    static func save(_ state: CoupleSyncState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Forgets all sync bookkeeping for the active account. Required whenever local
    /// data is wiped: otherwise every remembered record would look locally deleted and
    /// the next sync would delete it on the server too.
    static func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
