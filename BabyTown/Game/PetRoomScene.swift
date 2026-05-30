import SpriteKit
import UIKit
import SwiftUI

/// The living-room scene where the adopted cat lives. Renders the room + props,
/// and drives an "ambient" cat that wanders, sits, sleeps and grooms on its own,
/// and reacts when tapped.
///
/// Art strategy: every visual prefers real art (a texture atlas named after the
/// skin, or a named image). Idle/stand frames use the `stand_*` atlas prefix.
final class PetRoomScene: SKScene {

    // MARK: Behavior states

    private enum CatAction: String, CaseIterable {
        case idle, walk, sit, sleep, groom, petReaction, eat, pounce
    }

    /// Tappable things in the room. Reported to SwiftUI via `onTapProp` so the
    /// view can show the right inspect card / run the matching care action.
    enum RoomProp {
        case cat, foodBowl, waterBowl, litterBox
    }

    /// Kind of reaction the view can ask the cat to perform after a care action.
    enum ReactionKind {
        case happy, eat
    }

    // MARK: Config

    private let skin: CatSkin
    private let atlas: SKTextureAtlas

    /// Vertical band (fraction of height) the cat may wander within — a shallow
    /// strip near the bottom that reads as the room floor.
    private let floorBand: ClosedRange<CGFloat> = 0.12...0.38
    /// Points/second the cat walks.
    private let walkSpeed: CGFloat = 70
    /// On-screen cat height; width follows each frame's aspect ratio.
    private let catDisplayHeight: CGFloat = 150

    // MARK: Nodes

    private struct CatFrame {
        let name: String
        let texture: SKTexture
    }

    private let cat = SKNode()             // movable container
    private let catFacing = SKNode()       // left/right mirror only
    private let catVisual = SKSpriteNode() // the drawn/animated body
    private var frameDisplaySizes: [String: CGSize] = [:]
    private var currentFrameName: String?

    /// Interactive prop nodes, for tap hit-testing and walk-to targets.
    private var propNodes: [RoomProp: SKNode] = [:]

    private var isInteracting = false
    private var currentAction: CatAction = .idle
    /// True while the cat is in a sit / sleep / groom pose and should not wander.
    private var isHoldingPose = false

    // MARK: Laser play

    /// Called when the user taps a prop (or the cat). Set by `PetRoomView`.
    var onTapProp: ((RoomProp) -> Void)?

    var layoutState = PetRoomLayoutState()
    var pictureFrameImage: UIImage?
    var isCustomizeMode = false
    var onLayoutPositionsChanged: (([String: NormalizedPoint]) -> Void)?
    /// Active laser-drag seconds accumulated this session (0…`PetEconomy.playDurationRequired`).
    var onPlayProgress: ((TimeInterval) -> Void)?
    /// Fired once when the player has moved the laser for the full required duration.
    var onPlayDurationMet: (() -> Void)?

    private var wallWashNode: SKSpriteNode?
    private var pictureFrameNode: SKNode?
    private var draggableNodes: [String: SKNode] = [:]
    private var draggingKey: String?
    private var dragTouchOffset = CGPoint.zero

    private var isPlaying = false
    private var laserDot: SKShapeNode?
    private var lastUpdateTime: TimeInterval = 0
    /// Sprites face right by default; true when mirrored to face left.
    private var facesLeft = false
    private var isLaserEngaged = false
    private var playEngagementSeconds: TimeInterval = 0
    private var playDurationMetFired = false

    // MARK: Init

    init(skin: CatSkin, size: CGSize) {
        self.skin = skin
        self.atlas = SKTextureAtlas(named: skin.atlasName)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        preloadFrameDisplaySizes()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        removeAllChildren()
        buildRoom()
        buildCat()
        runBehavior()
    }

    // MARK: Room

    func applyRoomLayout(_ layout: PetRoomLayoutState, frameImage: UIImage?) {
        layoutState = layout
        pictureFrameImage = frameImage
        rebuildRoomDecor()
    }

