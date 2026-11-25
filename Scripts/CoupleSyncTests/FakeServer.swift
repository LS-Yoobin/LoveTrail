import Foundation

/// In-memory stand-in for the Covela API, modelling the BAB-68 `/couple/profile`
/// contract as verified on the backend in BAB-147:
/// - `GET` returns `note`, `mood`, `updated_at`, `couple_profile_id` and
///   `partner_profiles: [{ user_id, nickname, avatar_path, avatar_url }]`, with an entry
///   only for users who have PATCHed (empty right after pairing).
/// - `PATCH` writes `note`, `mood` and the caller's own `partner_profile` entry, merged:
///   an omitted `avatar_path` keeps the stored one, `""` removes it, `null` is
///   400 `invalid_media_path`, and any string (even `file://`) is stored as sent.
///   Answers 409 when `base_updated_at` is older than the stored document (unless
///   `ignoresBase`), and can answer 500 like Mongoose VersionError on concurrent saves.
/// Plus one generic collection (`couple/test-items`) and one plain document
/// (`couple/test-doc`) to check that the engine's other paths are unaffected.
final class FakeServer {
    nonisolated(unsafe) static var shared = FakeServer()
    nonisolated(unsafe) static var media: [String: Data] = [:]
    /// Across all tests: `avatar_path` values of `null` or `file:` ever received.
    nonisolated(unsafe) static var everReceivedNullOrFileAvatar = 0

    var members: Set<String> = []
    var note = ""
    var mood = ""
    var entries: [String: [String: Any]] = [:]   // user id → { nickname, avatar_path }
    var version = 0

    /// Force every `/couple/profile` request to answer this status (e.g. 401, 403, 500).
    var forcedProfileStatus: Int?
    /// Answer the next N PATCHes with 500.
    var failNextPatches = 0
    /// Answer every PATCH with 500 (persistent server error).
    var alwaysFailPatches = false
    /// The next PATCH from these users answers 500 as if it collided with another save.
    var versionErrorNextPatchFor: Set<String> = []
    /// Accept PATCHes regardless of `base_updated_at` (backend without conflict check).
    var ignoresBase = false
    /// Simulated network latency per request (cancellable, see Stubs.swift).
    var latencyNanos: UInt64 = 0
    /// GETs to these paths fail as offline.
    var offlineGets: Set<String> = []
    /// Every PATCH from these users answers 409 (e.g. a clock-skewed server).
    var alwaysConflictFor: Set<String> = []
    /// Every `avatar_path` value received: the string, "<null>" or "<absent>".
    var receivedAvatarValues: [(user: String, value: String)] = []
    /// Upload stub overrides.
    var uploadReturnsPath: String?
    var uploadError: Error?

    var requests: [(user: String, method: String, path: String)] = []
    func count(_ method: String, _ path: String, user: String? = nil) -> Int {
        requests.filter { $0.method == method && $0.path == path && (user == nil || $0.user == user) }.count
    }
    /// Status of every profile PATCH, per user.
    var patchStatuses: [(user: String, status: Int)] = []

    // Generic collection + document used for the "other resources" check.
    var items: [String: [String: Any]] = [:]
    var itemVersion = 0
    var testDoc: [String: Any] = ["value": ""]
    var testDocVersion = 0

    private var updatedAt: String { String(format: "2026-01-01T00:00:%02d.000Z", version) }

    func storeMedia(_ data: Data) -> String {
        let path = "public/media/\(UUID().uuidString.lowercased()).jpg"
        FakeServer.media[path] = data
        return path
    }

    func handle(method: String, path: String, query: [URLQueryItem], body: [String: Any]?, token: String) throws -> CovelaAPIClient.RawResponse {
        let user = String(token.dropFirst("test-token-".count))
        requests.append((user, method, path))
        let response = try route(method: method, path: path, query: query, body: body, user: user)
        if method == "PATCH", path == "couple/profile" { patchStatuses.append((user, response.status)) }
        return response
    }

