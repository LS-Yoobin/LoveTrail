import Foundation
import Combine
import os

/// Step-by-step couple sync diagnostics (BAB-147), so a failed first profile sync shows
/// where it stopped: gate → media upload → push (PATCH) → pull (GET) → apply.
///
/// Messages are built only from step names, resource keys, HTTP statuses, server
/// reason codes, counts and booleans. Never pass ids, names, tokens, emails, media
/// paths or URLs. Visible in Console.app / Xcode with subsystem `LS.Covela`, category
/// `CoupleSync`; the last 100 events are also kept in memory (`recent`).
enum CoupleSyncLog {
    private static let logger = Logger(subsystem: "LS.Covela", category: "CoupleSync")
    nonisolated(unsafe) private(set) static var recent: [String] = []
    /// Total events logged so far (not capped like `recent`).
    nonisolated(unsafe) private(set) static var eventCount = 0

    static func event(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        eventCount += 1
        recent.append(message)
        if recent.count > 100 { recent.removeFirst(recent.count - 100) }
    }
}

extension Notification.Name {
    /// Posted on the main actor after pulled server changes were written to local
    /// storage. `userInfo["resources"]` is a `Set<String>` of resource keys.
    static let coupleSyncDidApplyRemoteChanges = Notification.Name("coupleSyncDidApplyRemoteChanges")
}

/// Client side of Couple Cloud Sync (BAB-66).
///
/// Local storage stays the source the UI reads from. A sync run:
/// 1. **Detects local changes** by comparing each resource's records to the snapshot
///    of what was last synced, and queues them in a persisted outbox.
/// 2. **Pushes** the outbox oldest first, sending `base_updated_at` so the server
///    answers 409 instead of letting a stale offline edit overwrite a newer one.
/// 3. **Pulls** each resource with its saved `since` cursor and applies changes.
///
/// It only runs while signed in and in the Together phase (`officialCouple`), so
/// Prelude and Breakup data never enter the outbox.
@MainActor
final class CoupleSyncEngine: ObservableObject {
    static let shared = CoupleSyncEngine()

    enum Trigger: String {
        case launch, foreground, localChange, retry, silentPush, pullToRefresh, accountChange, backgroundRefresh, manual, paired
    }

    enum Status: Equatable {
        case idle
        case syncing
        /// Network unreachable; the outbox is kept and retried.
        case offline
        /// Server says this account is not in a couple (403). Sync stays off until the
        /// next trigger after pairing.
        case notPaired
        case signedOut
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var pendingChangeCount = 0

    private var collections: [CoupleSyncCollection] = []
    private var documents: [CoupleSyncDocument] = []
    private var tasks: [CoupleSyncTask] = []

    /// `true` while the last run ended because the network was unreachable. Features
    /// that need the server right now (spending coins) check this.
    var isOffline: Bool { status == .offline }

    private var state = CoupleSyncState()
    private var stateScopeId: String?
    private var isRunning = false
    private var rerunRequested = false
    private var isApplyingRemote = false
    private var debounceTask: Task<Void, Never>?
    /// Syncs started by the debounce, tracked only so an account change can cancel them.
    private var debouncedSyncs: [UUID: Task<Void, Never>] = [:]
    /// After a failed run, `localChange` triggers wait until the scheduled retry instead
    /// of starting a new run every 1.5s (BAB-147 409 loop). Other triggers ignore it.
    private var autoSyncNotBefore: Date?
    /// Consecutive 409s per `resource/recordId` without a successful write in between.
    private var conflictStreaks: [String: Int] = [:]
    /// A write that keeps getting 409 after refetching is not retried in a tight loop:
    /// the run stops and normal backoff applies.
    static let maxConsecutiveConflicts = 3
    private var retryTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    private var accountObserver: NSObjectProtocol?

    private let api: CovelaAPIClient
    private let pageLimit = 100

    init(api: CovelaAPIClient = .shared) {
        self.api = api
        accountObserver = NotificationCenter.default.addObserver(
            forName: .covelaAccountDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleAccountChange()
            }
        }
    }