    private func buildRoom() {
        if let bg = loadImage("room_background") {
            bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
            bg.size = size
            bg.zPosition = -10
            addChild(bg)
        } else {
            let bg = SKSpriteNode(texture: gradientTexture(size: size,
                                                           top: SKColor(red: 1.0, green: 0.93, blue: 0.95, alpha: 1),
                                                           bottom: SKColor(red: 0.99, green: 0.86, blue: 0.83, alpha: 1)),
                                  size: size)
            bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
            bg.zPosition = -10
            addChild(bg)

            let floor = SKSpriteNode(color: SKColor(red: 0.97, green: 0.80, blue: 0.74, alpha: 1),
                                     size: CGSize(width: size.width, height: size.height * floorBand.upperBound))
            floor.anchorPoint = CGPoint(x: 0.5, y: 0)
            floor.position = CGPoint(x: size.width / 2, y: 0)
            floor.zPosition = -9
            addChild(floor)
        }

        rebuildRoomDecor()
    }

    private func rebuildRoomDecor() {
        wallWashNode?.removeFromParent()
        pictureFrameNode?.removeFromParent()
        draggableNodes.values.forEach { $0.removeFromParent() }
        draggableNodes.removeAll()
        propNodes.removeAll()

        applyWallWash()
        buildPictureFrame()

        placeBuiltInProps()
        placeOwnedFurniture()
    }

    private func applyWallWash() {
        var r: CGFloat = 1, g: CGFloat = 0.93, b: CGFloat = 0.95, a: CGFloat = 1
        PetShopCatalog.wallUIColor(for: layoutState.wallColorID).getRed(&r, green: &g, blue: &b, alpha: &a)
        let wash = SKSpriteNode(color: SKColor(red: r, green: g, blue: b, alpha: a), size: size)
        wash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        wash.alpha = layoutState.wallColorID == nil ? 0.22 : 0.38
        wash.zPosition = -8
        addChild(wash)
        wallWashNode = wash
    }

    private func buildPictureFrame() {
        guard layoutState.owns(PetShopCatalog.pictureFrameID),
              layoutState.pictureFrameMomentID != nil else { return }

        let container = SKNode()
        let center = CGPoint(x: size.width * 0.72, y: size.height * 0.62)
        container.position = center
        container.zPosition = -2

        let frame = SKShapeNode(rectOf: CGSize(width: 92, height: 108), cornerRadius: 6)
        frame.fillColor = SKColor(red: 0.45, green: 0.28, blue: 0.18, alpha: 1)
        frame.strokeColor = SKColor(red: 0.88, green: 0.22, blue: 0.38, alpha: 0.9)
        frame.lineWidth = 3
        container.addChild(frame)

        if let pictureFrameImage {
            let tex = SKTexture(image: pictureFrameImage)
            let photo = SKSpriteNode(texture: tex)
            photo.size = CGSize(width: 76, height: 76)
            photo.position = CGPoint(x: 0, y: 6)
            container.addChild(photo)
        } else {
            let label = SKLabelNode(text: "♥")
            label.fontSize = 28
            label.verticalAlignmentMode = .center
            container.addChild(label)
        }

        addChild(container)
        pictureFrameNode = container
    }

    private func placeBuiltInProps() {
        installProp(
            key: PetRoomPropKey.catTree,
            imageName: "prop_cat_tree",
            caption: "Cat Tree",
            roomProp: nil,
            defaultPoint: NormalizedPoint(x: 0.84, y: 0.30),
            placeholderSize: CGSize(width: 120, height: 220),
            draggableInCustomize: false,
            pixelOffset: CGPoint(x: 0, y: 150)
        )
        installProp(
            key: PetRoomPropKey.foodBowl,
            imageName: "prop_food_bowl",
            caption: "Food",
            roomProp: .foodBowl,
            defaultPoint: NormalizedPoint(x: 0.18, y: 0.22),
            placeholderSize: CGSize(width: 52, height: 40),
            draggableInCustomize: true
        )
        installProp(
            key: PetRoomPropKey.waterBowl,
            imageName: "prop_water_bowl",
            caption: "Water",
            roomProp: .waterBowl,
            defaultPoint: NormalizedPoint(x: 0.34, y: 0.21),
            placeholderSize: CGSize(width: 52, height: 40),
            draggableInCustomize: true
        )
        installProp(
            key: PetRoomPropKey.litterBox,
            imageName: "prop_litter_box",
            caption: "Litter",
            roomProp: .litterBox,
            defaultPoint: NormalizedPoint(x: 0.90, y: 0.12),
            placeholderSize: CGSize(width: 200, height: 120),
            draggableInCustomize: true
        )
    }