    private func route(method: String, path: String, query: [URLQueryItem], body: [String: Any]?, user: String) throws -> CovelaAPIClient.RawResponse {
        guard members.contains(user) else { return Self.json(403, ["result": "FAIL", "reason": "not_in_couple"]) }

        switch (method, path) {
        case ("GET", "couple/profile"):
            if let forced = forcedProfileStatus { return Self.json(forced, profileDTO()) }
            return Self.json(200, profileDTO())

        case ("PATCH", "couple/profile"):
            if let forced = forcedProfileStatus { return Self.json(forced, ["result": "FAIL"]) }
            let body = body ?? [:]
            if let own = body["partner_profile"] as? [String: Any] {
                let value: String
                switch own["avatar_path"] {
                case nil: value = "<absent>"
                case is NSNull: value = "<null>"
                case let string as String: value = string
                default: value = "<other>"
                }
                receivedAvatarValues.append((user, value))
                FakeServer.everReceivedNullOrFileAvatar += (value == "<null>" || value.contains("file:")) ? 1 : 0
                if value == "<null>" { return Self.json(400, ["result": "FAIL", "reason": "invalid_media_path"]) }
            }
            if alwaysFailPatches { return Self.json(500, ["result": "FAIL"]) }
            if failNextPatches > 0 { failNextPatches -= 1; return Self.json(500, ["result": "FAIL"]) }
            if versionErrorNextPatchFor.remove(user) != nil {
                return Self.json(500, ["result": "FAIL", "message": "VersionError: No matching document found"])
            }
            if alwaysConflictFor.contains(user) {
                return Self.json(409, ["result": "FAIL", "reason": "stale_write"])
            }
            if !ignoresBase, let base = body["base_updated_at"] as? String, base != updatedAt {
                return Self.json(409, ["result": "FAIL", "reason": "conflict"])
            }
            note = body["note"] as? String ?? note
            mood = body["mood"] as? String ?? mood
            if let own = body["partner_profile"] as? [String: Any] {
                var entry = entries[user] ?? [:]
                if let nickname = own["nickname"] as? String { entry["nickname"] = nickname }
                if let avatar = own["avatar_path"] as? String {
                    if avatar.isEmpty { entry.removeValue(forKey: "avatar_path") } else { entry["avatar_path"] = avatar }
                }
                entries[user] = entry
            }
            version += 1
            return Self.json(200, ["updated_at": updatedAt])

        case ("GET", "couple/test-items"):
            itemVersion += 0
            return Self.json(200, ["items": Array(items.values), "has_more": false])

        case ("POST", "couple/test-items"):
            var item = body ?? [:]
            item.removeValue(forKey: "base_updated_at")
            itemVersion += 1
            item["updated_at"] = String(format: "2026-02-01T00:00:%02d.000Z", itemVersion)
            items[item["id"] as! String] = item
            return Self.json(200, ["updated_at": item["updated_at"]!])

        case ("GET", "couple/test-doc"):
            return Self.json(200, testDoc.merging(["updated_at": "v\(testDocVersion)"]) { a, _ in a })

        case ("PUT", "couple/test-doc"):
            testDoc = ["value": (body?["value"] as? String) ?? ""]
            testDocVersion += 1
            return Self.json(200, ["updated_at": "v\(testDocVersion)"])

        default:
            return Self.json(404, ["result": "FAIL"])
        }
    }

    private func profileDTO() -> [String: Any] {
        let profiles: [[String: Any]] = members.sorted().filter { entries[$0] != nil }.map { member in
            var entry: [String: Any] = ["user_id": member.uppercased()]   // server ids are not lowercased
            let stored = entries[member] ?? [:]
            entry["nickname"] = stored["nickname"] ?? NSNull()
            if let path = stored["avatar_path"] as? String {
                entry["avatar_path"] = path
                entry["avatar_url"] = "https://media.test/\(path)"
            } else {
                entry["avatar_path"] = NSNull()
                entry["avatar_url"] = NSNull()
            }
            return entry
        }
        return [
            "couple_profile_id": "couple-1",
            "note": note,
            "mood": mood,
            "updated_at": updatedAt,
            "partner_profiles": profiles,
        ]
    }

    static func json(_ status: Int, _ object: [String: Any]) -> CovelaAPIClient.RawResponse {
        CovelaAPIClient.RawResponse(status: status, data: try! JSONSerialization.data(withJSONObject: object))
    }
}
