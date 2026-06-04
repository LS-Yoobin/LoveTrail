import SpriteKit

/// Lightweight parade of adoptable cats for the app launch splash.
final class LaunchCatScene: SKScene {

    private struct CatFrame {
        let name: String
        let texture: SKTexture
    }

    private struct RunnerConfig {
        let skin: CatSkin
        let destinationXFraction: CGFloat
        let destinationYFraction: CGFloat
        let startDelay: TimeInterval
    }

    private let catDisplayHeight: CGFloat = 92
    private let walkSpeed: CGFloat = 140

    private var hasStarted = false
    private var frameDisplaySizes: [String: CGSize] = [:]

    private static let runners: [RunnerConfig] = [
        RunnerConfig(skin: .calico, destinationXFraction: 0.36, destinationYFraction: 0.48, startDelay: 0),
        RunnerConfig(skin: .cowCat, destinationXFraction: 0.64, destinationYFraction: 0.44, startDelay: 0.22)
    ]

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        startParadeIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        removeAllChildren()
        hasStarted = false
        startParadeIfNeeded()
    }

    func startParadeIfNeeded() {
        guard size.width > 0, size.height > 0, !hasStarted else { return }
        hasStarted = true

        for config in Self.runners {
            spawnRunner(config)
        }
    }

    private func spawnRunner(_ config: RunnerConfig) {
        let atlas = SKTextureAtlas(named: config.skin.atlasName)
        cacheFrameSizes(from: atlas)

        let root = SKNode()
        let visual = SKSpriteNode()
        visual.anchorPoint = CGPoint(x: 0.5, y: 0)

        root.addChild(visual)
        addChild(root)

        let destination = CGPoint(
            x: size.width * config.destinationXFraction,
            y: size.height * config.destinationYFraction
        )
        let start = CGPoint(x: -catDisplayHeight, y: destination.y)
        root.position = start
        face(visual, towards: destination.x, from: start.x)

        let walkFrames = frames(from: atlas, prefixes: ["walk_"])
        let idleFrames = frames(from: atlas, prefixes: ["stand_", "idle_"])

        let begin = SKAction.sequence([
            .wait(forDuration: config.startDelay),
            .run { [weak self, weak root, weak visual] in
                guard let self, let root, let visual else { return }
                self.playWalkAnimation(on: visual, frames: walkFrames)
                self.runToPosition(
                    root: root,
                    visual: visual,
                    destination: destination,
                    idleFrames: idleFrames
                )
            }
        ])
        root.run(begin)
    }

    private func runToPosition(
        root: SKNode,
        visual: SKSpriteNode,
        destination: CGPoint,
        idleFrames: [CatFrame]
    ) {
        let distance = hypot(destination.x - root.position.x, destination.y - root.position.y)
        let duration = max(0.55, TimeInterval(distance / walkSpeed))

        let move = SKAction.move(to: destination, duration: duration)
        move.timingMode = .easeOut

        let settle = SKAction.run { [weak self, weak visual] in
            guard let self, let visual else { return }
            visual.removeAction(forKey: "walk")
            self.startIdleAnimation(on: visual, frames: idleFrames)
        }

        root.run(.sequence([move, settle]), withKey: "approach")
    }

    private func playWalkAnimation(on visual: SKSpriteNode, frames: [CatFrame]) {
        guard let firstFrame = frames.first else { return }
        apply(firstFrame, to: visual)
        guard frames.count > 1 else { return }

        visual.run(
            .repeatForever(
                .animate(
                    with: frames.map(\.texture),
                    timePerFrame: 0.08
                )
            ),
            withKey: "walk"
        )
    }

    private func startIdleAnimation(on visual: SKSpriteNode, frames: [CatFrame]) {
        guard let first = frames.first else { return }
        apply(first, to: visual)

        guard frames.count >= 3 else { return }

        let wait = { SKAction.wait(forDuration: 2.4) }
        let show: (CatFrame) -> SKAction = { [weak self, weak visual] frame in
            .run {
                guard let self, let visual else { return }
                self.apply(frame, to: visual)
            }
        }

        visual.run(
            .repeatForever(.sequence([
                wait(), show(frames[1]),
                wait(), show(frames[2])
            ])),
            withKey: "idle"
        )
    }

    private func apply(_ frame: CatFrame, to visual: SKSpriteNode) {
        visual.texture = frame.texture
        visual.size = frameDisplaySizes[frame.name]
            ?? Self.displaySize(for: frame.texture, targetHeight: catDisplayHeight)
    }

    private func face(_ visual: SKSpriteNode, towards x: CGFloat, from currentX: CGFloat) {
        visual.xScale = x >= currentX ? 1 : -1
    }

    private func cacheFrameSizes(from atlas: SKTextureAtlas) {
        for name in atlas.textureNames {
            let texture = atlas.textureNamed(name)
            frameDisplaySizes[name] = Self.displaySize(for: texture, targetHeight: catDisplayHeight)
        }
    }

    private func frames(from atlas: SKTextureAtlas, prefixes: [String]) -> [CatFrame] {
        let names = atlas.textureNames
            .filter { name in prefixes.contains(where: { name.hasPrefix($0) }) }
            .sorted { frameIndex($0) < frameIndex($1) }
        return names.map { CatFrame(name: $0, texture: atlas.textureNamed($0)) }
    }

    private func frameIndex(_ name: String) -> Int {
        let base = (name as NSString).deletingPathExtension
        if let n = base.split(separator: "_").last.flatMap({ Int($0) }) { return n }
        return 0
    }

    private static func displaySize(for texture: SKTexture, targetHeight: CGFloat) -> CGSize {
        let cg = texture.cgImage()
        guard cg.height > 0 else {
            return texture.size().scaledToHeight(targetHeight)
        }
        let aspect = CGFloat(cg.width) / CGFloat(cg.height)
        return CGSize(width: targetHeight * aspect, height: targetHeight)
    }
}

private extension CGSize {
    func scaledToHeight(_ targetHeight: CGFloat) -> CGSize {
        guard height > 0 else { return self }
        let aspect = width / height
        return CGSize(width: targetHeight * aspect, height: targetHeight)
    }
}
