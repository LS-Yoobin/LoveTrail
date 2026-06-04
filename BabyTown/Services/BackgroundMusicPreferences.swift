import Foundation

/// User-selected background music for the home screen (imported audio in Documents).
enum BackgroundMusicPreferences {

    static var hasCustomSong: Bool {
        BackgroundMusicImporter.hasImportedSong
    }

    static var importedAudioURL: URL? {
        BackgroundMusicImporter.importedAudioURL
    }

    static func clearCustomSong() {
        BackgroundMusicImporter.clearImportedSong()
    }
}

extension Notification.Name {
    static let backgroundMusicPreferenceChanged = Notification.Name("backgroundMusicPreferenceChanged")
}
