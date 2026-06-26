import Foundation

enum CouplePlaylistStore {

    static let maxTracks = 10
    static let maxDisplayNameLength = 60

    private static let playlistFileName = "playlist.json"
    private static let directoryName = "background_music"
    private static let tracksSubdirectory = "tracks"
    private static let legacyFileName = "imported_song.m4a"
    private static let legacyHasImportedKey = "backgroundMusicHasImportedSong"

    private static let nowPlayingIDKey = "couplePlaylistNowPlayingID"
    private static let repeatEnabledKey = "couplePlaylistRepeatEnabled"
    private static let shuffleEnabledKey = "couplePlaylistShuffleEnabled"
    private static let didMigrateLegacyKey = "couplePlaylistDidMigrateLegacy"

    private static let defaultBundledResourceName = "one_love"
    private static let defaultBundledResourceExtension = "mp3"
    private static let defaultDisplayName = "One Love"

    private static var fileManager: FileManager { .default }
    private static var userDefaults: UserDefaults { .standard }

    private static var storageDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static var tracksDirectory: URL {
        storageDirectory.appendingPathComponent(tracksSubdirectory, isDirectory: true)
    }

    private static var playlistURL: URL {
        storageDirectory.appendingPathComponent(playlistFileName)
    }

    private static var legacySongURL: URL {
        storageDirectory.appendingPathComponent(legacyFileName)
    }

    // MARK: - Playlist

    static var tracks: [CouplePlaylistTrack] {
        loadPlaylist().sorted { $0.sortOrder < $1.sortOrder }
    }

    static var hasTracks: Bool {
        !tracks.isEmpty
    }

    static var canAddTrack: Bool {
        tracks.count < maxTracks
    }

    static func audioURL(for track: CouplePlaylistTrack) -> URL {
        tracksDirectory.appendingPathComponent(track.fileName)
    }

    static func audioURL(forID id: UUID) -> URL? {
        guard let track = tracks.first(where: { $0.id == id }) else { return nil }
        return audioURL(for: track)
    }

    static func track(withID id: UUID) -> CouplePlaylistTrack? {
        tracks.first { $0.id == id }
    }

    @discardableResult
    static func addTrack(
        fromExportedAudioAt sourceURL: URL,
        proposedDisplayName: String? = nil
    ) throws -> CouplePlaylistTrack {
        migrateLegacyIfNeeded()
        guard canAddTrack else {
            throw PlaylistError.playlistFull
        }

        ensureDirectories()
        let id = UUID()
        let fileName = "\(id.uuidString).m4a"
        let destination = tracksDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)

