import SpriteKit

/// Lightweight parade of adoptable cats for the app launch splash.
final class LaunchCatScene: SKScene {

    private struct CatFrame {
        let name: String
        let texture: SKTexture
    }

    private enum RunnerBehavior {
        case stopAndSit
        case walkAcross
    }

    private struct RunnerConfig {
        let skin: CatSkin
        let displayHeight: CGFloat
        let destinationXFraction: CGFloat
        let destinationYFraction: CGFloat
        let startDelay: TimeInterval
        let behavior: RunnerBehavior
    }

    private let walkSpeed: CGFloat = 140

    private var hasStarted = false

    private static let runners: [RunnerConfig] = [
        RunnerConfig(
            skin: .calico,
            displayHeight: 92,
            destinationXFraction: 0.5,
            destinationYFraction: 0.48,
            startDelay: 0,
            behavior: .stopAndSit
        ),
        RunnerConfig(
            skin: .cowCat,
            displayHeight: 108,
            destinationXFraction: 0.64,
            destinationYFraction: 0.44,
            startDelay: 0.22,
            behavior: .walkAcross
        )
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

    func restartParade() {
        removeAllChildren()
        hasStarted = false
        startParadeIfNeeded()
    }

    private func spawnRunner(_ config: RunnerConfig) {
        let atlas = SKTextureAtlas(named: config.skin.atlasName)

        let root = SKNode()
        let visual = SKSpriteNode()
        visual.anchorPoint = CGPoint(x: 0.5, y: 0)

        root.addChild(visual)
        addChild(root)

        let y = size.height * config.destinationYFraction
        let start = CGPoint(x: -config.displayHeight, y: y)
        root.position = start

        let walkFrames = frames(from: atlas, prefixes: ["walk_"])

        switch config.behavior {
        case .stopAndSit:
            let destination = CGPoint(
                x: size.width * config.destinationXFraction,
                y: y
            )
            face(visual, towards: destination.x, from: start.x)
            let sitFrames = frames(from: atlas, prefixes: ["sit_"])

            let begin = SKAction.sequence([
                .wait(forDuration: config.startDelay),
                .run { [weak self, weak root, weak visual] in
                    guard let self, let root, let visual else { return }
                    self.playWalkAnimation(on: visual, frames: walkFrames, displayHeight: config.displayHeight)
                    self.runToPositionAndSit(
                        root: root,
                        visual: visual,
                        destination: destination,
                        sitFrames: sitFrames,
                        displayHeight: config.displayHeight
                    )
                }
            ])
            root.run(begin)

        case .walkAcross:
            let exit = CGPoint(x: size.width + config.displayHeight, y: y)
            face(visual, towards: exit.x, from: start.x)

            let begin = SKAction.sequence([
                .wait(forDuration: config.startDelay),
                .run { [weak self, weak root, weak visual] in
                    guard let self, let root, let visual else { return }
                    self.playWalkAnimation(on: visual, frames: walkFrames, displayHeight: config.displayHeight)
                    self.walkAcrossScreen(
                        root: root,
                        destination: exit
                    )
                }
            ])
            root.run(begin)
        }
    }

    private func runToPositionAndSit(
        root: SKNode,
        visual: SKSpriteNode,
        destination: CGPoint,
        sitFrames: [CatFrame],
        displayHeight: CGFloat
    ) {
        let distance = hypot(destination.x - root.position.x, destination.y - root.position.y)
        let duration = max(0.55, TimeInterval(distance / walkSpeed))

        let move = SKAction.move(to: destination, duration: duration)
        move.timingMode = .easeOut

        let settle = SKAction.run { [weak self, weak visual] in
            guard let self, let visual else { return }
            visual.removeAction(forKey: "walk")
            self.startSitAnimation(on: visual, frames: sitFrames, displayHeight: displayHeight)
        }

        root.run(.sequence([move, settle]), withKey: "approach")
    }

    private func walkAcrossScreen(root: SKNode, destination: CGPoint) {
        let distance = hypot(destination.x - root.position.x, destination.y - root.position.y)
        let duration = max(0.55, TimeInterval(distance / walkSpeed))

        let move = SKAction.move(to: destination, duration: duration)
        move.timingMode = .linear
        root.run(move, withKey: "cross")
    }

    private func playWalkAnimation(on visual: SKSpriteNode, frames: [CatFrame], displayHeight: CGFloat) {
        guard let firstFrame = frames.first else { return }
        apply(firstFrame, to: visual, displayHeight: displayHeight)
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

    private func startSitAnimation(on visual: SKSpriteNode, frames: [CatFrame], displayHeight: CGFloat) {
        guard let first = frames.first else { return }
        apply(first, to: visual, displayHeight: displayHeight)

        guard frames.count >= 3 else { return }

        let wait = { SKAction.wait(forDuration: 2.0) }
        let show: (CatFrame) -> SKAction = { [weak self, weak visual] frame in
            .run {
                guard let self, let visual else { return }
                self.apply(frame, to: visual, displayHeight: displayHeight)
            }
        }

        visual.run(
            .repeatForever(.sequence([
                wait(), show(frames[1]),
                wait(), show(frames[2])
            ])),
            withKey: "sit"
        )
    }

    private func apply(_ frame: CatFrame, to visual: SKSpriteNode, displayHeight: CGFloat) {
        visual.texture = frame.texture
        visual.size = Self.displaySize(for: frame.texture, targetHeight: displayHeight)
    }

    private func face(_ visual: SKSpriteNode, towards x: CGFloat, from currentX: CGFloat) {
        visual.xScale = x >= currentX ? 1 : -1
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
