import Foundation

/// User-selected background music link for the home screen (persisted in UserDefaults).
enum BackgroundMusicPreferences {

    private static let customLinkKey = "customBackgroundMusicLink"

    static var customLinkURL: URL? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: customLinkKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            return URL(string: raw)
        }
        set {
            if let url = newValue?.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines),
               !url.isEmpty {
                UserDefaults.standard.set(url, forKey: customLinkKey)
            } else {
                UserDefaults.standard.removeObject(forKey: customLinkKey)
            }
            NotificationCenter.default.post(name: .backgroundMusicPreferenceChanged, object: nil)
        }
    }

    static var parsedLink: BackgroundMusicLink? {
        guard let url = customLinkURL else { return nil }
        return BackgroundMusicLinkParser.parse(url)
    }

    static func clearCustomLink() {
        customLinkURL = nil
    }
}

extension Notification.Name {
    static let backgroundMusicPreferenceChanged = Notification.Name("backgroundMusicPreferenceChanged")
}
