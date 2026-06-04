import SpriteKit
import UIKit
import GardenCore

/// The Love Garden scene. Renders garden elements (one flower per day with a
/// saved moment, one tree per love letter) as procedural blooms — no art assets
/// required. Sibling
/// to `PetRoomScene`; the cat room is never touched.
final class LoveGardenScene: SKScene {

    /// Reports the source act id of a tapped bloom so the SwiftUI layer can
    /// surface that memory.
    var onTapElement: ((UUID) -> Void)?

    private let elements: [GardenElement]
    private let season: GardenSeason
    /// When true, blooms and backdrop are drawn at rest with no motion (thumbnails).
    private let isStaticSnapshot: Bool
    private var elementNodes: [UUID: SKNode] = [:]

    init(
        size: CGSize,
        elements: [GardenElement],
        season: GardenSeason,
        isStaticSnapshot: Bool = false
    ) {
        self.elements = elements
        self.season = season
        self.isStaticSnapshot = isStaticSnapshot
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        addSkyBackdrop()
        addDistantHills()
        drawGround()
        if !isStaticSnapshot {
            addDriftingClouds()
        } else {
            addStaticClouds()
        }
        for (index, element) in elements.enumerated() {
            let node = makeNode(for: element)
            node.position = screenPosition(for: element.position)
            node.zPosition = node.position.y
            node.name = element.sourceID.uuidString
            addChild(node)
            elementNodes[element.sourceID] = node

            let depthScale = bloomDepthScale(normalizedY: CGFloat(element.position.y))
            if isStaticSnapshot {
                node.setScale(depthScale)
            } else {
                animateGrowth(node, targetScale: depthScale, delay: Double(index) * 0.03)
                addSway(to: node, seed: element.position.x)
            }
        }
        if !isStaticSnapshot {
            addAmbientParticles()
            if season == .blooming {
                addFallingPetals()
            }
        }
    }

    // MARK: Layout

    private func screenPosition(for p: GardenPoint) -> CGPoint {
        CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
    }

    /// Matches `GardenComposer` planting band — lower on screen reads closer/larger.
    private func bloomDepthScale(normalizedY: CGFloat) -> CGFloat {
        let bandLow: CGFloat = 0.08
        let bandHigh: CGFloat = 0.42
        let span = max(bandHigh - bandLow, 0.001)
        let t = min(max((normalizedY - bandLow) / span, 0), 1)
        let frontScale: CGFloat = 1.24
        let backScale: CGFloat = 0.76
        return frontScale + (backScale - frontScale) * t
    }

