import UIKit

/// Controls the app-wide interface orientation mask.
/// AppDelegate reads `currentMask` via `supportedInterfaceOrientationsFor:`.
/// Call `lockLandscape()` / `lockPortrait()` to switch modes.
@MainActor
final class OrientationManager {
    static let shared = OrientationManager()
    private init() {}

    private(set) var currentMask: UIInterfaceOrientationMask = .portrait

    /// Opens the door to landscape rotation without forcing it yet.
    func allowLandscape() {
        currentMask = .allButUpsideDown
        notifyOrientationUpdate()
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

    /// Applies the portrait mask without forcing a device rotation.
    func setPortraitMaskOnly() {
        currentMask = .portrait
        notifyOrientationUpdate()
    }

    /// Rotates to portrait while a fullscreen cover is still visible, then runs `completion`.
    /// Keeps Secret Garden from flashing in landscape when Watch Together closes.
    func exitToPortrait(then completion: @escaping () -> Void) {
        currentMask = .portrait

        guard let scene = activeWindowScene else {
            completion()
            return
        }

        if scene.interfaceOrientation.isPortrait {
            notifyOrientationUpdate()
            completion()
            return
        }

        requestOrientation(.portrait)
        Task {
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(50))
                if activeWindowScene?.interfaceOrientation.isPortrait == true { break }
            }
            completion()
        }
    }

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.first as? UIWindowScene
    }

    private func requestOrientation(_ orientation: UIInterfaceOrientation) {
        guard let scene = activeWindowScene else { return }
        let mask: UIInterfaceOrientationMask = orientation == .portrait ? .portrait : .landscape
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        notifyOrientationUpdate()
    }

    private func notifyOrientationUpdate() {
        activeWindowScene?.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
