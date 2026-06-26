import Foundation
import Combine

@MainActor
final class WatchTogetherSessionService: ObservableObject {
    let callController = WatchTogetherCallController()

    private let api: WatchTogetherAPIClientProtocol
    private let signaling: WatchTogetherSignalingClientProtocol

    private(set) var session: WatchTogetherSession?
    private var isHost = false
    private var answerObserver: NSObjectProtocol?
    private var iceObserver: NSObjectProtocol?

    init(
        api: WatchTogetherAPIClientProtocol = StubWatchTogetherAPIClient.shared,
        signaling: WatchTogetherSignalingClientProtocol = StubWatchTogetherSignalingClient()
    ) {
        self.api = api
        self.signaling = signaling
    }

    func startHosting(videoURL: String) async throws {
        let created = try await api.createSession(videoURL: videoURL)
        session = created
        isHost = true
        try await signaling.connect(sessionID: created.id)
        callController.configure(isHost: true)
        wireSignaling()
        let offer = try await callController.createOffer()
        try await signaling.send(offer)

        let hostName = DataPersistenceManager.shared.loadUserNickname() ?? "Your partner"
        NotificationManager.shared.handlePartnerEvent(
            .watchTogetherInvite(hostName: hostName, sessionID: created.id, videoURL: videoURL)
        )
    }

    func join(sessionID: UUID) async throws {
        let joined = try await api.joinSession(id: sessionID)
        session = joined
        isHost = false
        try await signaling.connect(sessionID: joined.id)
        callController.configure(isHost: false)
        wireSignaling()
    }

    func end() async {
        callController.endCall()
        signaling.disconnect()
        removeLocalObservers()
        // Only the host ends the shared session; joiners just disconnect locally so rejoin works.
        if isHost, let session {
            try? await api.endSession(id: session.id)
        }
        self.session = nil
        isHost = false
    }

    private func wireSignaling() {
        removeLocalObservers()

        signaling.onMessage = { [weak self] message in
            Task { @MainActor in
                guard let self else { return }
                do {
                    try await self.callController.handleRemoteSignal(message)
                } catch {
                    print("WatchTogether signaling error: \(error.localizedDescription)")
                }
            }
        }

        answerObserver = NotificationCenter.default.addObserver(
            forName: .watchTogetherLocalAnswerReady,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let message = note.object as? WatchTogetherSignalMessage else { return }
            Task { @MainActor in
                try? await self?.signaling.send(message)
            }
        }

        iceObserver = NotificationCenter.default.addObserver(
            forName: .watchTogetherLocalIceCandidate,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let message = note.object as? WatchTogetherSignalMessage else { return }
            Task { @MainActor in
                try? await self?.signaling.send(message)
            }
        }
    }

    private func removeLocalObservers() {
        if let answerObserver {
            NotificationCenter.default.removeObserver(answerObserver)
        }
        if let iceObserver {
            NotificationCenter.default.removeObserver(iceObserver)
        }
        answerObserver = nil
        iceObserver = nil
    }
}
