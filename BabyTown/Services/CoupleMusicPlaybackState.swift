import Combine
import Foundation

@MainActor
final class CoupleMusicPlaybackState: ObservableObject {
    static let shared = CoupleMusicPlaybackState()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTrackTitle = "Default song"

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
        } else if CouplePlaylistStore.hasTracks {
            currentTrackTitle = "Our song"
        } else {
            currentTrackTitle = "Default song"
        }
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing
    }
}
