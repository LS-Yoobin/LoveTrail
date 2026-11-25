import Foundation

// BAB-147 regression tests. Runs the real CoupleSyncEngine and
// CoupleProfileSyncResource against FakeServer. See run.sh.

URLProtocol.registerClass(FakeMediaURLProtocol.self)

let root = FileManager.default.temporaryDirectory.appendingPathComponent("covela-sync-tests-\(UUID().uuidString)")
var failures = 0
var testIndex = 0

func check(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        failures += 1
        print("    FAIL (line \(line)): \(message)")
    }
}

/// One phone: its local data, its own engine and its own profile resource.
final class Phone {
    let device: Device
    var engine: CoupleSyncEngine
    var notifiedProfile = 0
    /// Like HomeView: a profile notification leads to a local save → localDidChange().
    var savesOnProfileNotify = false
    private var observer: NSObjectProtocol?

    init(_ name: String, nickname: String?, extra: (CoupleSyncEngine) -> Void = { _ in }) {
        device = Device(userId: "\(name)-\(testIndex)", root: root)
        device.userNickname = nickname
        device.profile.relationshipStage = .officialCouple
        engine = CoupleSyncEngine(api: .shared)
        engine.register(CoupleProfileSyncResource())
        extra(engine)
        FakeServer.shared.members.insert(device.userId)
        observer = NotificationCenter.default.addObserver(forName: .coupleSyncDidApplyRemoteChanges, object: nil, queue: nil) { [weak self] note in
            guard let self, Device.current === self.device,
                  (note.userInfo?["resources"] as? Set<String>)?.contains("profile") == true else { return }
            MainActor.assumeIsolated {
                self.notifiedProfile += 1
                if self.savesOnProfileNotify { self.engine.localDidChange() }
            }
        }
    }

    var id: String { device.userId }

    /// App relaunch: a fresh engine and resource over the same on-disk state.
    func relaunch() {
        engine = CoupleSyncEngine(api: .shared)
        engine.register(CoupleProfileSyncResource())
    }

    @discardableResult
    func sync() async -> Bool {
        Device.current = device
        return await engine.sync(trigger: .manual)
    }

    /// What `DataPersistenceManager.saveUserAvatar(nil)` does: the user removed it.
    func removeOwnPhoto() { device.ownAvatar = nil; device.ownAvatarRemovalPending = true }
    /// What `saveUserAvatar(image)` does.
    func setOwnPhoto(_ data: Data) { device.ownAvatar = data; device.ownAvatarRemovalPending = false }

    var partnerNickname: String? { device.syncedPartnerNickname }
    var partnerAvatar: Data? { device.syncedPartnerAvatar }
}

func test(_ name: String, _ body: () async -> Void) async {
    testIndex += 1
    FakeServer.shared = FakeServer()
    FakeServer.media = [:]
    let before = failures
    await body()
    print(failures == before ? "PASS  \(name)" : "FAIL  \(name)")
}

/// Fresh pairing in the order the app produces it: the invitee (B) accepts and syncs
/// first, then the inviter (A) detects acceptance and syncs.
func pair(aAvatar: Data? = nil, bAvatar: Data? = nil) async -> (Phone, Phone) {
    let a = Phone("a", nickname: "Ari")
    let b = Phone("b", nickname: "Bo")
    a.device.ownAvatar = aAvatar
    b.device.ownAvatar = bAvatar
    await b.sync()
    await a.sync()
    return (a, b)
}

let photoA1 = Data("photo-a-1".utf8), photoA2 = Data("photo-a-2".utf8)
let photoB1 = Data("photo-b-1".utf8), photoB2 = Data("photo-b-2".utf8)

// 1, 6: first pairing on an empty server profile (no note, no mood).
await test("1/6 first pairing with empty note and mood: both entries reach the server") {
    let (a, b) = await pair()
    check(FakeServer.shared.note.isEmpty && FakeServer.shared.mood.isEmpty, "server note/mood should stay empty")
    check(FakeServer.shared.entries[a.id]?["nickname"] as? String == "Ari", "A's nickname on server")
    check(FakeServer.shared.entries[b.id]?["nickname"] as? String == "Bo", "B's nickname on server")
}

