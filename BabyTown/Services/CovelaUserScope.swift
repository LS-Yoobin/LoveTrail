import Foundation

/// Thread-safe view of "which account's local storage is active".
///
/// `DataPersistenceManager` is main-actor bound, but several media stores
/// (`ThumbnailStore`, `MomentVideoStore`, …) do disk IO from background queues.
/// This holds the same scope id that `DataPersistenceManager` uses so those stores
/// can write into `Documents/CovelaUserData/<scopeId>/` without hopping actors.
///
/// `AuthService` keeps it current on session restore, sign-in and sign-out.
enum CovelaUserScope {
    static let anonymousScopeId = "anonymous"

    private static let lock = NSLock()
    private static var storedScopeId: String = KeychainTokenStore.load()?.userId ?? anonymousScopeId
    private static var migratedLegacyItems: Set<String> = []

    /// The signed-in user's id, or the anonymous bucket before signup / after sign-out.
    static var currentScopeId: String {
        lock.lock(); defer { lock.unlock() }
        return storedScopeId
    }

    static func setCurrentUserId(_ userId: String?) {
        lock.lock()
        storedScopeId = userId ?? anonymousScopeId
        lock.unlock()
    }

    /// `Documents/` itself, where pre-scoping installs kept their files.
    static var legacyDocumentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// `Documents/CovelaUserData/<scopeId>/` for the active account. Created on demand.
    static var documentsDirectory: URL {
        let dir = legacyDocumentsDirectory
            .appendingPathComponent("CovelaUserData", isDirectory: true)
            .appendingPathComponent(currentScopeId, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// A named file or folder inside the active account's directory.
    ///
    /// The first time a name is resolved for a scope, a legacy item with the same
    /// name directly under `Documents/` is moved in, so existing installs keep their
    /// media. The legacy copy goes to whichever account opens it first, matching how
    /// `DataPersistenceManager` migrated its own files.
    static func scopedItem(named name: String, isDirectory: Bool) -> URL {
        let scoped = documentsDirectory.appendingPathComponent(name, isDirectory: isDirectory)
        migrateLegacyItemIfNeeded(named: name, to: scoped)
        if isDirectory, !FileManager.default.fileExists(atPath: scoped.path) {
            try? FileManager.default.createDirectory(at: scoped, withIntermediateDirectories: true)
        }
        return scoped
    }

    private static func migrateLegacyItemIfNeeded(named name: String, to scoped: URL) {
        let key = "\(currentScopeId)/\(name)"
        lock.lock()
        let alreadyChecked = migratedLegacyItems.contains(key)
        if !alreadyChecked { migratedLegacyItems.insert(key) }
        lock.unlock()
        guard !alreadyChecked else { return }

        let fileManager = FileManager.default
        let legacy = legacyDocumentsDirectory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: legacy.path),
              !fileManager.fileExists(atPath: scoped.path) else { return }
        try? fileManager.moveItem(at: legacy, to: scoped)
    }
}

extension Notification.Name {
    /// Posted on the main actor after the signed-in account changes (sign-in, sign-out,
    /// account switch). Stores that cache per-account data in memory should reload.
    static let covelaAccountDidChange = Notification.Name("covelaAccountDidChange")

    /// Posted on the main actor after `DataPersistenceManager.clearCoupleData()` removed
    /// everything the couple built (end of the archive window, or step out). Anything
    /// holding couple data in memory must reload.
    static let coveDidReset = Notification.Name("coveDidReset")
}