    private func drawGround() {
        let groundHeight = size.height * 0.45
        let ground = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width,
                                              height: groundHeight))
        ground.fillColor = Self.groundColor(for: season)
        ground.strokeColor = .clear
        ground.zPosition = -1
        addChild(ground)

        let frontHill = SKShapeNode(
            ellipseIn: CGRect(x: -size.width * 0.1, y: groundHeight * 0.55,
                              width: size.width * 1.2, height: groundHeight * 0.9)
        )
        frontHill.fillColor = Self.groundColor(for: season).withAlphaComponent(0.55)
        frontHill.strokeColor = .clear
        frontHill.zPosition = 0.5
        addChild(frontHill)
    }

    // MARK: Backdrop polish (gradient sky, parallax hills, clouds, petals)

    private func addSkyBackdrop() {
        let texture = Self.skyGradientTexture(size: size, season: season)
        let sky = SKSpriteNode(texture: texture)
        sky.size = size
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.zPosition = -12
        addChild(sky)
    }

    private func addDistantHills() {
        let back = SKShapeNode(
            ellipseIn: CGRect(x: -size.width * 0.15, y: size.height * 0.28,
                              width: size.width * 1.3, height: size.height * 0.22)
        )
        back.fillColor = Self.hillColor(for: season, depth: .back)
        back.strokeColor = .clear
        back.zPosition = -4
        addChild(back)

        let mid = SKShapeNode(
            ellipseIn: CGRect(x: -size.width * 0.05, y: size.height * 0.22,
                              width: size.width * 1.15, height: size.height * 0.18)
        )
        mid.fillColor = Self.hillColor(for: season, depth: .mid)
        mid.strokeColor = .clear
        mid.zPosition = -3
        addChild(mid)

        guard !isStaticSnapshot else { return }
        let drift = SKAction.repeatForever(.sequence([
            .moveBy(x: 6, y: 0, duration: 14),
            .moveBy(x: -6, y: 0, duration: 14),
        ]))
        mid.run(drift)
    }

    private func addStaticClouds() {
        for i in 0..<3 {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: 90 + CGFloat(i) * 18, height: 34))
            cloud.fillColor = SKColor(white: 1, alpha: season == .blooming ? 0.55 : 0.38)
            cloud.strokeColor = .clear
            cloud.position = CGPoint(
                x: size.width * (0.2 + CGFloat(i) * 0.28),
                y: size.height * (0.72 + CGFloat(i) * 0.04)
            )
            cloud.zPosition = -2
            addChild(cloud)
        }
    }

    private func addDriftingClouds() {
        for i in 0..<3 {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: 90 + CGFloat(i) * 18, height: 34))
            cloud.fillColor = SKColor(white: 1, alpha: season == .blooming ? 0.55 : 0.38)
            cloud.strokeColor = .clear
            cloud.position = CGPoint(
                x: size.width * (0.2 + CGFloat(i) * 0.28),
                y: size.height * (0.72 + CGFloat(i) * 0.04)
            )
            cloud.zPosition = -2
            addChild(cloud)
            let travel = SKAction.repeatForever(.sequence([
                .moveBy(x: 24, y: 0, duration: 18 + Double(i) * 4),
                .moveBy(x: -24, y: 0, duration: 18 + Double(i) * 4),
            ]))
            cloud.run(travel)
        }
    }

    private func addFallingPetals() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.softDot()
        emitter.position = CGPoint(x: size.width / 2, y: size.height)
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        emitter.particleBirthRate = 3
        emitter.particleLifetime = 10
        emitter.particleSpeed = 28
        emitter.particleSpeedRange = 14
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 4
        emitter.particleAlpha = 0.7
        emitter.particleScale = 0.22
        emitter.particleColor = Self.flowerPalette(season)
        emitter.particleColorBlendFactor = 1
        emitter.zPosition = 4500
        addChild(emitter)
    }

    private enum HillDepth { case back, mid }

    private static func hillColor(for season: GardenSeason, depth: HillDepth) -> SKColor {
        switch (season, depth) {
        case (.blooming, .back): return SKColor(red: 0.58, green: 0.72, blue: 0.52, alpha: 0.85)
        case (.blooming, .mid):  return SKColor(red: 0.62, green: 0.76, blue: 0.56, alpha: 0.9)
        case (.resting, .back):  return SKColor(red: 0.70, green: 0.74, blue: 0.72, alpha: 0.85)
        case (.resting, .mid):   return SKColor(red: 0.74, green: 0.78, blue: 0.76, alpha: 0.9)
        }
    }

    static func skyGradientTexture(size: CGSize, season: GardenSeason) -> SKTexture {
        let top = skyColor(for: season)
        let bottom = (season == .blooming)
            ? SKColor(red: 0.88, green: 0.94, blue: 1.0, alpha: 1)
            : SKColor(red: 0.86, green: 0.88, blue: 0.92, alpha: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width / 2, y: size.height),
                    end: CGPoint(x: size.width / 2, y: 0),
                    options: []
                )
            }
        }
        return SKTexture(image: image)
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
    private func animateGrowth(_ node: SKNode, targetScale: CGFloat, delay: TimeInterval) {
        node.setScale(0)
        let overshoot = targetScale * 1.08
        let grow = SKAction.sequence([
            .wait(forDuration: delay),
            .scale(to: overshoot, duration: 0.28),
            .scale(to: targetScale, duration: 0.12),
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

    // Slice 1 surfaces a memory card only for moment-sourced blooms. Tapping a
    // tree (letter-sourced) reports its id, but the host has no letter card yet —
    // intentional scope gap; the letter card arrives in a later slice.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        // Walk up from the hit node to find the element container we named.
        var node: SKNode? = atPoint(location)
        while let current = node {
            if let name = current.name, let id = UUID(uuidString: name) {
                let rest = current.xScale
                let bump = SKAction.sequence([.scale(to: rest * 1.18, duration: 0.08),
                                              .scale(to: rest, duration: 0.12)])
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
