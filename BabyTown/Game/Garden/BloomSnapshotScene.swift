import SpriteKit
import GardenCore

final class BloomSnapshotScene: SKScene {
    private let entry: BloomCatalogEntry

    init(entry: BloomCatalogEntry) {
        self.entry = entry
        super.init(size: CGSize(width: 100, height: 130))
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        let node: SKNode
        if entry.isTree {
            node = LoveGardenScene.makeTree()
        } else {
            node = LoveGardenScene.makeFlower(
                chapter: entry.chapter!,
                shape: entry.shape!,
                season: .blooming,
                cycle: 0,
                isLegend: entry.isLegend
            )
        }
        node.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        addChild(node)
    }
}