// 2: A (synced second) sees B already on its very first sync.
await test("2 inviter A shows B's nickname and photo after pairing") {
    let (a, _) = await pair(bAvatar: photoB1)
    check(a.partnerNickname == "Bo", "A partner nickname = \(a.partnerNickname ?? "nil")")
    check(a.partnerAvatar == photoB1, "A should have B's photo")
}

// 3: B (synced first, server was empty) sees A on its next sync (launch/foreground).
await test("3 invitee B shows A's nickname and photo after its next sync") {
    let (a, b) = await pair(aAvatar: photoA1)
    _ = a
    await b.sync()
    check(b.partnerNickname == "Ari", "B partner nickname = \(b.partnerNickname ?? "nil")")
    check(b.partnerAvatar == photoA1, "B should have A's photo")
}

// 4, 5: profile edits without any note/mood change reach the partner, both ways.
await test("4/5 nickname and photo changes propagate both ways without note/mood changes") {
    let (a, b) = await pair(aAvatar: photoA1, bAvatar: photoB1)
    await b.sync()
    a.device.userNickname = "Ari2"; a.device.ownAvatar = photoA2
    await a.sync(); await b.sync()
    check(b.partnerNickname == "Ari2", "B sees A rename: \(b.partnerNickname ?? "nil")")
    check(b.partnerAvatar == photoA2, "B sees A's new photo")
    b.device.userNickname = "Bo2"; b.device.ownAvatar = photoB2
    await b.sync(); await a.sync()
    check(a.partnerNickname == "Bo2", "A sees B rename: \(a.partnerNickname ?? "nil")")
    check(a.partnerAvatar == photoB2, "A sees B's new photo")
    check(FakeServer.shared.note.isEmpty && FakeServer.shared.mood.isEmpty, "note/mood untouched")
}

await test("partner photo removal clears the stale local copy") {
    let (a, b) = await pair(aAvatar: photoA1)
    await b.sync()
    check(b.partnerAvatar == photoA1, "precondition: B has A's photo")
    a.removeOwnPhoto()
    await a.sync(); await b.sync()
    check(b.partnerAvatar == nil, "B should drop A's removed photo")
    a.setOwnPhoto(photoA2)
    await a.sync(); await b.sync()
    check(b.partnerAvatar == photoA2, "B should get A's photo again after re-adding")
}

await test("own nickname and photo are never overwritten by the partner's") {
    let (a, b) = await pair(aAvatar: photoA1, bAvatar: photoB1)
    await b.sync(); await a.sync()
    check(a.device.userNickname == "Ari" && a.device.ownAvatar == photoA1, "A's own data intact")
    check(b.device.userNickname == "Bo" && b.device.ownAvatar == photoB1, "B's own data intact")
}

// 7: B has a local change still waiting while A changes their profile.
await test("7 pending local change: partner data still arrives, local change retried") {
    let (a, b) = await pair()
    await b.sync()
    // B edits the shared note while the server rejects writes (5xx), so it stays queued.
    FakeServer.shared.failNextPatches = 1
    b.device.profile.profileNote = "hello"
    let ok = await b.sync()
    check(!ok, "B's sync should report failure while PATCH fails")
    check(b.engine.pendingChangeCount == 1, "B's note change should stay queued")
    // Meanwhile A renames. B's queued PATCH now carries a stale base → 409 → refetch.
    a.device.userNickname = "Ari3"
    await a.sync()
    await b.sync()
    check(b.partnerNickname == "Ari3", "B sees A rename despite its pending change: \(b.partnerNickname ?? "nil")")
    check(b.engine.pendingChangeCount == 0, "outbox drained")
}

// 8: repeated syncs are idempotent.
await test("8 repeated syncs send no extra PATCH, upload or notification") {
    let (a, b) = await pair(aAvatar: photoA1, bAvatar: photoB1)
    await b.sync(); await a.sync()
    let patches = FakeServer.shared.count("PATCH", "couple/profile")
    let mediaCount = FakeServer.media.count
    let notified = (a.notifiedProfile, b.notifiedProfile)
    for _ in 0..<5 { await a.sync(); await b.sync() }
    check(FakeServer.shared.count("PATCH", "couple/profile") == patches, "PATCH count grew: \(patches) → \(FakeServer.shared.count("PATCH", "couple/profile"))")
    check(FakeServer.media.count == mediaCount, "avatars re-uploaded")
    check(a.notifiedProfile == notified.0 && b.notifiedProfile == notified.1, "profile notifications on no-op syncs")
    check(a.engine.pendingChangeCount == 0 && b.engine.pendingChangeCount == 0, "outbox empty")
}