    private func placeOwnedFurniture() {
        for item in PetShopCatalog.all where item.isFloorItem {
            guard layoutState.owns(item.id) else { continue }
            let key = item.id
            let defaultPoint: NormalizedPoint
            switch key {
            case PetRoomPropKey.couch: defaultPoint = NormalizedPoint(x: 0.56, y: 0.19)
            case PetRoomPropKey.catBed: defaultPoint = NormalizedPoint(x: 0.44, y: 0.20)
            case PetRoomPropKey.yarnBall: defaultPoint = NormalizedPoint(x: 0.70, y: 0.23)
            default: defaultPoint = NormalizedPoint(x: 0.5, y: 0.2)
            }
            installProp(
                key: key,
                imageName: item.imageName ?? "",
                caption: item.placeholderCaption,
                roomProp: nil,
                defaultPoint: defaultPoint,
                placeholderSize: item.defaultSize,
                draggableInCustomize: true
            )
        }
    }

    private func installProp(
        key: String,
        imageName: String,
        caption: String,
        roomProp: RoomProp?,
        defaultPoint: NormalizedPoint,
        placeholderSize: CGSize,
        draggableInCustomize: Bool,
        pixelOffset: CGPoint = .zero
    ) {
        let normalized = layoutState.propPositions[key] ?? defaultPoint
        var point = scenePoint(from: normalized)
        point.x += pixelOffset.x
        point.y += pixelOffset.y
        let node = makePropNode(imageName: imageName, caption: caption, placeholderSize: placeholderSize, point: point, roomProp: roomProp)
        addChild(node)
        if let roomProp { propNodes[roomProp] = node }
        if draggableInCustomize {
            draggableNodes[key] = node
        }
        if layoutState.propPositions[key] == nil {
            var positions = layoutState.propPositions
            positions[key] = normalized
            layoutState.propPositions = positions
        }
    }

    private func makePropNode(
        imageName: String,
        caption: String,
        placeholderSize: CGSize,
        point: CGPoint,
        roomProp: RoomProp?
    ) -> SKNode {
        if !imageName.isEmpty, let sprite = loadImage(imageName) {
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.position = point
            if sprite.size.height > 0 {
                sprite.size = sprite.size.scaledToHeight(placeholderSize.height)
            }
            sprite.zPosition = roomProp == nil ? 0 : 5
            if isCustomizeMode { highlightDraggable(sprite) }
            return sprite
        }

        let rect = SKShapeNode(rectOf: placeholderSize, cornerRadius: 12)
        rect.fillColor = SKColor(red: 0.90, green: 0.62, blue: 0.66, alpha: 0.55)
        rect.strokeColor = SKColor(red: 0.88, green: 0.22, blue: 0.38, alpha: 0.6)
        rect.lineWidth = 2
        rect.position = CGPoint(x: point.x, y: point.y + placeholderSize.height / 2)
        rect.zPosition = roomProp == nil ? 0 : 5
        let label = SKLabelNode(text: caption)
        label.fontName = "HelveticaNeue-Medium"
        label.fontSize = 14
        label.fontColor = SKColor(red: 0.55, green: 0.15, blue: 0.27, alpha: 1)
        label.verticalAlignmentMode = .center
        rect.addChild(label)
        if isCustomizeMode { highlightDraggable(rect) }
        return rect
    }

