import Combine
import Foundation

/// Shared pending Watch Together invite state for Secret Garden and Home.
@MainActor
final class WatchTogetherInviteStore: ObservableObject {
    static let shared = WatchTogetherInviteStore()

    @Published private(set) var pendingInvite: WatchTogetherInvite?
    @Published private(set) var activeInvite: WatchTogetherInvite?
    @Published var showPlayerFromInvite = false

    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: .watchTogetherInviteReceived,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.handleInviteNotification(note)
            }
        }
    }

    func joinPending() {
        guard let invite = pendingInvite else { return }
        activeInvite = invite
        OrientationManager.shared.allowLandscape()
        OrientationManager.shared.lockLandscape()
        showPlayerFromInvite = true
    }

    func tearDownPlayer() {
        OrientationManager.shared.setPortraitMaskOnly()
        activeInvite = nil
        showPlayerFromInvite = false
    }

    private func handleInviteNotification(_ note: Notification) {
        guard let sessionID = note.userInfo?["sessionID"] as? UUID,
              let videoURL = note.userInfo?["videoURL"] as? String,
              let hostName = note.userInfo?["hostName"] as? String else { return }
        pendingInvite = WatchTogetherInvite(
            sessionID: sessionID,
            videoURL: videoURL,
            hostName: hostName
        )
    }
}