await test("profile change notifies the UI exactly when partner data changed") {
    let (a, b) = await pair()
    await b.sync()
    let before = b.notifiedProfile
    a.device.userNickname = "Ari4"
    await a.sync(); await b.sync()
    check(b.notifiedProfile > before, "B should be notified of A's rename")
}

await test("401/403 answers apply nothing") {
    let (a, b) = await pair()
    a.device.userNickname = "Ari5"
    await a.sync()
    FakeServer.shared.forcedProfileStatus = 403
    await b.sync()
    check(b.partnerNickname == nil, "403 must not apply partner data: \(b.partnerNickname ?? "nil")")
    check(b.engine.status == .notPaired, "status notPaired")
    FakeServer.shared.forcedProfileStatus = 401
    await b.sync()
    check(b.partnerNickname == nil, "401 must not apply partner data")
    check(b.engine.status == .signedOut, "status signedOut")
    FakeServer.shared.forcedProfileStatus = nil
    await b.sync()
    check(b.partnerNickname == "Ari5", "recovers once the server answers 200")
}

await test("existing paired accounts (already-synced snapshots) recover on next sync") {
    // Both phones fully paired under the old behaviour: snapshots exist, nothing pending.
    let (a, b) = await pair()
    await b.sync()
    // Simulate the BAB-147 state: partner data never stored locally.
    a.device.syncedPartnerNickname = nil
    b.device.syncedPartnerNickname = nil
    await a.sync(); await b.sync()
    check(a.partnerNickname == "Bo" && b.partnerNickname == "Ari", "recovered: A→\(a.partnerNickname ?? "nil") B→\(b.partnerNickname ?? "nil")")
}

await test("coupleDidPair syncs immediately and replaces the debounced save trigger") {
    let a = Phone("a", nickname: "Ari")
    await a.sync()
    let b = Phone("b", nickname: "Bo")
    Device.current = b.device
    // What the pairing paths do: saveCoupleProfile (→ localDidChange) then coupleDidPair.
    b.engine.localDidChange()
    b.engine.coupleDidPair()
    b.engine.coupleDidPair()   // a second caller while the first run is in flight
    try? await Task.sleep(nanoseconds: 300_000_000)
    check(FakeServer.shared.count("GET", "couple/profile", user: b.id) >= 1, "B synced right away")
    check(FakeServer.shared.entries[b.id] != nil, "B's profile uploaded right away")
    check(b.partnerNickname == "Ari", "B already shows A: \(b.partnerNickname ?? "nil")")
    let gets = FakeServer.shared.count("GET", "couple/profile", user: b.id)
    try? await Task.sleep(nanoseconds: 2_000_000_000)   // past the 1.5s debounce
    check(FakeServer.shared.count("GET", "couple/profile", user: b.id) == gets, "cancelled debounce must not run another cycle")
    check(FakeServer.shared.count("PATCH", "couple/profile", user: b.id) == 1, "exactly one PATCH")
}

// 9: engine paths used by Moments/Letters (collections) and Pet (documents) unchanged.
@MainActor final class TestItems: CoupleSyncCollection {
    let key = "test-items", path = "couple/test-items"
    var records: [String: String] = [:]
    func localRecords() -> [String: [String: Any]] { records.mapValues { ["text": $0] } }
    func comparableBody(fromServer dto: [String: Any]) -> [String: Any]? { ["text": dto["text"] as? String ?? ""] }
    func applyRemote(upserts: [[String: Any]], deletedIds: [String]) {
        for u in upserts { records[u["id"] as! String] = u["text"] as? String }
    }
}
@MainActor final class TestDoc: CoupleSyncDocument {
    let key = "test-doc", path = "couple/test-doc", writeMethod = "PUT"
    var value = ""
    func localBody() -> [String: Any]? { ["value": value] }
    func comparableBody(fromServer dto: [String: Any]) -> [String: Any] { ["value": dto["value"] as? String ?? ""] }
    func serverHasContent(_ dto: [String: Any]) -> Bool { !(dto["value"] as? String ?? "").isEmpty }
    func applyRemote(_ dto: [String: Any]) { value = dto["value"] as? String ?? "" }
}

