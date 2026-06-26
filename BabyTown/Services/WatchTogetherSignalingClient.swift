import Foundation

protocol WatchTogetherSignalingClientProtocol: AnyObject {
    var onMessage: ((WatchTogetherSignalMessage) -> Void)? { get set }
    func connect(sessionID: UUID) async throws
    func send(_ message: WatchTogetherSignalMessage) async throws
    func disconnect()
}

/// Dev stub: forwards signals via NotificationCenter. Replace with WebSocket when SUB-3 lands.
final class StubWatchTogetherSignalingClient: WatchTogetherSignalingClientProtocol {
    var onMessage: ((WatchTogetherSignalMessage) -> Void)?
    private var sessionID: UUID?
    private var observer: NSObjectProtocol?

    func connect(sessionID: UUID) async throws {
        self.sessionID = sessionID
        observer = NotificationCenter.default.addObserver(
            forName: .watchTogetherSignalReceived,
            object: sessionID,
            queue: .main
        ) { [weak self] note in
            guard let message = note.userInfo?["message"] as? WatchTogetherSignalMessage else { return }
            self?.onMessage?(message)
        }
    }

    func send(_ message: WatchTogetherSignalMessage) async throws {
        guard let sessionID else { return }
        NotificationCenter.default.post(
            name: .watchTogetherSignalReceived,
            object: sessionID,
            userInfo: ["message": message]
        )
    }

    func disconnect() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        sessionID = nil
    }
}

extension Notification.Name {
    static let watchTogetherSignalReceived = Notification.Name("watchTogetherSignalReceived")
}
