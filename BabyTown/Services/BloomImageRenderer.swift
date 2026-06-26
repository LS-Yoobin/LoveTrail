import SpriteKit
import UIKit

@MainActor
final class BloomImageRenderer {
    static let shared = BloomImageRenderer()

    private var cache: [String: UIImage] = [:]

    func render(entry: BloomCatalogEntry) async -> UIImage? {
        if let cached = cache[entry.cacheKey] { return cached }

        let size = CGSize(width: 100, height: 130)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.allowsTransparency = true

        let scene = BloomSnapshotScene(entry: entry)
        scene.isPaused = true
        view.presentScene(scene)

        await waitForRenderPass()
        if let image = snapshot(from: view, scene: scene) {
            cache[entry.cacheKey] = image
            return image
        }
        await waitForRenderPass()
        let image = snapshot(from: view, scene: scene)
        if let image { cache[entry.cacheKey] = image }
        return image
    }

    private func snapshot(from view: SKView, scene: BloomSnapshotScene) -> UIImage? {
        guard let texture = view.texture(from: scene) else { return nil }
        return UIImage(cgImage: texture.cgImage())
    }

    private func waitForRenderPass() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
        }
    }
}