    private func highlightDraggable(_ node: SKNode) {
        node.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.72, duration: 0.55),
            .fadeAlpha(to: 1.0, duration: 0.55)
        ])))
    }

    private func scenePoint(from normalized: NormalizedPoint) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    private func normalizedPoint(from scenePoint: CGPoint) -> NormalizedPoint {
        NormalizedPoint(
            x: min(max(scenePoint.x / max(size.width, 1), 0.06), 0.94),
            y: min(max(scenePoint.y / max(size.height, 1), floorBand.lowerBound), floorBand.upperBound)
        )
    }

    private func clampToFloorBand(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, size.width * 0.06), size.width * 0.94),
            y: min(max(point.y, size.height * floorBand.lowerBound), size.height * floorBand.upperBound)
        )
    }

    // MARK: Cat

    private func buildCat() {
        cat.position = CGPoint(x: size.width * 0.5, y: randomFloorY())
        cat.zPosition = 1
        addChild(cat)

        cat.addChild(catFacing)
        catVisual.anchorPoint = CGPoint(x: 0.5, y: 0) // feet at the node origin
        catFacing.addChild(catVisual)

        if let frame = frames(for: .idle).first {
            applyCatFrame(frame)
            currentAction = .idle
        }
    }

    private func preloadFrameDisplaySizes() {
        for name in atlas.textureNames {
            let texture = atlas.textureNamed(name)
            frameDisplaySizes[name] = Self.displaySize(for: texture, targetHeight: catDisplayHeight)
        }
    }

    /// Sets the cat sprite frame and resizes from that frame's pixel aspect ratio.
    private func applyCatFrame(_ frame: CatFrame) {
        catVisual.texture = frame.texture
        currentFrameName = frame.name
        catVisual.size = frameDisplaySizes[frame.name]
            ?? Self.displaySize(for: frame.texture, targetHeight: catDisplayHeight)
    }

    private static func displaySize(for texture: SKTexture, targetHeight: CGFloat) -> CGSize {
        let cg = texture.cgImage()
        guard cg.height > 0 else {
            return texture.size().scaledToHeight(targetHeight)
        }
        let aspect = CGFloat(cg.width) / CGFloat(cg.height)
        return CGSize(width: targetHeight * aspect, height: targetHeight)
    }

    // MARK: Ambient behavior loop

    private func runBehavior() {
        guard !isInteracting, !isHoldingPose else { return }
        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<55:  wander()
        case 55..<72: idleFor(state: .sit, duration: Double.random(in: 3...6))
        case 72..<86: idleFor(state: .groom, duration: Double.random(in: 2...4))
        default:      idleFor(state: .sleep, duration: Double.random(in: 5...9))
        }
    }

    private func wander() {
        guard !isHoldingPose else { return }
        let target = CGPoint(x: CGFloat.random(in: size.width * 0.12...size.width * 0.88),
                             y: randomFloorY())
        face(towards: target.x)
        startAnimation(.walk)
        let distance = hypot(target.x - cat.position.x, target.y - cat.position.y)
        let duration = max(0.4, TimeInterval(distance / walkSpeed))
        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        runBehaviorAction(move) { [weak self] in
            guard let self else { return }
            self.startAnimation(.idle)
            self.runBehaviorAction(.wait(forDuration: Double.random(in: 0.4...1.5))) {
                self.runBehavior()
            }
        }
    }

    private func idleFor(state: CatAction, duration: TimeInterval) {
        stopMovement()
        startAnimation(state)
        isHoldingPose = true
        runBehaviorAction(.wait(forDuration: duration)) { [weak self] in
            guard let self else { return }
            self.isHoldingPose = false
            self.startAnimation(.idle)
            self.runBehavior()
        }
    }

    /// Cancels locomotion so sit / sleep / groom poses stay in place.
    private func stopMovement() {
        isHoldingPose = false
        cat.removeAction(forKey: "behavior")
    }

    /// Runs an action on the cat under the cancelable "behavior" key, invoking
    /// `completion` when it finishes naturally. Cancelling via
    /// `removeAction(forKey: "behavior")` skips the completion — which is how an
    /// interaction (tap) takes over the loop and restarts it manually.
    private func runBehaviorAction(_ action: SKAction, completion: @escaping () -> Void) {
        cat.run(.sequence([action, .run(completion)]), withKey: "behavior")
    }

    /// Plays the animation for a state from real atlas frames.
    private func startAnimation(_ state: CatAction) {
        currentAction = state
        catVisual.removeAction(forKey: "anim")
        catVisual.removeAction(forKey: "pounce")

        let actionFrames = frames(for: state)
        if actionFrames.count > 1 {
            applyCatFrame(actionFrames[0])
            let timePerFrame: TimeInterval = state == .walk ? 0.08 : 0.18
            catVisual.run(
                .repeatForever(.animate(with: actionFrames.map(\.texture), timePerFrame: timePerFrame)),
                withKey: "anim"
            )
            resetVisualTransform()
            return
        }
        if let single = actionFrames.first {
            applyCatFrame(single)
            resetVisualTransform()
            return
        }

        // No dedicated frames — reuse stand/idle art for locomotion states.
        if state == .walk || state == .pounce, let stand = frames(for: .idle).first {
            applyCatFrame(stand)
            resetVisualTransform()
            return
        }

        resetVisualTransform()
    }

    /// Clears procedural motion transforms so real sprite art displays cleanly.
    private func resetVisualTransform() {
        catVisual.xScale = 1
        catVisual.yScale = 1
        catVisual.zRotation = 0
        if let name = currentFrameName, let size = frameDisplaySizes[name] {
            catVisual.size = size
        }
        updateFacingFlip()
    }

    private func face(towards x: CGFloat) {
        // Real sprites are drawn facing right; mirror via a dedicated parent node.
        facesLeft = x < cat.position.x
        updateFacingFlip()
    }

    private func updateFacingFlip() {
        catFacing.xScale = facesLeft ? -1 : 1
    }

    // MARK: Interaction

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if isCustomizeMode {
            beginCustomizeDrag(at: location)
            return
        }

        if isPlaying {
            isLaserEngaged = true
            moveLaser(to: location)
            return
        }

        let catHit = cat.calculateAccumulatedFrame().insetBy(dx: -24, dy: -24)
        if catHit.contains(location) {
            handleTap(.cat)
            return
        }
        for (prop, node) in propNodes {
            if node.calculateAccumulatedFrame().insetBy(dx: -16, dy: -16).contains(location) {
                handleTap(prop)
                return
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if isCustomizeMode, let key = draggingKey, let node = draggableNodes[key] {
            let target = clampToFloorBand(
                CGPoint(x: location.x + dragTouchOffset.x, y: location.y + dragTouchOffset.y)
            )
            if let sprite = node as? SKSpriteNode {
                sprite.position = CGPoint(x: target.x, y: target.y)
            } else {
                let halfH = node.calculateAccumulatedFrame().height / 2
                node.position = CGPoint(x: target.x, y: target.y + halfH)
            }
            return
        }

        guard isPlaying else { return }
        isLaserEngaged = true
        moveLaser(to: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPlaying { isLaserEngaged = false }
        endCustomizeDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPlaying { isLaserEngaged = false }
        endCustomizeDrag()
    }

    private func beginCustomizeDrag(at location: CGPoint) {
        for (key, node) in draggableNodes {
            let frame = node.calculateAccumulatedFrame()
            if frame.insetBy(dx: -12, dy: -12).contains(location) {
                draggingKey = key
                dragTouchOffset = CGPoint(x: frame.midX - location.x, y: frame.midY - location.y)
                node.zPosition = 20
                return
            }
        }
    }

    private func endCustomizeDrag() {
        guard let key = draggingKey, let node = draggableNodes[key] else {
            draggingKey = nil
            return
        }
        let anchorY: CGFloat
        if node is SKSpriteNode {
            anchorY = node.position.y
        } else {
            anchorY = node.position.y - node.calculateAccumulatedFrame().height / 2
        }
        let normalized = normalizedPoint(from: CGPoint(x: node.position.x, y: anchorY))
        var positions = layoutState.propPositions
        positions[key] = normalized
        layoutState.propPositions = positions
        onLayoutPositionsChanged?(positions)
        node.zPosition = propNodes.values.contains(where: { $0 === node }) ? 5 : 0
        draggingKey = nil
    }

    func setCustomizeMode(_ enabled: Bool) {
        isCustomizeMode = enabled
        if enabled {
            stopMovement()
            catVisual.removeAllActions()
        } else {
            endCustomizeDrag()
            runBehavior()
        }
        rebuildRoomDecor()
    }

    private func handleTap(_ prop: RoomProp) {
        if let onTapProp {
            onTapProp(prop)
        } else if prop == .cat {
            // Self-contained fallback when not wired to a view (e.g. previews).
            playReaction(.happy)
        }
    }

    // MARK: Reactions driven by the view (after a care action)

    /// Asks the cat to perform a reaction the view triggers after a care action.
    func playReaction(_ kind: ReactionKind) {
        guard !isPlaying else { return }
        stopMovement()
        switch kind {
        case .happy: petCat()
        case .eat:   eatAtBowl()
        }
    }

    /// Walks the cat to the food bowl and plays the eat animation, then resumes.
    private func eatAtBowl() {
        guard let bowl = propNodes[.foodBowl] else { petCat(); return }
        isInteracting = true
        stopMovement()
        catVisual.removeAction(forKey: "anim")

        let target = CGPoint(x: bowl.position.x + 40, y: max(randomFloorY(), bowl.position.y))
        face(towards: target.x)
        startAnimation(.walk)
        let distance = hypot(target.x - cat.position.x, target.y - cat.position.y)
        let move = SKAction.move(to: target, duration: max(0.3, TimeInterval(distance / walkSpeed)))
        move.timingMode = .easeInEaseOut
        cat.run(move) { [weak self] in
            guard let self else { return }
            self.startAnimation(.eat)
            self.cat.run(.wait(forDuration: 2.2)) {
                self.isInteracting = false
                self.startAnimation(.idle)
                self.runBehavior()
            }
        }
    }

    // MARK: Laser play

    /// Enters laser-pointer play: a glowing dot appears and the cat chases it
    /// (steered each frame in `update`). The dot follows the user's touch.
    func startLaserPlay() {
        guard !isPlaying else { return }
        isPlaying = true
        isInteracting = true
        isLaserEngaged = false
        playEngagementSeconds = 0
        playDurationMetFired = false
        onPlayProgress?(0)
        stopMovement()
        catVisual.removeAction(forKey: "anim")
        resetVisualTransform()

        // Wake from sleep (or any idle pose) into standing before chasing.
        startAnimation(.idle)

        let dot = SKShapeNode(circleOfRadius: 9)
        dot.fillColor = SKColor(red: 1.0, green: 0.18, blue: 0.22, alpha: 0.95)
        dot.strokeColor = SKColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 0.5)
        dot.glowWidth = 6
        dot.lineWidth = 4
        dot.zPosition = 40
        dot.position = CGPoint(x: size.width * 0.5, y: size.height * floorBand.lowerBound)
        addChild(dot)
        laserDot = dot
        face(towards: dot.position.x)
    }

    /// Exits laser play and returns the cat to its ambient routine.
    func endLaserPlay() {
        guard isPlaying else { return }
        isPlaying = false
        isLaserEngaged = false
        playEngagementSeconds = 0
        playDurationMetFired = false
        onPlayProgress?(0)
        laserDot?.removeFromParent()
        laserDot = nil
        isInteracting = false
        startAnimation(.idle)
        runBehavior()
    }

    private func moveLaser(to point: CGPoint) {
        // Keep the dot within the floor band so the cat can reach it.
        let y = min(max(point.y, size.height * floorBand.lowerBound), size.height * floorBand.upperBound)
        laserDot?.position = CGPoint(x: point.x, y: y)
        face(towards: point.x)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime

        if isPlaying, isLaserEngaged {
            playEngagementSeconds += dt
            onPlayProgress?(playEngagementSeconds)
            if !playDurationMetFired,
               playEngagementSeconds >= PetEconomy.playDurationRequired {
                playDurationMetFired = true
                onPlayDurationMet?()
            }
        }

        guard isPlaying, let dot = laserDot, !isHoldingPose else { return }

        let dx = dot.position.x - cat.position.x
        let dy = dot.position.y - cat.position.y
        let distance = hypot(dx, dy)
        face(towards: dot.position.x)

        if distance > 12 {
            let step = min(CGFloat(walkSpeed * 1.6) * CGFloat(dt), distance)
            cat.position = CGPoint(x: cat.position.x + dx / distance * step,
                                   y: cat.position.y + dy / distance * step)
            if catVisual.action(forKey: "anim") == nil { startAnimation(.walk) }
        } else if catVisual.action(forKey: "pounce") == nil {
            // Caught up — a quick pounce, then keep chasing.
            startAnimation(.pounce)
            let pounce = SKAction.sequence([
                .scaleY(to: 0.88, duration: 0.08),
                .scaleY(to: 1.0, duration: 0.12)
            ])
            catVisual.run(pounce, withKey: "pounce")
        }
    }

    private func petCat() {
        guard !isInteracting else { return }
        isInteracting = true
        stopMovement()
        catVisual.removeAction(forKey: "anim")

        let happyBounce = SKAction.sequence([
            .scale(to: 1.15, duration: 0.12),
            .scale(to: 0.97, duration: 0.12),
            .scale(to: 1.0, duration: 0.1)
        ])
        spawnHearts()
        catVisual.run(happyBounce) { [weak self] in
            guard let self else { return }
            self.isInteracting = false
            self.startAnimation(.idle)
            self.runBehavior()
        }
    }

    private func spawnHearts() {
        for i in 0..<4 {
            let heart = SKLabelNode(text: "♥")
            heart.fontSize = CGFloat.random(in: 18...28)
            heart.fontColor = SKColor(red: 0.92, green: 0.30, blue: 0.45, alpha: 1)
            heart.position = CGPoint(x: cat.position.x + CGFloat.random(in: -20...20),
                                     y: cat.position.y + 120)
            heart.zPosition = 50
            heart.alpha = 0
            addChild(heart)

            let float = SKAction.group([
                .moveBy(x: CGFloat.random(in: -30...30), y: 90, duration: 1.1),
                .sequence([.fadeIn(withDuration: 0.2), .wait(forDuration: 0.5), .fadeOut(withDuration: 0.4)])
            ])
            heart.run(.sequence([
                .wait(forDuration: Double(i) * 0.08),
                float,
                .removeFromParent()
            ]))
        }
    }

    // MARK: Asset helpers

    private static let maxTextureDimension: CGFloat = 2048

    /// Loads a sprite from a catalog image name, or nil if missing.
    private func loadImage(_ name: String) -> SKSpriteNode? {
        guard let image = UIImage(named: name) else { return nil }
        let texture = SKTexture(image: Self.imageFittingTextureLimits(image))
        return SKSpriteNode(texture: texture)
    }

    /// Downscales oversized art so SpriteKit never exceeds the GPU texture limit.
    private static func imageFittingTextureLimits(_ image: UIImage) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxTextureDimension else { return image }
        let scale = maxTextureDimension / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Returns the ordered animation frames for an action from the skin's atlas,
    /// or an empty array if none are present.
    private func frames(for action: CatAction) -> [CatFrame] {
        let prefixes = framePrefixes(for: action)
        let names = atlas.textureNames
            .filter { name in prefixes.contains(where: { name.hasPrefix($0) }) }
            .sorted { frameIndex($0) < frameIndex($1) }
        return names.map { CatFrame(name: $0, texture: atlas.textureNamed($0)) }
    }

    /// Atlas file prefixes for each action. Real art uses `stand_*` for idle.
    private func framePrefixes(for action: CatAction) -> [String] {
        switch action {
        case .idle: return ["idle_", "stand_"]
        default: return ["\(action.rawValue)_"]
        }
    }

    private func frameIndex(_ name: String) -> Int {
        let base = (name as NSString).deletingPathExtension
        if let n = base.split(separator: "_").last.flatMap({ Int($0) }) { return n }
        return 0
    }

    private func randomFloorY() -> CGFloat {
        CGFloat.random(in: size.height * floorBand.lowerBound...size.height * floorBand.upperBound)
    }

    private func gradientTexture(size: CGSize, top: SKColor, bottom: SKColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            ctx.cgContext.drawLinearGradient(gradient,
                                             start: CGPoint(x: 0, y: 0),
                                             end: CGPoint(x: 0, y: size.height),
                                             options: [])
        }
        return SKTexture(image: image)
    }

}

private extension CGSize {
    /// Scales the size proportionally to a target height.
    func scaledToHeight(_ targetHeight: CGFloat) -> CGSize {
        guard height > 0 else { return self }
        let scale = targetHeight / height
        return CGSize(width: width * scale, height: targetHeight)
    }
}