await test("9 collection and plain-document sync behave as before") {
    let itemsA = TestItems(), itemsB = TestItems(), docA = TestDoc(), docB = TestDoc()
    let a = Phone("a", nickname: "Ari") { $0.register(itemsA); $0.register(docA) }
    let b = Phone("b", nickname: "Bo") { $0.register(itemsB); $0.register(docB) }
    await a.sync(); await b.sync()
    itemsA.records["00000000000000000000000a"] = "moment from A"
    docA.value = "pet state from A"
    await a.sync(); await b.sync()
    check(itemsB.records["00000000000000000000000a"] == "moment from A", "collection item reached B")
    check(docB.value == "pet state from A", "document reached B")
    let posts = FakeServer.shared.count("POST", "couple/test-items"), puts = FakeServer.shared.count("PUT", "couple/test-doc")
    for _ in 0..<3 { await a.sync(); await b.sync() }
    check(FakeServer.shared.count("POST", "couple/test-items") == posts, "no repeat POST")
    check(FakeServer.shared.count("PUT", "couple/test-doc") == puts, "no repeat PUT")
}

// MARK: - BAB-147 backend verification follow-up

func avatarValues(_ user: String) -> [String] {
    FakeServer.shared.receivedAvatarValues.filter { $0.user == user }.map(\.value)
}

await test("N1 first pairing from empty partner_profiles: GET → PATCH 200 → partner applied, logged per step without personal data") {
    let (a, b) = await pair(aAvatar: photoA1, bAvatar: photoB1)
    await b.sync()
    check(FakeServer.shared.count("PATCH", "couple/profile", user: a.id) == 1, "A one PATCH")
    check(FakeServer.shared.count("PATCH", "couple/profile", user: b.id) == 1, "B one PATCH")
    check(a.partnerNickname == "Bo" && b.partnerNickname == "Ari", "both partners applied")
    check(a.partnerAvatar == photoB1 && b.partnerAvatar == photoA1, "both photos applied")
    let log = CoupleSyncLog.recent.suffix(30)   // this test's events (buffer keeps 100)
    check(log.contains { $0.hasPrefix("pull profile status=200 firstSync=true") }, "first GET logged")
    check(log.contains { $0.hasPrefix("profile pulled entries=0") }, "empty partner_profiles logged")
    check(log.contains { $0.hasPrefix("push profile PATCH status=200") }, "PATCH logged")
    check(log.contains { $0.contains("partner=true") }, "partner applied logged")
    let leaks = log.filter { line in
        [a.id, b.id, "Ari", "Bo", "public/", "test-token", "media.test"].contains { line.contains($0) }
    }
    check(leaks.isEmpty, "diagnostics leak personal data: \(leaks)")
}

await test("N2 pairing signal before officialCouple is saved: skipped and logged, no request") {
    let a = Phone("a", nickname: "Ari")
    a.device.profile.relationshipStage = .prelude
    Device.current = a.device
    a.engine.coupleDidPair()
    try? await Task.sleep(nanoseconds: 200_000_000)
    check(FakeServer.shared.requests.isEmpty, "no request outside officialCouple")
    check(CoupleSyncLog.recent.last(where: { $0.hasPrefix("sync skipped trigger=paired") }) != nil, "skip logged")
}

await test("N3 photo removal sends avatar_path \"\" exactly once, never null, no repeat PATCH") {
    let (a, b) = await pair(aAvatar: photoA1)
    await b.sync()
    a.removeOwnPhoto()
    await a.sync(); await b.sync()
    check(avatarValues(a.id).filter { $0 == "" }.count == 1, "one \"\" sent: \(avatarValues(a.id))")
    check(FakeServer.shared.entries[a.id]?["avatar_path"] == nil, "server photo cleared")
    check(b.partnerAvatar == nil, "B dropped A's photo")
    let patches = FakeServer.shared.count("PATCH", "couple/profile", user: a.id)
    for _ in 0..<4 { await a.sync(); await b.sync() }
    check(FakeServer.shared.count("PATCH", "couple/profile", user: a.id) == patches, "no repeat PATCH after removal")
    check(!a.device.ownAvatarRemovalPending, "removal confirmed by the next pull and cleared")
    check(!avatarValues(a.id).contains("<null>"), "null never sent")
}

