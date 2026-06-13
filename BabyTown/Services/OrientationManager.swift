import UIKit

/// Controls the app-wide interface orientation mask.
/// AppDelegate reads `currentMask` via `supportedInterfaceOrientationsFor:`.
/// Call `lockLandscape()` / `lockPortrait()` to switch modes.
final class OrientationManager {
    static let shared = OrientationManager()
    private init() {}

    private(set) var currentMask: UIInterfaceOrientationMask = .portrait

    /// Opens the door to landscape rotation without forcing it yet.
    func allowLandscape() {
        currentMask = .allButUpsideDown
    }

    /// Locks to landscape and requests the rotation immediately.
    func lockLandscape() {
        currentMask = .landscape
        requestOrientation(.landscapeRight)
    }

    /// Returns to portrait-only and requests the rotation immediately.
    func lockPortrait() {
        currentMask = .portrait
        requestOrientation(.portrait)
    }

    private func requestOrientation(_ orientation: UIInterfaceOrientation) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let mask: UIInterfaceOrientationMask = orientation == .portrait ? .portrait : .landscape
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        // Notify the root view controller so it respects the new mask immediately.
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
