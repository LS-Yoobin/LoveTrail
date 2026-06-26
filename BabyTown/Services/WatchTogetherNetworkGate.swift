import Foundation
import Network
import Combine

@MainActor
final class WatchTogetherNetworkGate: ObservableObject {
    @Published private(set) var isCameraAllowed = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "covela.watchtogether.network")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let allowed = Self.isCameraAllowed(for: path)
            Task { @MainActor in self?.isCameraAllowed = allowed }
        }
        monitor.start(queue: queue)
    }

    nonisolated private static func isCameraAllowed(for path: NWPath) -> Bool {
        guard path.status == .satisfied else { return false }
        if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.cellular) {
            return true
        }
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func stop() {
        monitor.cancel()
        isCameraAllowed = false
    }
}