await test("N4 removal when the server already has no photo sends nothing") {
    let (a, _) = await pair()
    let patches = FakeServer.shared.count("PATCH", "couple/profile", user: a.id)
    a.removeOwnPhoto()
    for _ in 0..<3 { await a.sync() }
    check(FakeServer.shared.count("PATCH", "couple/profile", user: a.id) == patches, "no PATCH for a no-op removal")
}

await test("N5 photo missing locally without removal (reinstall / cleared data) never clears the server photo or loops") {
    let (a, b) = await pair(aAvatar: photoA1)
    await b.sync()
    a.device.ownAvatar = nil   // file gone, but the user did not remove it
    a.device.profile.profileNote = "note after reinstall"   // forces a PATCH of the whole body
    for _ in 0..<4 { await a.sync(); await b.sync() }
    check(FakeServer.shared.entries[a.id]?["avatar_path"] != nil, "server photo kept")
    check(!avatarValues(a.id).contains(""), "no \"\" sent without removal intent: \(avatarValues(a.id))")
    check(b.partnerAvatar == photoA1, "B keeps A's photo")
    check(FakeServer.shared.count("PATCH", "couple/profile", user: a.id) == 2, "first PATCH + note PATCH only, got \(FakeServer.shared.count("PATCH", "couple/profile", user: a.id))")
}

await test("N6 upload rejected: server photo kept, no local path, no repeat PATCH") {
    let (a, b) = await pair(aAvatar: photoA1)
    await b.sync()
    FakeServer.shared.uploadError = CovelaMediaUploadError.rejected("too large")
    a.setOwnPhoto(photoA2)
    a.device.userNickname = "Ari6"
    for _ in 0..<3 { await a.sync(); await b.sync() }
    let serverPath = FakeServer.shared.entries[a.id]?["avatar_path"] as? String
    check(serverPath.map { FakeServer.media[$0] == photoA1 } == true, "server still has A's first photo")
    check(b.partnerNickname == "Ari6" && b.partnerAvatar == photoA1, "rename arrives, old photo kept")
    check(FakeServer.shared.count("PATCH", "couple/profile", user: a.id) == 2, "no repeat PATCH: \(FakeServer.shared.count("PATCH", "couple/profile", user: a.id))")
    FakeServer.shared.uploadError = nil
    await a.sync(); await b.sync()
    check(b.partnerAvatar == photoA2, "new photo arrives once upload works")
}

await test("N7 upload offline: cycle stops before PATCH, nothing invalid stored") {
    let (a, _) = await pair()
    let patches = FakeServer.shared.count("PATCH", "couple/profile", user: a.id)
    FakeServer.shared.uploadError = CovelaMediaUploadError.network
    a.setOwnPhoto(photoA1)
    let ok = await a.sync()
    check(!ok && a.engine.status == .offline, "offline status")
    check(FakeServer.shared.count("PATCH", "couple/profile", user: a.id) == patches, "no PATCH while upload offline")
}

await test("N8 upload returning a file:// or local path is never sent as avatar_path") {
    let (a, b) = await pair()
    for bad in ["file:///var/mobile/Containers/avatar.jpg", "/private/var/mobile/avatar.jpg", "https://example.com/x.jpg?X-Amz-Signature=1"] {
        FakeServer.shared.uploadReturnsPath = bad
        a.setOwnPhoto(Data(bad.utf8))
        await a.sync(); await b.sync()
    }
    check(!avatarValues(a.id).contains { $0.contains("file:") || $0.hasPrefix("/") || $0.contains("://") },
          "invalid path sent: \(avatarValues(a.id))")
    check(FakeServer.shared.entries[a.id]?["avatar_path"] == nil, "server has no invalid path: \(avatarValues(a.id)) \(String(describing: FakeServer.shared.entries[a.id]))")
    FakeServer.shared.uploadReturnsPath = nil
    await a.sync(); await b.sync()
    check(b.partnerAvatar != nil, "valid upload works afterwards")
}

