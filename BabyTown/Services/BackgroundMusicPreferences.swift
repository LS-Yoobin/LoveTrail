import Foundation

/// User-selected background music for the home screen (imported audio in Documents).
enum BackgroundMusicPreferences {

    static var hasCustomSong: Bool {
        CouplePlaylistStore.hasTracks
    }

    static var importedAudioURL: URL? {
        CouplePlaylistStore.importedAudioURL
    }

    static func clearCustomSong() {
        CouplePlaylistStore.clearAll()
    }
}

extension Notification.Name {
    static let backgroundMusicPreferenceChanged = Notification.Name("backgroundMusicPreferenceChanged")
}