        var playlist = loadPlaylist()
        let nextOrder = (playlist.map(\.sortOrder).max() ?? -1) + 1
        let displayName = sanitizedDisplayName(
            proposedDisplayName,
            fallback: "Song \(playlist.count + 1)"
        )
        let track = CouplePlaylistTrack(
            id: id,
            displayName: displayName,
            fileName: fileName,
            sortOrder: nextOrder
        )
        playlist.append(track)
        savePlaylist(playlist)
        nowPlayingID = id
        notifyChanged()
        return track
    }

    static func removeTrack(id: UUID) {
        migrateLegacyIfNeeded()
        var playlist = loadPlaylist()
        guard let index = playlist.firstIndex(where: { $0.id == id }) else { return }

        let track = playlist[index]
        let fileURL = audioURL(for: track)
        try? fileManager.removeItem(at: fileURL)
        playlist.remove(at: index)

        for i in playlist.indices {
            playlist[i].sortOrder = i
        }
        savePlaylist(playlist)

        if nowPlayingID == id {
            nowPlayingID = playlist.sorted(by: { $0.sortOrder < $1.sortOrder }).first?.id
        }
        notifyChanged()
    }

    static func setNowPlaying(id: UUID) {
        guard track(withID: id) != nil else { return }
        nowPlayingID = id
        notifyChanged()
    }

    static func replaceAudio(for id: UUID, from trimmedSourceURL: URL) throws {
        migrateLegacyIfNeeded()
        guard track(withID: id) != nil else { return }

        ensureDirectories()
        let destination = tracksDirectory.appendingPathComponent("\(id.uuidString).m4a")

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: trimmedSourceURL, to: destination)
        notifyChanged()
    }

    @discardableResult
    static func updateDisplayName(id: UUID, displayName: String) -> Bool {
        migrateLegacyIfNeeded()
        let sanitized = sanitizedDisplayName(displayName, fallback: "")
        guard !sanitized.isEmpty else { return false }

        var playlist = loadPlaylist()
        guard let index = playlist.firstIndex(where: { $0.id == id }) else { return false }
        guard playlist[index].displayName != sanitized else { return true }

        playlist[index].displayName = sanitized
        savePlaylist(playlist)
        notifyChanged()
        return true
    }

    static func clearAll() {
        for track in tracks {
            try? fileManager.removeItem(at: audioURL(for: track))
        }
        savePlaylist([])
        nowPlayingID = nil
        try? fileManager.removeItem(at: legacySongURL)
        userDefaults.set(false, forKey: legacyHasImportedKey)
        notifyChanged()
    }

    // MARK: - Preferences

    static var nowPlayingID: UUID? {
        get {
            guard let raw = userDefaults.string(forKey: nowPlayingIDKey) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                userDefaults.set(newValue.uuidString, forKey: nowPlayingIDKey)
            } else {
                userDefaults.removeObject(forKey: nowPlayingIDKey)
            }
        }
    }

    static var nowPlayingTrack: CouplePlaylistTrack? {
        guard let id = nowPlayingID else { return tracks.first }
        return track(withID: id) ?? tracks.first
    }

    static var repeatEnabled: Bool {
        get { userDefaults.bool(forKey: repeatEnabledKey) }
        set {
            userDefaults.set(newValue, forKey: repeatEnabledKey)
            notifyChanged()
        }
    }

    static var shuffleEnabled: Bool {
        get { userDefaults.bool(forKey: shuffleEnabledKey) }
        set {
            userDefaults.set(newValue, forKey: shuffleEnabledKey)
            notifyChanged()
        }
    }

    // MARK: - Legacy compatibility

    static var hasImportedSong: Bool {
        migrateLegacyIfNeeded()
        return hasTracks
    }

    static var importedAudioURL: URL? {
        migrateLegacyIfNeeded()
        guard let track = nowPlayingTrack ?? tracks.first else { return nil }
        let url = audioURL(for: track)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    enum PlaylistError: LocalizedError {
        case playlistFull

        var errorDescription: String? {
            switch self {
            case .playlistFull:
                return "Playlist is full (10 songs). Remove one in Change."
            }
        }
    }

    // MARK: - Private

    private static func migrateLegacyIfNeeded() {
        guard !userDefaults.bool(forKey: didMigrateLegacyKey) else { return }
        defer { userDefaults.set(true, forKey: didMigrateLegacyKey) }

        var playlist = readPlaylistFromDisk()
        if playlist.isEmpty,
           fileManager.fileExists(atPath: legacySongURL.path),
           userDefaults.bool(forKey: legacyHasImportedKey) {
            ensureDirectories()
            let id = UUID()
            let fileName = "\(id.uuidString).m4a"
            let destination = tracksDirectory.appendingPathComponent(fileName)
            try? fileManager.copyItem(at: legacySongURL, to: destination)
            try? fileManager.removeItem(at: legacySongURL)

            let track = CouplePlaylistTrack(
                id: id,
                displayName: "Our song",
                fileName: fileName,
                sortOrder: 0
            )
            playlist = [track]
            savePlaylist(playlist)
            nowPlayingID = id
        }
    }

    private static func installDefaultSongIfNeeded() {
        guard readPlaylistFromDisk().isEmpty else { return }
        guard let bundleURL = bundledDefaultSongURL() else { return }

        ensureDirectories()
        let id = UUID()
        let fileName = "\(id.uuidString).\(defaultBundledResourceExtension)"
        let destination = tracksDirectory.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: bundleURL, to: destination)
        } catch {
            return
        }

        let track = CouplePlaylistTrack(
            id: id,
            displayName: defaultDisplayName,
            fileName: fileName,
            sortOrder: 0
        )
        savePlaylist([track])
        nowPlayingID = id
        if !repeatEnabled {
            repeatEnabled = true
        }
        notifyChanged()
    }

    private static func bundledDefaultSongURL() -> URL? {
        if let url = Bundle.main.url(
            forResource: defaultBundledResourceName,
            withExtension: defaultBundledResourceExtension
        ) {
            return url
        }
        return Bundle.main.url(
            forResource: defaultBundledResourceName,
            withExtension: defaultBundledResourceExtension,
            subdirectory: "Songs"
        )
    }

    private static func readPlaylistFromDisk() -> [CouplePlaylistTrack] {
        guard fileManager.fileExists(atPath: playlistURL.path),
              let data = try? Data(contentsOf: playlistURL),
              let decoded = try? JSONDecoder().decode([CouplePlaylistTrack].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func loadPlaylist() -> [CouplePlaylistTrack] {
        migrateLegacyIfNeeded()
        installDefaultSongIfNeeded()
        return readPlaylistFromDisk()
    }

    private static func savePlaylist(_ tracks: [CouplePlaylistTrack]) {
        ensureDirectories()
        if let data = try? JSONEncoder().encode(tracks) {
            try? data.write(to: playlistURL, options: .atomic)
        }
    }

    private static func ensureDirectories() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: tracksDirectory.path) {
            try? fileManager.createDirectory(at: tracksDirectory, withIntermediateDirectories: true)
        }
    }

    private static func sanitizedDisplayName(_ raw: String?, fallback: String) -> String {
        guard let raw else { return fallback }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(maxDisplayNameLength))
    }

    private static func notifyChanged() {
        NotificationCenter.default.post(name: .backgroundMusicPreferenceChanged, object: nil)
    }
}
