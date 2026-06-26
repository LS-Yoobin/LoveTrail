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
            guard let sessionID = note.userInfo?["sessionID"] as? UUID,
                  let videoURL = note.userInfo?["videoURL"] as? String,
                  let hostName = note.userInfo?["hostName"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.applyInvite(sessionID: sessionID, videoURL: videoURL, hostName: hostName)
            }
        }
    }

    func joinPending() {
        guard let invite = pendingInvite else { return }
        Task {
            // Let the previous player finish teardown and release camera hardware.
            try? await Task.sleep(for: .milliseconds(350))
            guard pendingInvite != nil else { return }
            beginJoin(invite)
        }
    }

    /// Push notification tap: store invite and join immediately (spec: "Tap to join and watch").
    func acceptAndJoinFromNotification(sessionID: UUID, videoURL: String, hostName: String) {
        let invite = WatchTogetherInvite(
            sessionID: sessionID,
            videoURL: videoURL,
            hostName: hostName
        )
        pendingInvite = invite
        beginJoin(invite)
    }

    private func beginJoin(_ invite: WatchTogetherInvite) {
        activeInvite = invite
        OrientationManager.shared.allowLandscape()
        OrientationManager.shared.lockLandscape()
        // Present the player immediately (same as host flow) so camera capture
        // starts inside the player hierarchy after it has laid out in landscape.
        showPlayerFromInvite = true
    }

    func tearDownPlayer() {
        OrientationManager.shared.setPortraitMaskOnly()
        activeInvite = nil
        showPlayerFromInvite = false
    }

    private func applyInvite(sessionID: UUID, videoURL: String, hostName: String) {
        pendingInvite = WatchTogetherInvite(
            sessionID: sessionID,
            videoURL: videoURL,
            hostName: hostName
        )
    }
}