await test("N9 partner's file:// path on the server is ignored: no download loop, stored photo kept") {
    let (a, b) = await pair(aAvatar: photoA1)
    await b.sync()
    FakeServer.shared.entries[a.id]?["avatar_path"] = "file:///var/mobile/avatar.jpg"   // what the backend currently accepts
    let notified = b.notifiedProfile
    for _ in 0..<3 { await b.sync() }
    check(b.partnerAvatar == photoA1, "B keeps A's last valid photo")
    check(b.notifiedProfile == notified, "no UI churn")
    check(b.engine.status == .idle, "sync healthy")
    check(!avatarValues(b.id).contains { $0.contains("file:") }, "B never echoes it")
}

await test("N10 concurrent first PATCH, VersionError 500 (backend without base check): retry converges, nothing overwritten") {
    FakeServer.shared.ignoresBase = true
    let a = Phone("a", nickname: "Ari"), b = Phone("b", nickname: "Bo")
    a.device.ownAvatar = photoA1; b.device.ownAvatar = photoB1
    FakeServer.shared.versionErrorNextPatchFor = [b.id]
    async let ra = a.sync()
    async let rb = b.sync()
    let (okA, okB) = await (ra, rb)
    check(okA && !okB, "A ok, B hit 500")
    check(b.engine.pendingChangeCount == 1, "B's change kept in outbox")
    await b.sync()   // what the 15s retry does
    await a.sync()
    check(b.engine.pendingChangeCount == 0, "B outbox drained")
    check(FakeServer.shared.entries[a.id]?["nickname"] as? String == "Ari", "A's entry intact")
    check(FakeServer.shared.entries[b.id]?["nickname"] as? String == "Bo", "B's entry stored")
    check(a.partnerNickname == "Bo" && b.partnerNickname == "Ari", "both see each other")
    check(a.partnerAvatar == photoB1 && b.partnerAvatar == photoA1, "both photos")
    check(FakeServer.shared.count("PATCH", "couple/profile", user: b.id) == 2, "B: 500 + one retry")
}

await test("N11 concurrent PATCH, 500 then 409 on retry (stale base): own entry re-sent in the same retry run") {
    let (a, b) = await pair()
    // Both edit at once; B's PATCH collides (500), A's lands and moves the version.
    FakeServer.shared.versionErrorNextPatchFor = [b.id]
    a.device.profile.profileNote = "from A"
    b.device.userNickname = "Bo11"
    await a.sync()
    let okFirst = await b.sync()
    check(!okFirst, "B first run fails with 500")
    let ok = await b.sync()   // retry: stale base → 409 → refetch → re-push
    check(ok, "retry run succeeds")
    check(FakeServer.shared.entries[b.id]?["nickname"] as? String == "Bo11", "B's rename reached the server in the retry run")
    check(FakeServer.shared.note == "from A", "A's note not overwritten by B")
    check(b.device.profile.profileNote == "from A", "B took A's note")
    check(FakeServer.shared.entries[a.id]?["nickname"] as? String == "Ari", "A's entry untouched")
    check(b.engine.pendingChangeCount == 0, "outbox drained")
}

await test("N12 persistent 500: change kept (no data loss), auto retry backs off and stops") {
    let (a, _) = await pair()
    FakeServer.shared.alwaysFailPatches = true
    a.device.userNickname = "Ari12"
    for _ in 0..<5 { _ = await a.sync() }
    check(a.engine.pendingChangeCount == 1, "change stays queued")
    check(FakeServer.shared.count("PATCH", "couple/profile", user: a.id) == 1 + 5, "one PATCH per run, no tight loop")
    let delays = (1...7).map { CoupleSyncEngine.retryDelay(afterFailures: $0) }
    check(delays == [15, 30, 60, 120, 240, 480, 600], "backoff \(delays)")
    check(CoupleSyncEngine.shouldRetryAutomatically(afterFailures: 6, isServerError: true), "retry up to cap")
    check(!CoupleSyncEngine.shouldRetryAutomatically(afterFailures: 7, isServerError: true), "stop after cap")
    check(CoupleSyncEngine.shouldRetryAutomatically(afterFailures: 50, isServerError: false), "offline not capped")
    FakeServer.shared.alwaysFailPatches = false
    await a.sync()
    check(FakeServer.shared.entries[a.id]?["nickname"] as? String == "Ari12", "delivered once the server recovers")
}


