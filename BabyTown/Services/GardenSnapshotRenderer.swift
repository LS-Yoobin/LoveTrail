import SpriteKit
import UIKit
import GardenCore

/// Renders a single-frame image of the couple garden for compact UI (e.g. Home Us card).
enum GardenSnapshotRenderer {

    private static let renderSize = CGSize(width: 150, height: 150)

    static func render(moments: [Moment], letters: [UserLetter], season: GardenSeason) -> UIImage? {
        let acts = GardenActMapper.acts(moments: moments, letters: letters)
        let elements = GardenComposer().compose(acts: acts)
        let view = SKView(frame: CGRect(origin: .zero, size: renderSize))
        view.allowsTransparency = true
        view.isPaused = true

        let scene = LoveGardenScene(
            size: renderSize,
            elements: elements,
            season: season,
            isStaticSnapshot: true
        )
        view.presentScene(scene)

        guard let texture = view.texture(from: scene) else { return nil }
        return UIImage(cgImage: texture.cgImage())
    }
}