    // MARK: - Registration

    func register(_ collection: CoupleSyncCollection) {
        guard !collections.contains(where: { $0.key == collection.key }) else { return }
        collections.append(collection)
    }

    func register(_ document: CoupleSyncDocument) {
        guard !documents.contains(where: { $0.key == document.key }) else { return }
        documents.append(document)
    }

    func register(_ task: CoupleSyncTask) {
        guard !tasks.contains(where: { $0.key == task.key }) else { return }
        tasks.append(task)
    }

    // MARK: - Entry points

    /// Call after saving any synced data. Cheap; coalesces bursts of saves.
    /// Ignored while the engine itself is writing pulled changes.
    func localDidChange() {
        guard !isApplyingRemote else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.startDebouncedSync()
        }
    }

    /// Runs the debounced sync as its own task. Cancelling `debounceTask` (every new
    /// local save does) must only cancel the wait, never a run already talking to the
    /// server: that cancelled its requests (NSURLError -999), ended the run "offline"
    /// before the pull that refreshes `base_updated_at`, and the next run got 409 again,
    /// in a loop (BAB-147). An account change still cancels it (`handleAccountChange`).
    private func startDebouncedSync() {
        let id = UUID()
        debouncedSyncs[id] = Task { [weak self] in
            await self?.sync(trigger: .localChange)
            self?.debouncedSyncs[id] = nil
        }
    }

    /// Call once this account has just joined a couple (invite accepted on either side,
    /// or the server reported it already paired), after the local stage is saved.
    /// Syncs now instead of waiting for the debounced save trigger; that pending trigger
    /// is cancelled, and a run already in progress just schedules one follow-up run.
    func coupleDidPair() {
        debounceTask?.cancel()
        debounceTask = nil
        let stage = DataPersistenceManager.shared.loadCoupleProfile().relationshipStage
        CoupleSyncLog.event("paired signedIn=\(AuthService.shared.isSignedIn) stage=\(stage.rawValue)")
        Task { await sync(trigger: .paired) }
    }

    /// Runs a full detect → push → pull cycle. Safe to call repeatedly: a call made
    /// while a run is in progress schedules exactly one follow-up run.
    /// Returns `true` when the run completed without errors.
    @discardableResult
    func sync(trigger: Trigger) async -> Bool {
        guard isEnabled else {
            if trigger == .paired {
                CoupleSyncLog.event("sync skipped trigger=paired: not signed in or not officialCouple")
            }
            status = AuthService.shared.isSignedIn ? .idle : .signedOut
            forgetCoupleIfNoLongerTogether()
            return false
        }
        if isRunning {
            rerunRequested = true
            return false
        }
        if trigger == .localChange, let notBefore = autoSyncNotBefore, Date() < notBefore {
            // The last run failed and a retry is scheduled; the change is picked up then.
            CoupleSyncLog.event("sync deferred trigger=localChange: waiting for scheduled retry")
            return false
        }

        isRunning = true
        status = .syncing
        loadStateIfNeeded()
        defer { isRunning = false }

        var succeeded = false
        repeat {
            rerunRequested = false
            succeeded = await runCycle()
        } while rerunRequested && succeeded

        CoupleSyncLog.event("sync end trigger=\(trigger.rawValue) ok=\(succeeded) status=\(Self.describe(status))")
        if succeeded {
            consecutiveFailures = 0
            autoSyncNotBefore = nil
            lastSyncedAt = Date()
            status = .idle
        } else if status == .notPaired {
            // The couple changed on the server (breakup started, or dissolved).
            Task { await ArchiveService.shared.refreshFromServer() }
        } else {
            scheduleRetryIfNeeded()
        }
        return succeeded
    }

    /// Wipes sync bookkeeping for the active account. Call when local data is cleared.
    func resetLocalState() {
        state = CoupleSyncState()
        stateScopeId = DataPersistenceManager.shared.activeScopeId
        CoupleSyncStateStore.reset()
        SyncMediaRegistry.shared.reset()
        CoinLedgerSync.shared.reset()
        LettersSyncResource.shared.reset()
        pendingChangeCount = 0
    }

    // MARK: - Gate

    private var isEnabled: Bool {
        guard AuthService.shared.isSignedIn else { return false }
        return DataPersistenceManager.shared.loadCoupleProfile().relationshipStage == .officialCouple
    }

    /// After a breakup or step out, the snapshots describe a couple that no longer
    /// exists. Keeping them would let a later pairing (possibly with someone else)
    /// receive this account's old records as "local edits". Forget them instead.
    private func forgetCoupleIfNoLongerTogether() {
        guard AuthService.shared.isSignedIn else { return }
        loadStateIfNeeded()
        guard state != CoupleSyncState() else { return }
        resetLocalState()
    }

    private func handleAccountChange() {
        debounceTask?.cancel()
        // A run for the previous account must not continue with the new one's data.
        debouncedSyncs.values.forEach { $0.cancel() }
        debouncedSyncs.removeAll()
        retryTask?.cancel()
        consecutiveFailures = 0
        autoSyncNotBefore = nil
        conflictStreaks.removeAll()
        stateScopeId = nil
        loadStateIfNeeded()
        Task { await sync(trigger: .accountChange) }
    }

    private func loadStateIfNeeded() {
        let scope = DataPersistenceManager.shared.activeScopeId
        guard stateScopeId != scope else { return }
        state = CoupleSyncStateStore.load()
        stateScopeId = scope
        pendingChangeCount = state.outbox.count
    }

    private func persistState() {
        CoupleSyncStateStore.save(state)
        pendingChangeCount = state.outbox.count
    }

    // MARK: - Cycle

    private enum StepResult {
        case ok
        case stop(Status)
    }

    private func runCycle() async -> Bool {
        guard let token = AuthService.shared.authToken else {
            status = .signedOut
            return false
        }

        for handler in mediaHandlers {
            do {
                try await handler.uploadPendingMedia()
            } catch {
                CoupleSyncLog.event("media upload offline; cycle stopped before push")
                status = .offline
                return false
            }
        }

        detectLocalChanges()

        if case .stop(let stopStatus) = await pushOutbox(token: token) {
            status = stopStatus
            return false
        }

        var changedResources = Set<String>()
        for collection in collections {
            switch await pull(collection, token: token, changed: &changedResources) {
            case .ok: continue
            case .stop(let stopStatus):
                notifyApplied(changedResources)
                status = stopStatus
                return false
            }
        }
        for document in documents {
            switch await pull(document, token: token, changed: &changedResources) {
            case .ok: continue
            case .stop(let stopStatus):
                notifyApplied(changedResources)
                status = stopStatus
                return false
            }
        }
        notifyApplied(changedResources)

        for task in tasks {
            switch await task.perform(token: token) {
            case .ok: continue
            case .changed: notifyApplied([task.key])
            case .offline:
                status = .offline
                return false
            case .notPaired:
                status = .notPaired
                return false
            }
        }

        var downloadedResources = Set<String>()
        for handler in mediaHandlers where await handler.downloadPendingMedia() {
            if let key = (handler as? CoupleSyncCollection)?.key ?? (handler as? CoupleSyncDocument)?.key {
                downloadedResources.insert(key)
            }
        }
        notifyApplied(downloadedResources)

        // A document adopted from the server on first sync, or a pulled change that a
        // resource normalised locally, can leave new local differences; push them now.
        detectLocalChanges()
        if !state.outbox.isEmpty, case .stop(let stopStatus) = await pushOutbox(token: token) {
            status = stopStatus
            return false
        }
        return true
    }

    // MARK: - Detect

    private func detectLocalChanges() {
        for collection in collections {
            let local = collection.localRecords()
            var snapshot = state.snapshots[collection.key] ?? [:]
            for (recordId, body) in local {
                let canonical = SyncJSON.canonical(body)
                guard snapshot[recordId] != canonical else { continue }
                state.enqueue(resource: collection.key, recordId: recordId, operation: .upsert, body: body)
                snapshot[recordId] = canonical
            }
            let missing = snapshot.keys.filter { local[$0] == nil }
            if Self.looksLikeMassDeletion(missing: missing.count, known: snapshot.count) {
                // Safety valve: a large share of records vanishing at once is far more
                // likely a local bug (a stale in-memory copy saved over the file, a
                // failed load) than the user deleting them. Never mirror that to the
                // partner; hold the deletes and keep the snapshot until it resolves.
                print("[CoupleSync] holding \(missing.count)/\(snapshot.count) deletes for \(collection.key)")
            } else {
                for recordId in missing {
                    state.enqueue(resource: collection.key, recordId: recordId, operation: .delete, body: nil)
                    snapshot.removeValue(forKey: recordId)
                }
            }
            state.snapshots[collection.key] = snapshot
        }

        for document in documents {
            // A document is only pushed after its first pull decided who wins.
            guard let snapshot = state.snapshots[document.key]?[CoupleSyncState.documentRecordId],
                  let body = document.localBody() else { continue }
            let canonical = SyncJSON.canonical(body)
            guard snapshot != canonical else { continue }
            state.enqueue(resource: document.key, recordId: CoupleSyncState.documentRecordId, operation: .write, body: body)
            state.snapshots[document.key, default: [:]][CoupleSyncState.documentRecordId] = canonical
        }
        persistState()
    }

    /// More than 10 records and more than half of everything known, in one pass.
    static func looksLikeMassDeletion(missing: Int, known: Int) -> Bool {
        missing > 10 && missing * 2 > known
    }

    // MARK: - Push

    private func pushOutbox(token: String) async -> StepResult {
        for entry in state.outbox {
            guard state.outbox.contains(where: { $0.id == entry.id }) else { continue }
            let result = await send(entry, token: token)
            if case .stop = result {
                persistState()
                return result
            }
        }
        persistState()
        return .ok
    }

    private func send(_ entry: SyncOutboxEntry, token: String) async -> StepResult {
        let basePath = resourcePath(for: entry.resource)
        guard let basePath else {
            state.removeOutboxEntry(entry.id)
            return .ok
        }

        var body: [String: Any] = entry.body
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        if let base = state.serverUpdatedAt[entry.resource]?[entry.recordId] {
            body["base_updated_at"] = base
        }

        let method: String
        let path: String
        switch entry.operation {
        case .upsert:
            method = "POST"
            path = basePath
            body["id"] = entry.recordId
        case .delete:
            method = "DELETE"
            path = "\(basePath)/\(entry.recordId)"
        case .write:
            method = documents.first(where: { $0.key == entry.resource })?.writeMethod ?? "PUT"
            path = basePath
        }

        let response: CovelaAPIClient.RawResponse
        do {
            response = try await api.send(method: method, path: path, body: body, token: token)
        } catch {
            CoupleSyncLog.event("push \(entry.resource) \(method) offline")
            return .stop(.offline)
        }
        CoupleSyncLog.event("push \(entry.resource) \(method) status=\(response.status) reason=\(response.failureReason ?? "-") attempt=\(entry.attempts + 1)")

        switch response.status {
        case 200..<300:
            conflictStreaks["\(entry.resource)/\(entry.recordId)"] = nil
            state.removeOutboxEntry(entry.id)
            if let updatedAt = response.jsonObject()?["updated_at"] as? String {
                state.serverUpdatedAt[entry.resource, default: [:]][entry.recordId] = updatedAt
            }
            return .ok
        case 404 where entry.operation == .delete:
            // Never reached the server (created and deleted offline); nothing to do.
            state.removeOutboxEntry(entry.id)
            state.serverUpdatedAt[entry.resource]?.removeValue(forKey: entry.recordId)
            return .ok
        case 409 where response.failureReason == "couple_archived":
            // The partner ended the relationship: the server refuses writes during the
            // archive window. Keep nothing queued; let ArchiveService switch phases.
            state.outbox.removeAll()
            return .stop(.notPaired)
        case 409:
            // The partner changed this record after the version we edited. Their newer
            // version wins: drop our change and take theirs.
            state.removeOutboxEntry(entry.id)
            let streakKey = "\(entry.resource)/\(entry.recordId)"
            let streak = (conflictStreaks[streakKey] ?? 0) + 1
            conflictStreaks[streakKey] = streak
            let refetched = await refetch(entry, token: token)
            if case .stop = refetched { return refetched }
            if streak >= Self.maxConsecutiveConflicts {
                CoupleSyncLog.event("push \(entry.resource) conflict \(streak)x in a row; backing off")
                return .stop(.failed("Repeated conflict"))
            }
            return .ok
        case 401:
            return .stop(.signedOut)
        case 403:
            return .stop(.notPaired)
        case 400, 404, 422:
            // The server will never accept this change; drop it so it can't block the queue.
            print("[CoupleSync] dropping \(entry.operation.rawValue) \(entry.resource)/\(entry.recordId): \(response.status) \(response.failureReason ?? "")")
            state.removeOutboxEntry(entry.id)
            return .ok
        default:
            if let index = state.outbox.firstIndex(where: { $0.id == entry.id }) {
                state.outbox[index].attempts += 1
            }
            return .stop(.failed("Server error \(response.status)"))
        }
    }

    /// After a 409, fetches the server's current record and applies it locally.
    private func refetch(_ entry: SyncOutboxEntry, token: String) async -> StepResult {
        guard let basePath = resourcePath(for: entry.resource) else { return .ok }
        let path = entry.operation == .write ? basePath : "\(basePath)/\(entry.recordId)"
        let response: CovelaAPIClient.RawResponse
        do {
            response = try await api.send(method: "GET", path: path, token: token)
        } catch {
            return .stop(.offline)
        }
        guard response.isSuccess, let dto = response.jsonObject() else {
            if response.status == 403 { return .stop(.notPaired) }
            return .ok
        }

        var changed = Set<String>()
        if let collection = collections.first(where: { $0.key == entry.resource }) {
            apply([dto], to: collection, changed: &changed)
        } else if let document = documents.first(where: { $0.key == entry.resource }) {
            // The refetched version is the new base. Without it, a run that stops before
            // its pull (offline, cancelled) re-sends the stale base and gets 409 again.
            if let updatedAt = dto["updated_at"] as? String {
                state.serverUpdatedAt[document.key, default: [:]][CoupleSyncState.documentRecordId] = updatedAt
            }
            applyServerOwnedFields(dto, to: document)
            apply(dto, to: document)
        }
        notifyApplied(changed)
        return .ok
    }

    private var mediaHandlers: [CoupleSyncMediaHandling] {
        collections.compactMap { $0 as? CoupleSyncMediaHandling }
            + documents.compactMap { $0 as? CoupleSyncMediaHandling }
    }

    private func resourcePath(for key: String) -> String? {
        collections.first(where: { $0.key == key })?.path
            ?? documents.first(where: { $0.key == key })?.path
    }

    // MARK: - Pull

    private func pull(_ collection: CoupleSyncCollection, token: String, changed: inout Set<String>) async -> StepResult {
        var hasMore = true
        while hasMore {
            var query = [URLQueryItem(name: "limit", value: String(pageLimit))]
            if let cursor = state.cursors[collection.key] {
                query.append(URLQueryItem(name: "since", value: cursor))
            }

            let response: CovelaAPIClient.RawResponse
            do {
                response = try await api.send(method: "GET", path: collection.path, query: query, token: token)
            } catch {
                return .stop(.offline)
            }
            switch response.status {
            case 200..<300: break
            case 401: return .stop(.signedOut)
            case 403: return .stop(.notPaired)
            default: return .stop(.failed("Server error \(response.status)"))
            }

            guard let page = response.jsonObject(),
                  let items = page["items"] as? [[String: Any]] else {
                return .stop(.failed("Unexpected sync response"))
            }
            apply(items, to: collection, changed: &changed)

            if let next = page["next_since"] as? String {
                state.cursors[collection.key] = next
            }
            hasMore = (page["has_more"] as? Bool) ?? false
            persistState()
        }
        return .ok
    }

    private func apply(_ items: [[String: Any]], to collection: CoupleSyncCollection, changed: inout Set<String>) {
        var upserts: [[String: Any]] = []
        var deletedIds: [String] = []
        var snapshot = state.snapshots[collection.key] ?? [:]

        for item in items {
            guard let recordId = (item["id"] as? String)?.lowercased() else { continue }
            // A local change for this record is still queued. It is pushed with its
            // base timestamp; if the server version is newer, the push gets a 409 and
            // the server version is fetched then.
            if state.hasPendingChange(resource: collection.key, recordId: recordId) { continue }

            if let deletedAt = item["deleted_at"] as? String, !deletedAt.isEmpty {
                snapshot.removeValue(forKey: recordId)
                deletedIds.append(recordId)
                state.serverUpdatedAt[collection.key]?.removeValue(forKey: recordId)
                continue
            }

            if let updatedAt = item["updated_at"] as? String {
                state.serverUpdatedAt[collection.key, default: [:]][recordId] = updatedAt
            }
            guard let comparable = collection.comparableBody(fromServer: item) else { continue }
            let canonical = SyncJSON.canonical(comparable)
            guard snapshot[recordId] != canonical else { continue }
            snapshot[recordId] = canonical
            upserts.append(item)
        }

        guard !upserts.isEmpty || !deletedIds.isEmpty else {
            state.snapshots[collection.key] = snapshot
            return
        }
        isApplyingRemote = true
        collection.applyRemote(upserts: upserts, deletedIds: deletedIds)
        isApplyingRemote = false

        // Snapshot what is now stored locally, so local-only normalisation is not
        // mistaken for a new edit. A record the resource chose not to store is
        // forgotten rather than remembered, so it can never be sent as a delete.
        let local = collection.localRecords()
        for item in upserts {
            guard let recordId = (item["id"] as? String)?.lowercased() else { continue }
            if let body = local[recordId] {
                snapshot[recordId] = SyncJSON.canonical(body)
            } else {
                snapshot.removeValue(forKey: recordId)
            }
        }
        state.snapshots[collection.key] = snapshot
        // Notify synchronously, before the next network await: view models that hold
        // their own copy of the data (HomeViewModel.moments) must reload before they
        // can save a stale copy, which would read as a local delete.
        notifyApplied([collection.key])
    }

    private func pull(_ document: CoupleSyncDocument, token: String, changed: inout Set<String>) async -> StepResult {
        let response: CovelaAPIClient.RawResponse
        do {
            response = try await api.send(method: "GET", path: document.path, token: token)
        } catch {
            CoupleSyncLog.event("pull \(document.key) offline")
            return .stop(.offline)
        }
        CoupleSyncLog.event("pull \(document.key) status=\(response.status) firstSync=\(state.snapshots[document.key]?[CoupleSyncState.documentRecordId] == nil)")
        switch response.status {
        case 200..<300: break
        case 401: return .stop(.signedOut)
        case 403: return .stop(.notPaired)
        case 404: return .ok
        default: return .stop(.failed("Server error \(response.status)"))
        }
        guard let dto = response.jsonObject() else { return .ok }

        applyServerOwnedFields(dto, to: document)

        // Proof that this phone really belongs to a couple on the server. Only then may a
        // later "couple dissolved" answer clear the Cove (see ArchiveService).
        if let coupleProfileId = dto["couple_profile_id"] as? String, !coupleProfileId.isEmpty {
            DataPersistenceManager.shared.saveServerCoupleProfileId(coupleProfileId)
        }

        let recordId = CoupleSyncState.documentRecordId
        if let updatedAt = dto["updated_at"] as? String {
            state.serverUpdatedAt[document.key, default: [:]][recordId] = updatedAt
        }
        guard !state.hasPendingChange(resource: document.key, recordId: recordId) else { return .ok }

        let isFirstSync = state.snapshots[document.key]?[recordId] == nil
        if isFirstSync {
            if document.serverHasContent(dto) {
                apply(dto, to: document)
            } else {
                // Server is empty: our copy becomes the shared one. An empty snapshot
                // makes the next detect step queue the upload.
                state.snapshots[document.key, default: [:]][recordId] = ""
            }
            persistState()
            return .ok
        }

        let canonical = SyncJSON.canonical(document.comparableBody(fromServer: dto))
        guard state.snapshots[document.key]?[recordId] != canonical else { return .ok }
        apply(dto, to: document)
        persistState()
        return .ok
    }

    private func apply(_ dto: [String: Any], to document: CoupleSyncDocument) {
        isApplyingRemote = true
        document.applyRemote(dto)
        isApplyingRemote = false
        notifyApplied([document.key])
        // Snapshot the *server* form. Fields the server holds but this device has not
        // applied (e.g. this user's own nickname when adopting the partner's profile on
        // first sync) then differ from `localBody()` and are pushed on the next detect.
        // Resources must make `localBody()` match the server form for applied fields.
        let snapshot = SyncJSON.canonical(document.comparableBody(fromServer: dto))
        state.snapshots[document.key, default: [:]][CoupleSyncState.documentRecordId] = snapshot
    }

    /// Server-owned fields (the partner's profile entry) are applied on every successful
    /// pull, outside snapshot change detection, so they can never trigger a push.
    private func applyServerOwnedFields(_ dto: [String: Any], to document: CoupleSyncDocument) {
        guard let owned = document as? CoupleSyncServerOwnedFields else { return }
        isApplyingRemote = true
        let changed = owned.applyServerOwnedFields(dto)
        isApplyingRemote = false
        if changed { notifyApplied([document.key]) }
    }

    private static func describe(_ status: Status) -> String {
        switch status {
        case .idle: return "idle"
        case .syncing: return "syncing"
        case .offline: return "offline"
        case .notPaired: return "notPaired"
        case .signedOut: return "signedOut"
        case .failed(let message): return "failed(\(message))"
        }
    }

    private func notifyApplied(_ resources: Set<String>) {
        guard !resources.isEmpty else { return }
        NotificationCenter.default.post(
            name: .coupleSyncDidApplyRemoteChanges,
            object: nil,
            userInfo: ["resources": resources]
        )
    }

    // MARK: - Retry

    /// Automatic retries after server errors (5xx, e.g. the backend's VersionError when
    /// both partners PATCH the profile at once) stop after this many in a row. The
    /// outbox is kept; the next launch, foreground, pull to refresh or local edit tries
    /// again. Offline retries are not capped.
    static let maxAutomaticServerErrorRetries = 6

    /// 15s, 30s, 60s … capped at 10 minutes.
    static func retryDelay(afterFailures failures: Int) -> TimeInterval {
        min(600, 15 * pow(2, Double(min(max(failures, 1) - 1, 6))))
    }

    static func shouldRetryAutomatically(afterFailures failures: Int, isServerError: Bool) -> Bool {
        !isServerError || failures <= maxAutomaticServerErrorRetries
    }

    private func scheduleRetryIfNeeded() {
        let isServerError: Bool = { if case .failed = status { return true } else { return false } }()
        guard status == .offline || isServerError else { return }
        consecutiveFailures += 1
        guard Self.shouldRetryAutomatically(afterFailures: consecutiveFailures, isServerError: isServerError) else {
            retryTask?.cancel()
            retryTask = nil
            autoSyncNotBefore = Date().addingTimeInterval(Self.retryDelay(afterFailures: consecutiveFailures))
            CoupleSyncLog.event("auto retry stopped after \(consecutiveFailures - 1) server errors; outbox kept for the next trigger")
            return
        }
        let delay = Self.retryDelay(afterFailures: consecutiveFailures)
        autoSyncNotBefore = Date().addingTimeInterval(delay)
        CoupleSyncLog.event("retry scheduled in \(Int(delay))s failures=\(consecutiveFailures)")
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.sync(trigger: .retry)
        }
    }
}
