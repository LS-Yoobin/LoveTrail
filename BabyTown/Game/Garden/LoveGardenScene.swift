import SpriteKit
import UIKit
import GardenCore

/// The Love Garden scene. Renders milestone bouquets, annual birthday/anniversary
/// blooms, shrine flowers at 50/100 moments, and one tree per love letter.
final class LoveGardenScene: SKScene {

    /// Reports the source act id of a tapped bloom so the SwiftUI layer can
    /// surface that memory.
    var onTapElement: ((UUID) -> Void)?
    /// When false, bloom nodes ignore touches (Edit Garden and other overlay modes).
    var allowsBloomInteraction = true

    private let elements: [GardenElement]
    private let season: GardenSeason
    /// When true, blooms and backdrop are drawn at rest with no motion (thumbnails).
    private let isStaticSnapshot: Bool
    /// When true with `isStaticSnapshot`, clouds drift within the scene bounds (home card).
    private let animateClouds: Bool
    /// When true, sky and clouds are omitted so a SwiftUI night backdrop shows through.
    private let isNightMode: Bool
    private var elementNodes: [UUID: SKNode] = [:]

    init(
        size: CGSize,
        elements: [GardenElement],
        season: GardenSeason,
        isStaticSnapshot: Bool = false,
        isNightMode: Bool = false,
        animateClouds: Bool = false
    ) {
        self.elements = elements
        self.season = season
        self.isStaticSnapshot = isStaticSnapshot
        self.isNightMode = isNightMode
        self.animateClouds = animateClouds
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        if !isNightMode {
            addSkyBackdrop()
        }
        addDistantHills()
        drawGround()
        if !isNightMode {
            switch cloudMotionStyle {
            case .still:
                addStaticClouds()
            case .fieldDrift:
                addDriftingClouds()
            case .boundedDrift:
                addBoundedDriftingClouds()
            }
        }
        for (index, element) in elements.enumerated() {
            let node = makeNode(for: element)
            node.position = screenPosition(for: element.position)
            node.zPosition = Self.floorDepthZ(for: node.position.y, sceneHeight: size.height)
            node.name = element.sourceID.uuidString
            addChild(node)
            elementNodes[element.sourceID] = node

            var depthScale = bloomDepthScale(normalizedY: CGFloat(element.position.y))
            if element.isLegend {
                depthScale *= 1.35
            } else if element.kind == .flower && element.shape == .daisy12 {
                depthScale *= 1.22
            }
            if isStaticSnapshot {
                node.setScale(depthScale)
                if animateClouds {
                    addSway(to: node, seed: element.position.x)
                }
            } else {
                animateGrowth(node, targetScale: depthScale, delay: Double(index) * 0.03)
                addSway(to: node, seed: element.position.x)
                if element.isLegend { addLegendShimmer(to: node) }
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

    private enum CloudMotionStyle {
        case still
        case fieldDrift
        case boundedDrift
    }

    private var cloudMotionStyle: CloudMotionStyle {
        if isStaticSnapshot {
            return animateClouds ? .boundedDrift : .still
        }
        return .fieldDrift
    }

    /// Draw order for blooms and roaming cats — lower Y (closer to camera) renders
    /// in front, matching pet-room `propDepthZ` (front = higher z, back = lower z).
    static func floorDepthZ(for baseY: CGFloat, sceneHeight: CGFloat) -> CGFloat {
        let frontEdge = sceneHeight * 0.02
        let backEdge = sceneHeight * 0.46
        let span = max(backEdge - frontEdge, 1)
        let t = min(max((baseY - frontEdge) / span, 0), 1) // 0 front … 1 back
        let frontZ: CGFloat = 420
        let backZ: CGFloat = 80
        return frontZ + (backZ - frontZ) * t
    }

    /// Adds a live pet cat so it depth-sorts against blooms in this scene.
    func adoptGardenCat(_ cat: SKNode) {
        guard cat.parent !== self else { return }
        cat.removeFromParent()
        addChild(cat)
    }

    private func screenPosition(for p: GardenPoint) -> CGPoint {
        CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
    }

    /// Matches `GardenComposer` planting band — lower on screen reads closer/larger.
    static func bloomDepthScale(normalizedY: CGFloat) -> CGFloat {
        let bandLow: CGFloat = 0.08
        let bandHigh: CGFloat = 0.42
        let span = max(bandHigh - bandLow, 0.001)
        let t = min(max((normalizedY - bandLow) / span, 0), 1)
        let frontScale: CGFloat = 1.24
        let backScale: CGFloat = 0.76
        return frontScale + (backScale - frontScale) * t
    }

    static func displayScale(for element: GardenElement) -> CGFloat {
        var depthScale = bloomDepthScale(normalizedY: CGFloat(element.position.y))
        if element.isLegend {
            depthScale *= 1.35
        } else if element.kind == .flower && element.shape == .daisy12 {
            depthScale *= 1.22
        }
        return depthScale
    }

    static func stemHeight(for element: GardenElement) -> CGFloat {
        element.isLegend ? 52 : 46
    }

    /// Normalized tap center on the flower head (not the stem base).
    static func normalizedBloomHeadCenter(
        for element: GardenElement,
        sceneHeight: CGFloat
    ) -> GardenPoint {
        guard element.kind != .tree else { return element.position }
        let scale = displayScale(for: element)
        let headOffsetYNormalized = Double((stemHeight(for: element) + 4) * scale / sceneHeight)
        return GardenPoint(
            x: element.position.x,
            y: element.position.y + headOffsetYNormalized
        )
    }

    /// Normalized hit radius around the flower head.
    static func normalizedBloomHeadHitRadius(
        for element: GardenElement,
        sceneHeight: CGFloat
    ) -> Double {
        guard element.kind != .tree else { return 0.06 }
        let scale = displayScale(for: element)
        let baseRadius: CGFloat
        if element.isLegend {
            baseRadius = 34
        } else if element.shape == .daisy12 {
            baseRadius = 30
        } else {
            baseRadius = 26
        }
        return Double(baseRadius * scale / sceneHeight)
    }

    func bloomHeadCenter(for element: GardenElement) -> CGPoint {
        let base = screenPosition(for: element.position)
        guard element.kind != .tree else { return base }
        let scale = Self.displayScale(for: element)
        let offsetY = (Self.stemHeight(for: element) + 4) * scale
        return CGPoint(x: base.x, y: base.y + offsetY)
    }

    func bloomHeadHitRadius(for element: GardenElement) -> CGFloat {
        guard element.kind != .tree else { return 40 }
        let scale = Self.displayScale(for: element)
        let baseRadius: CGFloat
        if element.isLegend {
            baseRadius = 34
        } else if element.shape == .daisy12 {
            baseRadius = 30
        } else {
            baseRadius = 26
        }
        return baseRadius * scale
    }

    /// Returns the nearest bloom whose flower head contains `location`.
    func bloomID(at location: CGPoint) -> UUID? {
        var best: (UUID, CGFloat)?
        for element in elements where element.kind != .tree {
            let center = bloomHeadCenter(for: element)
            let radius = bloomHeadHitRadius(for: element)
            let distance = hypot(location.x - center.x, location.y - center.y)
            guard distance <= radius else { continue }
            if best == nil || distance < best!.1 {
                best = (element.sourceID, distance)
            }
        }
        return best?.0
    }

    private func bloomDepthScale(normalizedY: CGFloat) -> CGFloat {
        Self.bloomDepthScale(normalizedY: normalizedY)
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
        let alpha: CGFloat = season == .blooming ? 0.55 : 0.38
        let color = SKColor(white: 1, alpha: alpha)
        for i in 0..<4 {
            let cloud = makeCloud(variant: i, color: color)
            cloud.position = CGPoint(
                x: size.width * (0.15 + CGFloat(i) * 0.24),
                y: size.height * (0.70 + CGFloat(i % 2) * 0.06)
            )
            cloud.zPosition = -2
            addChild(cloud)
        }
    }

    private func addDriftingClouds() {
        let alpha: CGFloat = season == .blooming ? 0.62 : 0.42
        let cloudColor = SKColor(white: 1, alpha: alpha)
        let cloudCount = 7
        let maxCloudWidth: CGFloat = 130

        let ySlots: [CGFloat] = [0.62, 0.68, 0.74, 0.78, 0.65, 0.71, 0.76]
        let speeds: [CGFloat] = [14, 19, 24, 17, 28, 21, 16]

        for i in 0..<cloudCount {
            // Outer node travels horizontally; inner node bobs vertically.
            let traveler = SKNode()
            let yPos = size.height * ySlots[i]
            let startX = -maxCloudWidth + (size.width + maxCloudWidth) * CGFloat(i) / CGFloat(cloudCount - 1)
            traveler.position = CGPoint(x: startX, y: yPos)
            traveler.zPosition = (i % 2 == 0) ? -2 : -3
            addChild(traveler)

            let cloud = makeCloud(variant: i, color: cloudColor)
            traveler.addChild(cloud)

            // Horizontal loop: travel right until off-screen, jump back to left edge.
            let speed = speeds[i]
            let rightEdge = size.width + maxCloudWidth
            let initialDist = rightEdge - startX
            let fullDist = size.width + maxCloudWidth * 2

            let moveInitial = SKAction.moveBy(x: initialDist, y: 0,
                                              duration: TimeInterval(initialDist / speed))
            let jumpLeft = SKAction.run { [weak traveler] in
                traveler?.position.x = -maxCloudWidth
            }
            let moveFull = SKAction.moveBy(x: fullDist, y: 0,
                                           duration: TimeInterval(fullDist / speed))
            traveler.run(.sequence([moveInitial, .repeatForever(.sequence([jumpLeft, moveFull]))]))

            // Vertical hover bob on the inner cloud node.
            let bobAmps: [CGFloat] = [4, 6, 3, 7, 5, 4, 6]
            let bobDurations: [Double] = [8, 11, 7, 10, 9, 12, 8]
            let bob = SKAction.repeatForever(.sequence([
                .moveBy(x: 0, y: bobAmps[i], duration: bobDurations[i]),
                .moveBy(x: 0, y: -bobAmps[i], duration: bobDurations[i]),
            ]))
            bob.timingMode = .easeInEaseOut
            cloud.run(.sequence([.wait(forDuration: Double(i) * 1.3), bob]))
        }
    }

    /// Gentle ping-pong drift for compact widgets — clouds stay inside the clipped card.
    private func addBoundedDriftingClouds() {
        let alpha: CGFloat = season == .blooming ? 0.58 : 0.40
        let cloudColor = SKColor(white: 1, alpha: alpha)
        let cloudCount = 7
        let marginX = size.width * 0.06

        let scales: [CGFloat] = [0.40, 0.55, 0.68, 0.48, 0.62, 0.82, 0.52]
        let xSlots: [CGFloat] = [0.10, 0.26, 0.44, 0.60, 0.76, 0.34, 0.52]
        let yHeights: [CGFloat] = [0.58, 0.72, 0.64, 0.80, 0.68, 0.55, 0.75]
        let driftXFactors: [CGFloat] = [0.07, 0.09, 0.06, 0.11, 0.08, 0.10, 0.075]
        let driftYAmps: [CGFloat] = [5, 7, 4, 8, 6, 5, 7]
        let driftXDurations: [Double] = [7, 9, 6, 8, 10, 7, 9]
        let driftYDurations: [Double] = [4, 5, 3.5, 6, 4.5, 5, 4]

        for i in 0..<cloudCount {
            let cloud = makeCloud(variant: i, color: cloudColor)
            let x = marginX + (size.width - marginX * 2) * xSlots[i]
            let y = size.height * yHeights[i]
            cloud.position = CGPoint(x: x, y: y)
            cloud.zPosition = (i % 3 == 0) ? -3 : -2
            cloud.setScale(scales[i])
            addChild(cloud)

            let driftX = size.width * driftXFactors[i]
            let driftY = driftYAmps[i]
            let durX = driftXDurations[i]
            let durY = driftYDurations[i]

            let horizontal = SKAction.repeatForever(.sequence([
                .moveBy(x: driftX, y: 0, duration: durX),
                .moveBy(x: -driftX, y: 0, duration: durX),
            ]))
            horizontal.timingMode = .easeInEaseOut

            let vertical = SKAction.repeatForever(.sequence([
                .moveBy(x: 0, y: driftY, duration: durY),
                .moveBy(x: 0, y: -driftY, duration: durY),
            ]))
            vertical.timingMode = .easeInEaseOut

            cloud.run(.sequence([.wait(forDuration: Double(i) * 0.55), horizontal]))
            cloud.run(.sequence([.wait(forDuration: Double(i) * 0.7), vertical]))
        }
    }

    // Builds a composite cloud from overlapping ellipses. Four distinct shapes.
    private func makeCloud(variant: Int, color: SKColor) -> SKNode {
        let container = SKNode()
        let bumps: [(CGSize, CGPoint)]
        switch variant % 4 {
        case 0: // Puffy round
            bumps = [
                (CGSize(width: 72, height: 28), .zero),
                (CGSize(width: 44, height: 36), CGPoint(x: -22, y: 10)),
                (CGSize(width: 50, height: 40), CGPoint(x:  2, y: 14)),
                (CGSize(width: 36, height: 28), CGPoint(x: 26, y:  8)),
            ]
        case 1: // Long wispy
            bumps = [
                (CGSize(width: 108, height: 22), .zero),
                (CGSize(width: 42,  height: 30), CGPoint(x: -30, y:  8)),
                (CGSize(width: 46,  height: 32), CGPoint(x:  24, y: 10)),
            ]
        case 2: // Tall builder
            bumps = [
                (CGSize(width: 62, height: 24), .zero),
                (CGSize(width: 38, height: 34), CGPoint(x: -14, y: 12)),
                (CGSize(width: 46, height: 42), CGPoint(x:   4, y: 18)),
                (CGSize(width: 32, height: 26), CGPoint(x:  24, y:  8)),
            ]
        default: // Small wispy
            bumps = [
                (CGSize(width: 56, height: 18), .zero),
                (CGSize(width: 36, height: 26), CGPoint(x: -10, y: 8)),
                (CGSize(width: 30, height: 22), CGPoint(x:  16, y: 6)),
            ]
        }
        for (bumpSize, offset) in bumps {
            let ellipse = SKShapeNode(ellipseOf: bumpSize)
            ellipse.fillColor = color
            ellipse.strokeColor = .clear
            ellipse.position = offset
            container.addChild(ellipse)
        }
        return container
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
        case .flower, .placeFlower, .birthdayFlower, .anniversaryFlower:
            return Self.makeFlower(
                chapter: element.chapter,
                shape: element.shape,
                season: season,
                cycle: element.cycle,
                isLegend: element.isLegend
            )
        case .tree:
            return Self.makeTree()
        }
    }

    internal static func makeFlower(
        chapter: BloomChapter,
        shape: BloomShape,
        season: GardenSeason,
        cycle: Int,
        isLegend: Bool
    ) -> SKNode {
        let container = SKNode()
        let stemHeight: CGFloat = isLegend ? 52 : 46
        let stem = SKShapeNode(rect: CGRect(x: -2, y: 0, width: 4, height: stemHeight))
        stem.fillColor = SKColor(red: 0.36, green: 0.55, blue: 0.32, alpha: 1)
        stem.strokeColor = .clear
        container.addChild(stem)

        let petalColor = Self.petalColor(chapter: chapter, season: season, cycle: cycle)
        let head = SKNode()
        head.position = CGPoint(x: 0, y: stemHeight + 4)
        Self.addPetals(to: head, shape: shape, color: petalColor, isLegend: isLegend)
        Self.addFlowerCenter(to: head, chapter: chapter, shape: shape)
        container.addChild(head)
        return container
    }

    private static func addPetals(to head: SKNode, shape: BloomShape, color: SKColor, isLegend: Bool) {
        switch shape {
        case .classic6:
            addRadialPetals(to: head, count: 6, size: CGSize(width: 12, height: 22), color: color, offsetY: 12)
        case .place5:
            addRadialPetals(to: head, count: 5, size: CGSize(width: 11, height: 20), color: color, offsetY: 11)
        case .daisy12:
            addRadialPetals(to: head, count: 12, size: CGSize(width: 7, height: 14), color: color, offsetY: 10)
        case .tulip3:
            for i in 0..<3 {
                let petal = SKShapeNode(ellipseOf: CGSize(width: 18, height: 28))
                petal.fillColor = color
                petal.strokeColor = .clear
                let holder = SKNode()
                holder.zRotation = CGFloat(i) * (2 * .pi / 3) - .pi / 2
                petal.position = CGPoint(x: 0, y: 14)
                holder.addChild(petal)
                head.addChild(holder)
            }
        case .lotus8:
            for ring in 0..<2 {
                let count = 4
                let radius: CGFloat = ring == 0 ? 10 : 16
                let petalSize = CGSize(width: ring == 0 ? 10 : 12, height: ring == 0 ? 16 : 18)
                for i in 0..<count {
                    let petal = SKShapeNode(ellipseOf: petalSize)
                    petal.fillColor = color
                    petal.strokeColor = color.withAlphaComponent(0.35)
                    petal.lineWidth = 0.5
                    let holder = SKNode()
                    let angle = CGFloat(i) * (.pi / 2) + (ring == 1 ? .pi / 4 : 0)
                    holder.zRotation = angle
                    petal.position = CGPoint(x: 0, y: radius)
                    holder.addChild(petal)
                    head.addChild(holder)
                }
            }
        }
        if isLegend {
            let glow = SKShapeNode(circleOfRadius: 22)
            glow.fillColor = color.withAlphaComponent(0.12)
            glow.strokeColor = .clear
            glow.zPosition = -1
            head.addChild(glow)
        }
    }

    private static func addRadialPetals(
        to head: SKNode,
        count: Int,
        size: CGSize,
        color: SKColor,
        offsetY: CGFloat
    ) {
        guard count > 0 else { return }
        for i in 0..<count {
            let petal = SKShapeNode(ellipseOf: size)
            petal.fillColor = color
            petal.strokeColor = .clear
            let holder = SKNode()
            holder.zRotation = CGFloat(i) * (2 * .pi / CGFloat(count))
            petal.position = CGPoint(x: 0, y: offsetY)
            holder.addChild(petal)
            head.addChild(holder)
        }
    }

    private static func addFlowerCenter(to head: SKNode, chapter: BloomChapter, shape: BloomShape) {
        switch shape {
        case .place5:
            let pin = SKShapeNode(circleOfRadius: 5)
            pin.fillColor = SKColor(red: 0.35, green: 0.42, blue: 0.62, alpha: 1)
            pin.strokeColor = .white
            pin.lineWidth = 1
            head.addChild(pin)
        default:
            let radius: CGFloat = (chapter == .black) ? 6 : 7
            let center = SKShapeNode(circleOfRadius: radius)
            if chapter == .black {
                center.fillColor = SKColor(red: 0.78, green: 0.80, blue: 0.85, alpha: 1)
            } else {
                center.fillColor = SKColor(red: 0.98, green: 0.85, blue: 0.45, alpha: 1)
            }
            center.strokeColor = .clear
            head.addChild(center)
        }
    }

    static func petalColor(chapter: BloomChapter, season: GardenSeason, cycle: Int) -> SKColor {
        let base: SKColor
        switch chapter {
        case .white:
            base = SKColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 1)
        case .yellow:
            base = SKColor(red: 1.0, green: 0.90, blue: 0.42, alpha: 1)
        case .red:
            base = SKColor(red: 0.95, green: 0.42, blue: 0.48, alpha: 1)
        case .blue:
            base = SKColor(red: 0.45, green: 0.62, blue: 0.95, alpha: 1)
        case .purple:
            base = SKColor(red: 0.72, green: 0.52, blue: 0.88, alpha: 1)
        case .black:
            base = SKColor(red: 0.10, green: 0.08, blue: 0.13, alpha: 1)
        case .birthday:
            base = SKColor(red: 0.98, green: 0.55, blue: 0.68, alpha: 1)
        case .anniversary:
            base = SKColor(red: 1.0, green: 0.78, blue: 0.36, alpha: 1)
        }
        var color = enrich(base, cycle: cycle)
        if season == .resting {
            color = soften(color, factor: 0.15)
        }
        return color
    }

    private static func enrich(_ color: SKColor, cycle: Int) -> SKColor {
        guard cycle > 0 else { return color }
        let white = SKColor.white
        return blend(color, white, factor: min(0.12 * CGFloat(cycle), 0.22))
    }

    private static func soften(_ color: SKColor, factor: CGFloat) -> SKColor {
        let calm = SKColor(red: 0.78, green: 0.76, blue: 0.82, alpha: 1)
        return blend(color, calm, factor: factor)
    }

    private static func blend(_ a: SKColor, _ b: SKColor, factor: CGFloat) -> SKColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let t = min(max(factor, 0), 1)
        return SKColor(
            red: ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue: ab + (bb - ab) * t,
            alpha: aa + (ba - aa) * t
        )
    }

    private func addLegendShimmer(to node: SKNode) {
        let pulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.92, duration: 1.4),
            .fadeAlpha(to: 1.0, duration: 1.4),
        ]))
        pulse.timingMode = .easeInEaseOut
        node.run(pulse)
    }

    internal static func makeTree() -> SKNode {
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
        petalColor(chapter: .yellow, season: season, cycle: 0)
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
        guard allowsBloomInteraction else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let id = bloomID(at: location) {
            bumpBloom(id: id)
            onTapElement?(id)
            return
        }

        // Letter trees still use node-name hit testing on the canopy.
        var node: SKNode? = atPoint(location)
        while let current = node {
            if let name = current.name, let id = UUID(uuidString: name) {
                bumpBloom(id: id)
                onTapElement?(id)
                return
            }
            node = current.parent
        }
    }

    private func bumpBloom(id: UUID) {
        guard let node = elementNodes[id] else { return }
        let rest = node.xScale
        let bump = SKAction.sequence([
            .scale(to: rest * 1.18, duration: 0.08),
            .scale(to: rest, duration: 0.12),
        ])
        node.run(bump)
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
