import SpriteKit
import UIKit
import GardenCore

/// Renders a single-frame image of the couple garden for compact UI (e.g. Home Us card).
enum GardenSnapshotRenderer {

    private static let renderSize = CGSize(width: 150, height: 150)

    /// SpriteKit must run on the main actor and needs at least one display pass after
    /// `presentScene` before `texture(from:)` returns pixels (cold launch often fails otherwise).
    @MainActor
    static func render(moments: [Moment], letters: [UserLetter], season: GardenSeason) async -> UIImage? {
        let elements = GardenActMapper.composeElements(moments: moments, letters: letters)
        let view = SKView(frame: CGRect(origin: .zero, size: renderSize))
        view.allowsTransparency = true

        let scene = LoveGardenScene(
            size: renderSize,
            elements: elements,
            season: season,
            isStaticSnapshot: true
        )
        scene.isPaused = true
        view.presentScene(scene)

        await waitForRenderPass()
        if let image = snapshot(from: view, scene: scene) {
            return image
        }

        await waitForRenderPass()
        return snapshot(from: view, scene: scene)
    }

    @MainActor
    private static func snapshot(from view: SKView, scene: LoveGardenScene) -> UIImage? {
        guard let texture = view.texture(from: scene) else { return nil }
        return UIImage(cgImage: texture.cgImage())
    }

    /// Yields until after the next main-runloop turn so the SKView can draw once.
    @MainActor
    private static func waitForRenderPass() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
        }
    }
}
