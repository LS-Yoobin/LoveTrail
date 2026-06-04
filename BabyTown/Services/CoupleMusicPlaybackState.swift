import Combine
import Foundation

@MainActor
final class CoupleMusicPlaybackState: ObservableObject {
    static let shared = CoupleMusicPlaybackState()

    @Published private(set) var isPlaying = false
    static let emptyPlaylistTitle = "No song yet"

    @Published private(set) var currentTrackTitle = emptyPlaylistTitle

    private var observer: NSObjectProtocol?

    private init() {
        refreshFromStore()
        observer = NotificationCenter.default.addObserver(
            forName: .backgroundMusicPreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromStore()
            }
        }
    }

    func refreshFromStore() {
        if let track = CouplePlaylistStore.nowPlayingTrack {
            currentTrackTitle = track.displayName
        } else {
            currentTrackTitle = Self.emptyPlaylistTitle
        }
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing
    }
}
