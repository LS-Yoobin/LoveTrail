import SpriteKit
import UIKit
import GardenCore

/// The Love Garden scene. Renders garden elements (grown from the couple's
/// moments and letters) as procedural blooms — no art assets required. Sibling
/// to `PetRoomScene`; the cat room is never touched.
final class LoveGardenScene: SKScene {

    /// Reports the source act id of a tapped bloom so the SwiftUI layer can
    /// surface that memory.
    var onTapElement: ((UUID) -> Void)?

    private let elements: [GardenElement]
    private let season: GardenSeason
    private var elementNodes: [UUID: SKNode] = [:]

    init(size: CGSize, elements: [GardenElement], season: GardenSeason) {
        self.elements = elements
        self.season = season
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = Self.skyColor(for: season)
        drawGround()
        for (index, element) in elements.enumerated() {
            let node = makeNode(for: element)
            node.position = screenPosition(for: element.position)
            node.zPosition = node.position.y
            node.name = element.sourceID.uuidString
            addChild(node)
            elementNodes[element.sourceID] = node

            animateGrowth(node, delay: Double(index) * 0.03)
            addSway(to: node, seed: element.position.x)
        }
        addAmbientParticles()
    }

    // MARK: Layout

    private func screenPosition(for p: GardenPoint) -> CGPoint {
        CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
    }

    private func drawGround() {
        let ground = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width,
                                              height: size.height * 0.45))
        ground.fillColor = Self.groundColor(for: season)
        ground.strokeColor = .clear
        ground.zPosition = -1
        addChild(ground)
    }

    // MARK: Procedural elements

    private func makeNode(for element: GardenElement) -> SKNode {
        switch element.kind {
        case .flower:      return makeFlower(petalColor: Self.flowerPalette(season))
        case .placeFlower: return makeFlower(petalColor: Self.placePalette(season))
        case .tree:        return makeTree()
        }
    }

    private func makeFlower(petalColor: SKColor) -> SKNode {
        let container = SKNode()

        let stem = SKShapeNode(rect: CGRect(x: -2, y: 0, width: 4, height: 46))
        stem.fillColor = SKColor(red: 0.36, green: 0.55, blue: 0.32, alpha: 1)
        stem.strokeColor = .clear
        container.addChild(stem)

        let head = SKNode()
        head.position = CGPoint(x: 0, y: 50)
        for i in 0..<6 {
            let petal = SKShapeNode(ellipseOf: CGSize(width: 12, height: 22))
            petal.fillColor = petalColor
            petal.strokeColor = .clear
            petal.zRotation = CGFloat(i) * (.pi / 3)
            petal.position = CGPoint(x: 0, y: 12)
            let holder = SKNode()
            holder.zRotation = CGFloat(i) * (.pi / 3)
            holder.addChild(petal)
            head.addChild(holder)
        }
        let center = SKShapeNode(circleOfRadius: 7)
        center.fillColor = SKColor(red: 0.98, green: 0.85, blue: 0.45, alpha: 1)
        center.strokeColor = .clear
        head.addChild(center)
        container.addChild(head)
        return container
    }

    private func makeTree() -> SKNode {
        let container = SKNode()
        let trunk = SKShapeNode(rect: CGRect(x: -5, y: 0, width: 10, height: 70))
        trunk.fillColor = SKColor(red: 0.45, green: 0.33, blue: 0.24, alpha: 1)
        trunk.strokeColor = .clear
        container.addChild(trunk)

        let canopy = SKShapeNode(circleOfRadius: 34)
        canopy.position = CGPoint(x: 0, y: 86)
        canopy.fillColor = SKColor(red: 0.34, green: 0.56, blue: 0.34, alpha: 1)
        canopy.strokeColor = .clear
        container.addChild(canopy)
        return container
    }

    // MARK: Palette (season-aware; resting is calmer / cooler)

    static func skyColor(for season: GardenSeason) -> SKColor {
        switch season {
        case .blooming: return SKColor(red: 0.78, green: 0.90, blue: 0.98, alpha: 1)
        case .resting:  return SKColor(red: 0.83, green: 0.86, blue: 0.92, alpha: 1)
        }
    }
    static func groundColor(for season: GardenSeason) -> SKColor {
        switch season {
        case .blooming: return SKColor(red: 0.66, green: 0.80, blue: 0.55, alpha: 1)
        case .resting:  return SKColor(red: 0.74, green: 0.78, blue: 0.74, alpha: 1)
        }
    }
    static func flowerPalette(_ season: GardenSeason) -> SKColor {
        switch season {
        case .blooming: return SKColor(red: 0.93, green: 0.45, blue: 0.62, alpha: 1)
        case .resting:  return SKColor(red: 0.74, green: 0.66, blue: 0.78, alpha: 1)
        }
    }
    static func placePalette(_ season: GardenSeason) -> SKColor {
        switch season {
        case .blooming: return SKColor(red: 0.55, green: 0.62, blue: 0.95, alpha: 1)
        case .resting:  return SKColor(red: 0.62, green: 0.66, blue: 0.80, alpha: 1)
        }
    }

    // MARK: Living layer — growth, sway, particles

    /// Sprout → bloom: pop up from nothing with a gentle overshoot.
    private func animateGrowth(_ node: SKNode, delay: TimeInterval) {
        node.setScale(0)
        let grow = SKAction.sequence([
            .wait(forDuration: delay),
            .scale(to: 1.08, duration: 0.28),
            .scale(to: 1.0, duration: 0.12),
        ])
        grow.timingMode = .easeOut
        node.run(grow)
    }

    /// Gentle, endless sway. The seed offsets each bloom's phase so the field
    /// doesn't move in lockstep.
    private func addSway(to node: SKNode, seed: Double) {
        let amplitude: CGFloat = 0.05
        let phase = SKAction.sequence([
            .rotate(toAngle: amplitude, duration: 1.6),
            .rotate(toAngle: -amplitude, duration: 1.6),
        ])
        phase.timingMode = .easeInEaseOut
        let sway = SKAction.repeatForever(phase)
        node.run(.sequence([.wait(forDuration: seed.truncatingRemainder(dividingBy: 1.0) * 1.6), sway]))
    }

    /// Drifting pollen by day, fireflies feel at dusk. Pure code (no art).
    private func addAmbientParticles() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.softDot()
        emitter.position = CGPoint(x: size.width / 2, y: size.height)
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        emitter.particleBirthRate = 6
        emitter.particleLifetime = 14
        emitter.particleSpeed = 18
        emitter.particleSpeedRange = 10
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 6
        emitter.particleAlpha = 0.55
        emitter.particleAlphaRange = 0.3
        emitter.particleScale = 0.18
        emitter.particleScaleRange = 0.12
        emitter.particleColor = (season == .resting)
            ? SKColor.white
            : SKColor(red: 1.0, green: 0.95, blue: 0.7, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.zPosition = 5000
        addChild(emitter)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        // Walk up from the hit node to find the element container we named.
        var node: SKNode? = atPoint(location)
        while let current = node {
            if let name = current.name, let id = UUID(uuidString: name) {
                let bump = SKAction.sequence([.scale(to: 1.18, duration: 0.08),
                                              .scale(to: 1.0, duration: 0.12)])
                current.run(bump)
                onTapElement?(id)
                return
            }
            node = current.parent
        }
    }

    /// A small soft circle texture used for particles, generated in code.
    static func softDot() -> SKTexture {
        let d: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor)
            c.fillEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
        }
        return SKTexture(image: image)
    }
}
