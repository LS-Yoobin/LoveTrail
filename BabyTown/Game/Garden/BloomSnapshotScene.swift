import SpriteKit
import GardenCore

final class BloomSnapshotScene: SKScene {
    private let entry: BloomCatalogEntry

    static func sceneSize(for entry: BloomCatalogEntry) -> CGSize {
        entry.isTree ? CGSize(width: 100, height: 150) : CGSize(width: 100, height: 130)
    }

    init(entry: BloomCatalogEntry) {
        self.entry = entry
        super.init(size: Self.sceneSize(for: entry))
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        let node: SKNode
        if entry.isTree {
            node = LoveGardenScene.makeTree()
            node.setScale(0.82)
            node.position = CGPoint(x: size.width / 2, y: size.height * 0.05)
        } else {
            node = LoveGardenScene.makeFlower(
                chapter: entry.chapter!,
                shape: entry.shape!,
                season: .blooming,
                cycle: 0,
                isLegend: entry.isLegend
            )
            node.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        }
        addChild(node)
    }
}