// MARK: - BAB-147 integration follow-up: 409 loop seen on two simulators

func sleepSeconds(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
func statuses(_ user: String) -> [Int] { FakeServer.shared.patchStatuses.filter { $0.user == user }.map(\.status) }
/// Events logged since `mark` (a value of `CoupleSyncLog.eventCount`); at most the last 100.
func logSince(_ mark: Int) -> [String] { Array(CoupleSyncLog.recent.suffix(min(100, CoupleSyncLog.eventCount - mark))) }

/// Steps 1-5: B's PATCH hits 409, B refetches, applying it makes the UI save
/// (localDidChange) while the run is still going. The run must not be cancelled,
/// the base must be refreshed and B's rename must land with one 409, no loop.
await test("R1 409 + refetch + localDidChange during apply: run not cancelled, rename lands, no loop") {
    let (a, b) = await pair()
    await b.sync()
    a.device.profile.profileNote = "note from A"; await a.sync()   // B's base is now stale
    b.device.userNickname = "Bo-renamed"
    b.savesOnProfileNotify = true
    FakeServer.shared.latencyNanos = 30_000_000
    Device.current = b.device
    let mark = CoupleSyncLog.eventCount
    b.engine.localDidChange()
    await sleepSeconds(6)
    let s = statuses(b.id)
    check(FakeServer.shared.entries[b.id]?["nickname"] as? String == "Bo-renamed", "B's rename on server: \(FakeServer.shared.entries[b.id]?["nickname"] ?? "nil")")
    check(s.filter { $0 == 409 }.count == 1, "exactly one 409, got \(s)")
    check(s.count <= 3, "no PATCH loop: \(s.count) PATCHes")
    check(!logSince(mark).contains { $0.contains("ok=false status=offline") }, "no run ended offline (cancelled): \(logSince(mark).filter { $0.contains("ok=false") })")
    check(b.engine.status == .idle, "B idle: \(b.engine.status)")
    check(FakeServer.shared.note == "note from A", "A's note kept (server wins for shared fields)")
    let before = FakeServer.shared.patchStatuses.count
    await sleepSeconds(3.5)
    check(FakeServer.shared.patchStatuses.count == before, "still no new PATCH after settling")
    b.savesOnProfileNotify = false
    FakeServer.shared.latencyNanos = 0
}

/// Step 5: a run that stops right after the 409 refetch (here: offline on the next
/// pull) must not re-send the stale base next time.
await test("R2 refetch after 409 refreshes base_updated_at even when the run stops before its pull") {
    let itemsB = TestItems()
    let a = Phone("a", nickname: "Ari"), b = Phone("b", nickname: "Bo") { $0.register(itemsB) }
    await b.sync(); await a.sync(); await b.sync()
    a.device.userNickname = "Ari2"; await a.sync()                  // B's base is now stale
    b.device.userNickname = "Bo2"
    FakeServer.shared.offlineGets = ["couple/test-items"]
    let first = await b.sync()
    check(!first && b.engine.status == .offline, "first run stops offline after the refetch")
    FakeServer.shared.offlineGets = []
    await b.sync()
    let s = statuses(b.id)
    check(s.filter { $0 == 409 }.count == 1, "stale base re-sent: \(s)")
    check(FakeServer.shared.entries[b.id]?["nickname"] as? String == "Bo2", "B's rename lands")
    check(FakeServer.shared.entries[a.id]?["nickname"] as? String == "Ari2", "A's rename not overwritten")
}

/// Step 6: even if the server keeps answering 409, no short-interval loop.
await test("R3 persistent 409 + UI saves: stops after 3 conflicts and waits for backoff") {
    let (_, b) = await pair()
    await b.sync()
    FakeServer.shared.alwaysConflictFor = [b.id]
    b.device.userNickname = "Bo3"
    b.savesOnProfileNotify = true
    Device.current = b.device
    let mark = CoupleSyncLog.eventCount
    b.engine.localDidChange()
    await sleepSeconds(9)
    let conflicts = statuses(b.id).filter { $0 == 409 }.count
    check(conflicts >= 1 && conflicts <= CoupleSyncEngine.maxConsecutiveConflicts, "bounded 409 PATCHes: \(conflicts)")
    check(logSince(mark).contains { $0.contains("backing off") }, "backoff logged")
    if case .failed = b.engine.status {} else { check(false, "status failed: \(b.engine.status)") }
    check(b.device.userNickname == "Bo3", "B's local rename is kept, not overwritten by the server")
    b.savesOnProfileNotify = false
    FakeServer.shared.alwaysConflictFor = []
    await b.sync()   // e.g. foreground after the server is fixed
    check(FakeServer.shared.entries[b.id]?["nickname"] as? String == "Bo3", "delivered once 409s stop")
}

/// Safety kept: an account change still cancels a debounced run in flight.
await test("R4 account change cancels the debounced run (no request with the old account)") {
    let a = Phone("a", nickname: "Ari")
    await a.sync()
    let other = Phone("c", nickname: "Cy")
    FakeServer.shared.latencyNanos = 400_000_000
    Device.current = a.device
    a.device.userNickname = "Ari-late"
    a.engine.localDidChange()
    await sleepSeconds(1.7)                 // debounce over, the run is waiting on the network
    let sentByA = FakeServer.shared.requests.filter { $0.user == a.id }.count
    Device.current = other.device           // sign-in switches account
    NotificationCenter.default.post(name: .covelaAccountDidChange, object: nil)
    await sleepSeconds(1.5)
    check(FakeServer.shared.requests.filter { $0.user == a.id }.count == sentByA, "request sent with the previous account after the switch")
    check(FakeServer.shared.entries[a.id]?["nickname"] as? String != "Ari-late", "old run did not push after the switch")
    FakeServer.shared.latencyNanos = 0
}

/// Steps 7-8: both rename before seeing each other; each sees the other's name and
/// nobody's entry is overwritten.
await test("R5 simultaneous renames on both phones: both land, both see each other") {
    let (a, b) = await pair()
    await b.sync()
    a.device.userNickname = "Ari-new"; b.device.userNickname = "Bo-new"
    await a.sync(); await b.sync(); await a.sync()
    check(FakeServer.shared.entries[a.id]?["nickname"] as? String == "Ari-new", "A on server")
    check(FakeServer.shared.entries[b.id]?["nickname"] as? String == "Bo-new", "B on server")
    check(a.partnerNickname == "Bo-new" && b.partnerNickname == "Ari-new", "A→\(a.partnerNickname ?? "nil") B→\(b.partnerNickname ?? "nil")")
    check(statuses(b.id).filter { $0 == 409 }.count <= 1, "at most one conflict: \(statuses(b.id))")
    check(a.engine.pendingChangeCount == 0 && b.engine.pendingChangeCount == 0, "outboxes empty")
}

/// Step 9: relaunch (fresh engine over the persisted state) stays in sync, no extra writes.
await test("R6 relaunch after a 409 recovery: state persisted, no extra PATCH, names intact") {
    let (a, b) = await pair()
    await b.sync()
    a.device.userNickname = "Ari-r"; b.device.userNickname = "Bo-r"
    await a.sync(); await b.sync(); await a.sync()
    let patches = FakeServer.shared.patchStatuses.count
    a.relaunch(); b.relaunch()
    for _ in 0..<2 { await a.sync(); await b.sync() }
    check(FakeServer.shared.patchStatuses.count == patches, "relaunch caused PATCHes: \(FakeServer.shared.patchStatuses.count - patches)")
    check(a.partnerNickname == "Bo-r" && b.partnerNickname == "Ari-r", "names after relaunch")
    check(a.engine.status == .idle && b.engine.status == .idle, "both idle")
}

check(FakeServer.everReceivedNullOrFileAvatar == 0, "avatar_path null or file: received \(FakeServer.everReceivedNullOrFileAvatar) times across all tests")

try? FileManager.default.removeItem(at: root)
print(failures == 0 ? "\nALL PASSED" : "\n\(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
