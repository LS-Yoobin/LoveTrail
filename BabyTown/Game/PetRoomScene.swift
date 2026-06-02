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
        case idle, walk, sit, sleep, groom, petReaction, eat, drink, pounce
        // `eat` shows the cat eating from its food bowl; `snack` is the bowl-less
        // eat pose used when the cat nibbles a treat dropped on the floor.
        case snack
        // Trick poses (atlas prefixes: paw_, highFive_, spin_, up_, sayHi_, down_)
        case paw, highFive, spin, up, sayHi, down
        // Trick training — cat doesn't know the command yet (confused_0)
        case confused
    }

    /// Tappable things in the room. Reported to SwiftUI via `onTapProp` so the
    /// view can show the right inspect card / run the matching care action.
    enum RoomProp {
        case cat, foodBowl, waterBowl, litterBox
    }

    /// Kind of reaction the view can ask the cat to perform after a care action.
    enum ReactionKind {
        case happy, eat, drink
    }

    // MARK: Config

    private let skin: CatSkin
    private let atlas: SKTextureAtlas

    /// Vertical band (fraction of height) the cat may wander within — a shallow
    /// strip near the bottom that reads as the room floor.
    private let floorBand: ClosedRange<CGFloat> = 0.12...0.30
    /// Points/second the cat walks.
    private let walkSpeed: CGFloat = 70
    /// On-screen cat height; width follows each frame's aspect ratio.
    private let catDisplayHeight: CGFloat = 150
    /// Extra padding so the cat sprite never touches the screen edge.
    private let catScreenEdgeInset: CGFloat = 8
    /// Default draw order for the cat on the floor (care props use 5).
    private let catDefaultZ: CGFloat = 1
    /// Draw order while eating/drinking so the cat renders in front of the bowl.
    private let catAtBowlZ: CGFloat = 8
    /// How far in front of a bowl (toward the camera / bottom of screen) the cat stops.
    private let bowlApproachFrontInset: CGFloat = 22
    /// Horizontal gap from the bowl's visual center to the cat's feet.
    private let bowlApproachLateralGap: CGFloat = 30

    // MARK: Prop depth (perspective on the floor)

    /// Perspective scale at the front (closest) edge of the floor band.
    private let depthFrontScale: CGFloat = 1.0
    /// Scale for a prop slid all the way to the front/bottom (`propFrontBound`) —
    /// a touch larger than full size to sell closeness/depth.
    private let depthNearScale: CGFloat = 1.15
    /// Perspective scale at the back (deepest) edge — farther reads as smaller.
    private let depthBackScale: CGFloat = 0.62
    /// The cat shrinks more aggressively with depth than props, so it doesn't
    /// tower over furniture at the back of the room.
    private let catDepthBackScale: CGFloat = 0.375
    /// Front (closest) edge of the prop drag region — props may slide all the way
    /// down to near the bottom of the screen, ahead of the cat's floor band.
    private let propFrontBound: CGFloat = 0.02
    /// Smallest a prop may shrink. Also caps how far back a prop's base may go,
    /// so even at its smallest the prop's top never crosses the floor/wall seam.
    private let depthMinScale: CGFloat = 0.45
    /// Props taller than this may lean on the wall (e.g. the cat tree); shorter
    /// props are kept fully on the floor.
    private let depthTallPropThreshold: CGFloat = 140
    /// Reference height for a wall-leaning prop's back limit — gives it the same
    /// deep drag range as a small floor prop instead of being held down by its
    /// own height.
    private let depthWallLeanReference: CGFloat = 36

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
    /// Fired with a prop's key when it's stashed, so the view can remove it from the room.
    var onStashProp: ((String) -> Void)?
    /// Fired with a prop's key when the user flips it, so the view can persist it.
    var onToggleFlip: ((String) -> Void)?
    /// Fired when the user selects or deselects a prop in customize mode.
    var onCustomizeSelectionChanged: ((String?) -> Void)?
    /// Scene-space point (origin bottom-left) for anchoring SwiftUI action pills above the selection.
    var onCustomizeSelectionAnchorChanged: ((CGPoint?) -> Void)?
    /// Active laser-drag seconds accumulated this session (0…`PetEconomy.playDurationRequired`).
    var onPlayProgress: ((TimeInterval) -> Void)?
    /// Fired once when the player has moved the laser for the full required duration.
    var onPlayDurationMet: (() -> Void)?
    /// Fired when the cat finishes eating a treat teaser during trick training.
    var onSnackEaten: (() -> Void)?

    private var wallWashNode: SKSpriteNode?
    private var pictureFrameNode: SKNode?
    /// Fixed draw order behind floor props during normal play.
    private let pictureFrameZ: CGFloat = -2
    /// Raised while customizing so the frame can be tapped above floor décor.
    private let pictureFrameCustomizeZ: CGFloat = 25
    private var collarNode: SKNode?
    private var draggableNodes: [String: SKNode] = [:]
    private var propInstallOffsets: [String: CGPoint] = [:]
    /// Unscaled (scale == 1) display height per prop, used to size the depth
    /// perspective and keep each prop's top below the floor/wall seam.
    private var propNaturalHeights: [String: CGFloat] = [:]
    private var draggingKey: String?
    private var dragTouchOffset = CGPoint.zero

    // MARK: Tap-to-select (customize)

    /// Prop under the finger on touch-down; promoted to a drag past a threshold,
    /// otherwise treated as a tap that selects it.
    private var dragCandidateKey: String?
    private var dragStartLocation = CGPoint.zero
    private var isActivelyDragging = false
    private let dragPromoteThreshold: CGFloat = 10
    /// Currently selected prop (shows the dotted outline in customize mode).
    private var selectedKey: String?
    private var selectionOverlay: SKNode?

    private var isPlaying = false
    private var isTrickMode = false
    /// The treat the player is dragging / has dropped during trick training.
    private var snackNode: SKNode?
    /// True from the moment a snack is dropped until the cat finishes eating it,
    /// so a second drop can't interrupt the eat sequence.
    private var isSnackBeingEaten = false
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
        playWelcomeSequence()
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
        // Keep the current selection across rebuilds (e.g. after a flip persists
        // and the layout change re-runs this), as long as the prop still exists.
        let keepSelected = selectedKey
        clearSelection()
        wallWashNode?.removeFromParent()
        pictureFrameNode?.removeFromParent()
        draggableNodes.values.forEach { $0.removeFromParent() }
        draggableNodes.removeAll()
        propNodes.removeAll()

        applyWallWash()
        buildPictureFrame()

        placeBuiltInProps()
        placeOwnedFurniture()
        applyCollar()

        if let keepSelected, draggableNodes[keepSelected] != nil {
            selectProp(keepSelected)
        }
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
              layoutState.pictureFrameMomentID != nil,
              !layoutState.isStashed(PetShopCatalog.pictureFrameID) else { return }

        let container = SKNode()
        let defaultPoint = NormalizedPoint(x: 0.72, y: 0.62)
        let normalized = clampNormalizedToWall(
            layoutState.propPositions[PetShopCatalog.pictureFrameID] ?? defaultPoint
        )
        let center = scenePoint(from: normalized)
        container.position = center
        container.zPosition = isCustomizeMode ? pictureFrameCustomizeZ : pictureFrameZ

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
        draggableNodes[PetShopCatalog.pictureFrameID] = container
        applyFlip(to: container, key: PetShopCatalog.pictureFrameID)
        if layoutState.propPositions[PetShopCatalog.pictureFrameID] == nil {
            var positions = layoutState.propPositions
            positions[PetShopCatalog.pictureFrameID] = normalized
            layoutState.propPositions = positions
        }
        if isCustomizeMode { highlightDraggable(container) }
    }

    private func placeBuiltInProps() {
        installEquippedProp(
            key: PetRoomPropKey.catTree,
            slot: .catTree,
            roomProp: nil,
            defaultPoint: NormalizedPoint(x: 0.84, y: 0.30),
            pixelOffset: CGPoint(x: 0, y: -15),
            depthHeight: 120
        )
        installEquippedProp(
            key: PetRoomPropKey.foodBowl,
            slot: .foodBowl,
            roomProp: .foodBowl,
            defaultPoint: NormalizedPoint(x: 0.18, y: 0.22),
            pixelOffset: CGPoint(x: -14, y: 0)
        )
        installEquippedProp(
            key: PetRoomPropKey.waterBowl,
            slot: .waterBowl,
            roomProp: .waterBowl,
            defaultPoint: NormalizedPoint(x: 0.34, y: 0.21),
            pixelOffset: CGPoint(x: -14, y: 0)
        )
        installEquippedProp(
            key: PetRoomPropKey.litterBox,
            slot: .litterBox,
            roomProp: .litterBox,
            defaultPoint: NormalizedPoint(x: 0.90, y: 0.12)
        )
    }

    private func installEquippedProp(
        key: String,
        slot: PetEquipSlot,
        roomProp: RoomProp?,
        defaultPoint: NormalizedPoint,
        pixelOffset: CGPoint = .zero,
        depthHeight: CGFloat? = nil
    ) {
        let equippedID = layoutState.equippedItemID(for: slot)
        let imageName = PetShopCatalog.equippedImageName(for: slot, equippedItemID: equippedID) ?? ""
        let placeholder = PetShopCatalog.equippedPlaceholder(for: slot, equippedItemID: equippedID)
        installProp(
            key: key,
            imageName: imageName,
            caption: placeholder.caption,
            roomProp: roomProp,
            defaultPoint: defaultPoint,
            placeholderSize: placeholder.size,
            draggableInCustomize: true,
            pixelOffset: pixelOffset,
            depthHeight: depthHeight
        )
    }

    private func applyCollar() {
        collarNode?.removeFromParent()
        collarNode = nil

        guard let collarID = layoutState.equippedItemID(for: .collar),
              catVisual.size.height > 0 else { return }

        let accent = PetShopCatalog.collarAccentColor(for: collarID)
        let container = SKNode()

        let bandHeight: CGFloat = 8
        let bandWidth = catVisual.size.width * 0.55
        let neckY = catVisual.size.height * 0.72

        let band = SKShapeNode(rectOf: CGSize(width: bandWidth, height: bandHeight), cornerRadius: bandHeight / 2)
        band.fillColor = accent
        band.strokeColor = accent.withAlphaComponent(0.85)
        band.lineWidth = 1
        band.position = CGPoint(x: 0, y: neckY)
        container.addChild(band)

        switch collarID {
        case "collar_bell":
            let bell = SKShapeNode(circleOfRadius: 5)
            bell.fillColor = accent
            bell.strokeColor = .white
            bell.lineWidth = 1
            bell.position = CGPoint(x: 0, y: neckY - 10)
            container.addChild(bell)
        case "collar_star":
            let star = SKLabelNode(text: "★")
            star.fontSize = 14
            star.fontColor = accent
            star.verticalAlignmentMode = .center
            star.position = CGPoint(x: bandWidth * 0.32, y: neckY)
            container.addChild(star)
        default:
            let bow = SKLabelNode(text: "♥")
            bow.fontSize = 12
            bow.fontColor = accent
            bow.verticalAlignmentMode = .center
            bow.position = CGPoint(x: bandWidth * 0.28, y: neckY)
            container.addChild(bow)
        }

        container.zPosition = 2
        catFacing.addChild(container)
        collarNode = container
    }

    private func placeOwnedFurniture() {
        for item in PetShopCatalog.all where item.isFloorItem {
            guard layoutState.owns(item.id), !layoutState.isStashed(item.id) else { continue }
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
        pixelOffset: CGPoint = .zero,
        depthHeight: CGFloat? = nil
    ) {
        propInstallOffsets[key] = pixelOffset
        // Height used for depth clamping/scaling. Defaults to the prop's own
        // height, but can be overridden so a tall prop drags like a shorter one.
        let naturalHeight = depthHeight ?? placeholderSize.height
        propNaturalHeights[key] = naturalHeight
        let normalized = clampNormalizedToFloor(layoutState.propPositions[key] ?? defaultPoint)
        var point = scenePoint(from: normalized)
        point.x += pixelOffset.x
        point.y += pixelOffset.y
        let node = makePropNode(imageName: imageName, caption: caption, placeholderSize: placeholderSize, point: point, roomProp: roomProp)
        addChild(node)
        applyDepthTransform(to: node, baseAnchor: clampPropAnchor(point, naturalHeight: naturalHeight), naturalHeight: naturalHeight)
        applyFlip(to: node, key: key)
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

    private func clampNormalizedToFloor(_ point: NormalizedPoint) -> NormalizedPoint {
        NormalizedPoint(
            x: min(max(point.x, 0.06), 0.94),
            y: min(max(point.y, propFrontBound), floorBand.upperBound)
        )
    }

    /// Picture frames live on the wall — above the floor/wall seam, never on the floor band.
    private func clampNormalizedToWall(_ point: NormalizedPoint) -> NormalizedPoint {
        let wallLowerBound = floorBand.upperBound + 0.02
        return NormalizedPoint(
            x: min(max(point.x, 0.08), 0.92),
            y: min(max(point.y, wallLowerBound), 0.92)
        )
    }

    private func normalizedWallPoint(from sceneCenter: CGPoint) -> NormalizedPoint {
        clampNormalizedToWall(
            NormalizedPoint(
                x: sceneCenter.x / max(size.width, 1),
                y: sceneCenter.y / max(size.height, 1)
            )
        )
    }

    /// Keeps the frame's center on the wall with its bottom edge above the floor seam.
    private func clampPictureFrameCenter(_ point: CGPoint, frameHeight: CGFloat) -> CGPoint {
        let seam = size.height * floorBand.upperBound
        let minY = seam + frameHeight / 2 + 6
        let maxY = size.height * 0.92 - frameHeight / 2
        return CGPoint(
            x: min(max(point.x, size.width * 0.08), size.width * 0.92),
            y: min(max(point.y, minY), max(minY, maxY))
        )
    }

    private func isPictureFrame(_ key: String) -> Bool {
        key == PetShopCatalog.pictureFrameID
    }

    private func normalizedPoint(from scenePoint: CGPoint) -> NormalizedPoint {
        NormalizedPoint(
            x: min(max(scenePoint.x / max(size.width, 1), 0.06), 0.94),
            y: min(max(scenePoint.y / max(size.height, 1), propFrontBound), floorBand.upperBound)
        )
    }

    /// Floor contact point for a prop — bottom-center for sprites, bottom-center for placeholders.
    private func propFloorAnchor(for node: SKNode) -> CGPoint {
        if let sprite = node as? SKSpriteNode {
            return sprite.position
        }
        let frame = node.calculateAccumulatedFrame()
        return CGPoint(x: frame.midX, y: frame.minY)
    }

    private func setPropFloorAnchor(_ node: SKNode, to anchor: CGPoint) {
        if let sprite = node as? SKSpriteNode {
            sprite.position = anchor
        } else {
            let halfH = node.calculateAccumulatedFrame().height / 2
            node.position = CGPoint(x: anchor.x, y: anchor.y + halfH)
        }
    }

    /// Clamps a prop's floor anchor (bottom-center) into the draggable region.
    /// X stays off the side edges. Y stays within the floor band, but its top is
    /// pulled in so that — even at `depthMinScale` — the prop's top never rises
    /// past the floor/wall seam (`floorBand.upperBound`). Keeps props on the floor.
    private func clampPropAnchor(_ point: CGPoint, naturalHeight: CGFloat) -> CGPoint {
        let floorBottom = size.height * propFrontBound
        let seam = size.height * floorBand.upperBound
        // Floor-bound props are held back by their own height so their top stays
        // under the seam. Tall props lean on the wall, so they use a small
        // reference height and get the same deep range as the bowls.
        let referenceHeight = naturalHeight <= depthTallPropThreshold ? naturalHeight : depthWallLeanReference
        let backLimit = seam - depthMinScale * referenceHeight
        return CGPoint(
            x: min(max(point.x, size.width * 0.06), size.width * 0.94),
            y: min(max(point.y, floorBottom), max(backLimit, floorBottom))
        )
    }

    /// Raw perspective scale for anything standing on the floor at `baseY`: full
    /// size at the front of the band, shrinking toward the back. Shared by props
    /// and the cat so they recede together.
    private func depthPerspectiveScale(baseY: CGFloat, backScale: CGFloat) -> CGFloat {
        let floorBottom = size.height * floorBand.lowerBound
        let seam = size.height * floorBand.upperBound
        let span = max(seam - floorBottom, 1)
        let t = min(max((baseY - floorBottom) / span, 0), 1)   // 0 front … 1 back
        return depthFrontScale + (backScale - depthFrontScale) * t
    }

    /// Perspective scale for a prop whose base sits at `baseY`. Same curve as the
    /// cat, but additionally capped so the prop's top can never cross the seam.
    /// Prop perspective scale: the shared back-shrink curve, extended with a
    /// front "near zone" so a prop dragged below the floor band toward the bottom
    /// of the screen grows past full size, up to `depthNearScale`.
    private func propPerspectiveScale(baseY: CGFloat) -> CGFloat {
        let frontEdge = size.height * floorBand.lowerBound   // full size here
        guard baseY < frontEdge else {
            return depthPerspectiveScale(baseY: baseY, backScale: depthBackScale)
        }
        let nearEdge = size.height * propFrontBound           // largest here
        let span = max(frontEdge - nearEdge, 1)
        let f = min(max((frontEdge - baseY) / span, 0), 1)    // 0 at band front … 1 at bottom
        return depthFrontScale + (depthNearScale - depthFrontScale) * f
    }

    private func depthScale(baseY: CGFloat, naturalHeight: CGFloat) -> CGFloat {
        let perspective = propPerspectiveScale(baseY: baseY)
        // Tall props lean on the wall: scale by perspective only, no seam cap.
        guard naturalHeight <= depthTallPropThreshold else { return perspective }
        let seam = size.height * floorBand.upperBound
        let fitCap = naturalHeight > 0 ? (seam - baseY) / naturalHeight : perspective
        return max(min(perspective, fitCap), depthMinScale)
    }

    /// Scales a prop for depth and pins its base (feet) to `baseAnchor`, so it
    /// grows upward from the floor rather than around its center.
    private func applyDepthTransform(to node: SKNode, baseAnchor: CGPoint, naturalHeight: CGFloat) {
        node.setScale(depthScale(baseY: baseAnchor.y, naturalHeight: naturalHeight))
        setPropFloorAnchor(node, to: baseAnchor)
    }

    // MARK: Cat

    private func buildCat() {
        cat.zPosition = catDefaultZ
        addChild(cat)

        cat.addChild(catFacing)
        catVisual.anchorPoint = CGPoint(x: 0.5, y: 0) // feet at the node origin
        catFacing.addChild(catVisual)

        if let frame = frames(for: .idle).first {
            applyCatFrame(frame)
            currentAction = .idle
        }
        cat.position = clampCatPosition(CGPoint(x: size.width * 0.5, y: randomFloorY()))
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
        applyCollar()
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

    /// The ambient activities the cat picks between when left alone.
    private enum AmbientBehavior: CaseIterable {
        case wander, sit, groom, sleep, play, eat, drink
    }

    /// The previous activity, so we avoid repeating it back-to-back and the
    /// routine doesn't fall into an obvious loop.
    private var lastBehavior: AmbientBehavior?
    /// Wander hops taken in a row, so a stroll can chain a few steps but never
    /// wanders forever before doing something else.
    private var wanderStreak = 0

    private func runBehavior() {
        guard !isInteracting, !isHoldingPose, !isTrickMode else { return }
        let choice = pickBehavior()
        lastBehavior = choice
        if choice != .wander { wanderStreak = 0 }
        switch choice {
        case .wander: wander()
        case .sit:    idleFor(state: .sit, duration: Double.random(in: 2.5...5.5))
        case .groom:  idleFor(state: .groom, duration: Double.random(in: 2...4.5))
        case .sleep:  sleep()
        case .play:   playfulPounce()
        case .eat:    ambientVisitBowl(.eat)
        case .drink:  ambientVisitBowl(.drink)
        }
    }

    /// Weighted random pick that won't immediately repeat the last non-wander
    /// activity, so the cat feels spontaneous rather than cyclic.
    private func pickBehavior() -> AmbientBehavior {
        var weights: [AmbientBehavior: Int] = [
            .wander: 34, .sit: 17, .groom: 17, .sleep: 12, .play: 12
        ]
        // Occasional self-feeding — only when the matching bowl is actually in
        // the room, otherwise the cat would walk to nothing. Skip during room
        // customize so the cat keeps strolling without blocking bowl placement.
        if !isCustomizeMode {
            if propNodes[.foodBowl] != nil { weights[.eat] = 8 }
            if propNodes[.waterBowl] != nil { weights[.drink] = 8 }
        }
        if let last = lastBehavior, last != .wander { weights[last] = 2 }
        let pool = weights.flatMap { Array(repeating: $0.key, count: $0.value) }
        return pool.randomElement() ?? .wander
    }

    private func wander() {
        guard !isHoldingPose else { return }
        wanderStreak += 1
        let margin = maxCatHorizontalHalfWidth
        let minX = margin
        let maxX = max(margin, size.width - margin)
        let targetX = minX == maxX ? size.width / 2 : CGFloat.random(in: minX...maxX)
        let target = clampCatPosition(CGPoint(x: targetX, y: randomFloorY()))
        face(towards: target.x)
        startAnimation(.walk)
        // Vary the gait a touch each trip so strolls don't look metronomic.
        let speed = walkSpeed * CGFloat.random(in: 0.75...1.35)
        let distance = hypot(target.x - cat.position.x, target.y - cat.position.y)
        let duration = max(0.4, TimeInterval(distance / speed))
        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        runBehaviorAction(move) { [weak self] in
            guard let self else { return }
            self.startAnimation(.idle)
            // Sometimes keep strolling to another spot; otherwise pause and re-roll.
            if self.wanderStreak < 3, Double.random(in: 0...1) < 0.4 {
                self.runBehaviorAction(.wait(forDuration: Double.random(in: 0.2...0.8))) {
                    self.wander()
                }
            } else {
                self.wanderStreak = 0
                self.runBehaviorAction(.wait(forDuration: Double.random(in: 0.5...2.0))) {
                    self.runBehavior()
                }
            }
        }
    }

    /// Curls up for a long nap. Petting the cat (`petCat`) cancels this and
    /// wakes it early.
    private func sleep() {
        idleFor(state: .sleep, duration: 30)
    }

    /// A short burst of play: the cat faces a random way and does a couple of
    /// quick forward pounces before settling — a bit of spontaneous energy.
    private func playfulPounce() {
        stopMovement()
        face(towards: cat.position.x + (Bool.random() ? 70 : -70))
        startAnimation(.pounce)
        let count = Int.random(in: 2...3)
        runPounceAnimation(squash: 0.86, offset: pounceForwardOffset(distance: PounceHop.playfulDistance), repeatCount: count)
        isHoldingPose = true
        runBehaviorAction(.wait(forDuration: Double(count) * PounceHop.hopDuration + 0.3)) { [weak self] in
            guard let self else { return }
            self.isHoldingPose = false
            self.startAnimation(.idle)
            self.runBehavior()
        }
    }

    /// Self-initiated trip to a bowl: the cat strolls over on its own and plays
    /// the eat/drink pose, then rejoins the ambient routine. Reuses `goToBowl`,
    /// the same walk-and-face logic the welcome/feed sequences use. Cosmetic only
    /// — like the welcome bite, it never refills hunger/thirst; the care economy
    /// owns that and depletes on its own schedule regardless.
    private func ambientVisitBowl(_ pose: CatAction) {
        guard !isCustomizeMode else { runBehavior(); return }
        let slot: RoomProp = pose == .eat ? .foodBowl : .waterBowl
        guard let bowl = propNodes[slot] else { runBehavior(); return }
        goToBowl(bowl, pose: pose, hold: Double.random(in: 1.8...2.8)) { [weak self] in
            guard let self else { return }
            self.startAnimation(.idle)
            self.runBehavior()
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
        cat.removeAction(forKey: "pounceMove")
        cat.zPosition = catDefaultZ
    }

    private enum PounceHop {
        static let crouchDuration: TimeInterval = 0.12
        static let extendDuration: TimeInterval = 0.17
        static let playfulDistance: CGFloat = 40
        static let laserDistance: CGFloat = 34
        static var hopDuration: TimeInterval { crouchDuration + extendDuration }
    }

    private func pounceVisualAction(squash: CGFloat) -> SKAction {
        .sequence([
            .scaleY(to: squash, duration: PounceHop.crouchDuration),
            .scaleY(to: 1.0, duration: PounceHop.extendDuration)
        ])
    }

    /// World-space travel for one hop; most of the distance lands on the extend phase.
    private func pounceMoveAction(offset: CGVector) -> SKAction {
        let crouch = SKAction.moveBy(
            x: offset.dx * 0.10, y: offset.dy * 0.10,
            duration: PounceHop.crouchDuration
        )
        let leap = SKAction.moveBy(
            x: offset.dx * 0.90, y: offset.dy * 0.90,
            duration: PounceHop.extendDuration
        )
        leap.timingMode = .easeOut
        return .sequence([crouch, leap])
    }

    private func pounceForwardOffset(distance: CGFloat) -> CGVector {
        let sign: CGFloat = facesLeft ? -1 : 1
        return CGVector(dx: distance * sign, dy: 0)
    }

    private func pounceTowardOffset(from origin: CGPoint, to target: CGPoint, distance: CGFloat) -> CGVector {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = hypot(dx, dy)
        guard length > 0.001 else { return pounceForwardOffset(distance: distance) }
        return CGVector(dx: dx / length * distance, dy: dy / length * distance)
    }

    private func runPounceAnimation(squash: CGFloat, offset: CGVector, repeatCount: Int = 1) {
        catVisual.removeAction(forKey: "pounce")
        cat.removeAction(forKey: "pounceMove")
        let visual = repeatCount > 1
            ? SKAction.repeat(pounceVisualAction(squash: squash), count: repeatCount)
            : pounceVisualAction(squash: squash)
        let move = repeatCount > 1
            ? SKAction.repeat(pounceMoveAction(offset: offset), count: repeatCount)
            : pounceMoveAction(offset: offset)
        catVisual.run(visual, withKey: "pounce")
        cat.run(move, withKey: "pounceMove")
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
        if state == .eat || state == .drink || state == .snack {
            applyBowlPose(state)
            return
        }

        currentAction = state
        catVisual.removeAction(forKey: "anim")
        catVisual.removeAction(forKey: "pounce")
        cat.removeAction(forKey: "pounceMove")

        let actionFrames = frames(for: state)
        // Each groom_* frame is a distinct pose variant — hold one at random, don't cycle.
        if state == .groom, let frame = actionFrames.randomElement() {
            applyCatFrame(frame)
            resetVisualTransform()
            return
        }
        if state == .idle, actionFrames.count >= 3 {
            startSlowIdleAnimation(actionFrames)
            resetVisualTransform()
            return
        }
        if isTrickMode, state == .sit, let frame = actionFrames.first {
            applyCatFrame(frame)
            resetVisualTransform()
            return
        }
        if actionFrames.count > 1 {
            applyCatFrame(actionFrames[0])
            catVisual.run(
                .repeatForever(.animate(with: actionFrames.map(\.texture), timePerFrame: frameDuration(for: state))),
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

    /// Applies eat, drink, or snack atlas frames only — never falls through to idle/walk.
    private func applyBowlPose(_ pose: CatAction) {
        currentAction = pose
        catVisual.removeAction(forKey: "anim")
        catVisual.removeAction(forKey: "pounce")
        cat.removeAction(forKey: "pounceMove")

        let actionFrames = frames(for: pose)
        guard let first = actionFrames.first else {
            resetVisualTransform()
            return
        }
        applyCatFrame(first)
        if actionFrames.count > 1 {
            catVisual.run(
                .repeatForever(.animate(with: actionFrames.map(\.texture), timePerFrame: frameDuration(for: pose))),
                withKey: "anim"
            )
        }
        resetVisualTransform()
    }

    /// Stand in front of and beside a bowl so the lowered head lines up with the prop.
    private func bowlApproachPoint(for bowl: SKNode, from catPosition: CGPoint) -> (target: CGPoint, faceX: CGFloat) {
        let anchor = propFloorAnchor(for: bowl)
        let frame = bowl.calculateAccumulatedFrame()
        let bowlCenterX = frame.midX
        let lateralGap = max(bowlApproachLateralGap, frame.width * 0.32)
        let side: CGFloat = catPosition.x < bowlCenterX ? -1 : 1
        let margin = maxCatHorizontalHalfWidth
        let targetX = min(max(bowlCenterX + lateralGap * side, margin), size.width - margin)
        let frontY = anchor.y - bowlApproachFrontInset
        let targetY = min(max(frontY, size.height * catFloorBand.lowerBound),
                          size.height * catFloorBand.upperBound)
        return (CGPoint(x: targetX, y: targetY), bowlCenterX)
    }

    /// Default standing pose uses frame 0; frames 1–2 swap in every few seconds.
    private func startSlowIdleAnimation(_ actionFrames: [CatFrame]) {
        applyCatFrame(actionFrames[0])
        let wait = { SKAction.wait(forDuration: Double.random(in: 5...7)) }
        let show: (CatFrame) -> SKAction = { [weak self] frame in
            .run { self?.applyCatFrame(frame) }
        }
        catVisual.run(
            .repeatForever(.sequence([
                wait(), show(actionFrames[1]),
                wait(), show(actionFrames[2]),
            ])),
            withKey: "anim"
        )
    }

    /// Seconds each frame is held while looping an action's animation. Walk is a
    /// brisk gait; sit (looking around) is a slow, deliberate pose so it doesn't
    /// flicker; everything else uses a moderate default.
    private func frameDuration(for state: CatAction) -> TimeInterval {
        switch state {
        case .walk:  return 0.08
        case .sit:   return 2.0
        default:     return 0.18
        }
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
            handleCustomizeTouchBegan(at: location)
            return
        }

        // Trick training is all about the cat — ignore taps on the cat and the
        // care props (food/water bowls, litter box, furniture). Snack handling is
        // driven separately from the SwiftUI controls.
        if isTrickMode { return }

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

        if isCustomizeMode, let key = dragCandidateKey, let node = draggableNodes[key] {
            // Promote a press into a drag only once the finger moves enough,
            // so a stationary tap stays a tap (which selects the prop).
            if !isActivelyDragging {
                let moved = hypot(location.x - dragStartLocation.x, location.y - dragStartLocation.y)
                guard moved >= dragPromoteThreshold else { return }
                isActivelyDragging = true
                draggingKey = key
                node.zPosition = 20
                clearSelection()
            }
            if isPictureFrame(key) {
                let frameHeight = node.calculateAccumulatedFrame().height
                let rawCenter = CGPoint(x: location.x + dragTouchOffset.x, y: location.y + dragTouchOffset.y)
                node.position = clampPictureFrameCenter(rawCenter, frameHeight: frameHeight)
                return
            }
            let naturalHeight = propNaturalHeights[key] ?? node.calculateAccumulatedFrame().height
            let rawAnchor = CGPoint(x: location.x + dragTouchOffset.x, y: location.y + dragTouchOffset.y)
            let anchor = clampPropAnchor(rawAnchor, naturalHeight: naturalHeight)
            applyDepthTransform(to: node, baseAnchor: anchor, naturalHeight: naturalHeight)
            applyFlip(to: node, key: key)
            return
        }

        guard isPlaying else { return }
        isLaserEngaged = true
        moveLaser(to: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPlaying { isLaserEngaged = false }
        let location = touches.first?.location(in: self)
        if isCustomizeMode {
            finishCustomizeTouch(at: location)
            return
        }
        endCustomizeDrag(at: location)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPlaying { isLaserEngaged = false }
        if isActivelyDragging {
            endCustomizeDrag(at: touches.first?.location(in: self))
        }
        dragCandidateKey = nil
        isActivelyDragging = false
    }

    private func handleCustomizeTouchBegan(at location: CGPoint) {
        // Pick the prop under the finger as a press candidate: a stationary
        // release selects it; movement past the threshold promotes to a drag.
        dragStartLocation = location
        isActivelyDragging = false
        dragCandidateKey = propKey(at: location)
        if let key = dragCandidateKey, let node = draggableNodes[key] {
            let grabPoint = isPictureFrame(key) ? node.position : propFloorAnchor(for: node)
            dragTouchOffset = CGPoint(x: grabPoint.x - location.x, y: grabPoint.y - location.y)
        }
    }

    /// Topmost draggable prop whose padded frame contains `location`.
    private func propKey(at location: CGPoint) -> String? {
        var best: (key: String, z: CGFloat)?
        for (key, node) in draggableNodes
        where node.calculateAccumulatedFrame().insetBy(dx: -12, dy: -12).contains(location) {
            if best == nil || node.zPosition > best!.z { best = (key, node.zPosition) }
        }
        return best?.key
    }

    private func finishCustomizeTouch(at location: CGPoint?) {
        if isActivelyDragging {
            endCustomizeDrag(at: location)
        } else if let key = dragCandidateKey {
            selectProp(key)
        } else {
            clearSelection()
        }
        dragCandidateKey = nil
        isActivelyDragging = false
    }

    private func endCustomizeDrag(at location: CGPoint? = nil) {
        guard let key = draggingKey, let node = draggableNodes[key] else {
            draggingKey = nil
            return
        }

        if isPictureFrame(key) {
            let frameHeight = node.calculateAccumulatedFrame().height
            let clamped = clampPictureFrameCenter(node.position, frameHeight: frameHeight)
            node.position = clamped
            let normalized = normalizedWallPoint(from: clamped)
            var positions = layoutState.propPositions
            positions[key] = normalized
            layoutState.propPositions = positions
            onLayoutPositionsChanged?(positions)
            node.zPosition = isCustomizeMode ? pictureFrameCustomizeZ : pictureFrameZ
            draggingKey = nil
            return
        }

        let anchor = propFloorAnchor(for: node)
        let offset = propInstallOffsets[key] ?? .zero
        let normalized = normalizedPoint(
            from: CGPoint(x: anchor.x - offset.x, y: anchor.y - offset.y)
        )
        var positions = layoutState.propPositions
        positions[key] = normalized
        layoutState.propPositions = positions
        onLayoutPositionsChanged?(positions)
        node.zPosition = propNodes.values.contains(where: { $0 === node }) ? 5 : 0
        draggingKey = nil
    }

    /// Only owned décor can be stashed: shop floor items (furniture, toys) and the
    /// picture frame. The built-in care props — food, water, litter — and the cat
    /// tree can never be stashed.
    private func isStashable(_ key: String) -> Bool {
        let careProps: Set<String> = [
            PetRoomPropKey.foodBowl,
            PetRoomPropKey.waterBowl,
            PetRoomPropKey.litterBox,
            PetRoomPropKey.catTree
        ]
        guard !careProps.contains(key), let item = PetShopCatalog.item(id: key) else { return false }
        return item.isFloorItem || item.isPictureFrame
    }

    /// Removes a prop from the room and marks it stashed (still owned).
    private func stashProp(_ key: String) {
        guard draggableNodes[key] != nil else { return }
        draggingKey = nil
        dragCandidateKey = nil
        isActivelyDragging = false
        clearSelection()
        // Persist stash first — an early layout refresh used to re-place the prop
        // before `stashedItemIDs` was updated.
        onStashProp?(key)
    }

    func isStashableProp(_ key: String) -> Bool {
        isStashable(key)
    }

    func flipCustomizeProp(_ key: String) {
        guard isCustomizeMode, draggableNodes[key] != nil else { return }
        selectedKey = key
        flipSelectedProp()
    }

    func stashCustomizeProp(_ key: String) {
        guard isCustomizeMode, isStashable(key), draggableNodes[key] != nil else { return }
        stashProp(key)
    }

    // MARK: Selection (tap a prop → dotted outline; Flip/Stash pills live in SwiftUI)

    private func selectProp(_ key: String) {
        guard draggableNodes[key] != nil else { clearSelection(); return }
        selectedKey = key
        buildSelectionOverlay(for: key)
        onCustomizeSelectionChanged?(key)
        onCustomizeSelectionAnchorChanged?(selectionActionAnchor(for: key))
    }

    private func clearSelection() {
        selectionOverlay?.removeFromParent()
        selectionOverlay = nil
        selectedKey = nil
        onCustomizeSelectionChanged?(nil)
        onCustomizeSelectionAnchorChanged?(nil)
    }

    private func flipSelectedProp() {
        guard let key = selectedKey, let node = draggableNodes[key] else { return }
        if let idx = layoutState.flippedItemIDs.firstIndex(of: key) {
            layoutState.flippedItemIDs.remove(at: idx)
        } else {
            layoutState.flippedItemIDs.append(key)
        }
        node.xScale = -node.xScale            // mirror horizontally in place
        onToggleFlip?(key)                    // persist
    }

    /// Mirrors a node if its prop is flipped. Call after any `setScale`, which
    /// resets the sign of `xScale`.
    private func applyFlip(to node: SKNode, key: String) {
        node.xScale = abs(node.xScale) * (layoutState.isFlipped(key) ? -1 : 1)
    }

    /// Point in scene coordinates for centering SwiftUI Flip/Stash pills above a prop.
    private func selectionActionAnchor(for key: String) -> CGPoint? {
        guard let node = draggableNodes[key] else { return nil }
        let frame = node.calculateAccumulatedFrame()
        let outlineRect = frame.insetBy(dx: -8, dy: -8)
        let buttonHeight: CGFloat = 34
        let rowY = outlineRect.maxY + 16 + buttonHeight / 2
        let estimatedRowWidth: CGFloat = 180
        let minCenter = estimatedRowWidth / 2 + 10
        let maxCenter = size.width - estimatedRowWidth / 2 - 10
        let centerX = min(max(frame.midX, minCenter), max(minCenter, maxCenter))
        return CGPoint(x: centerX, y: rowY)
    }

    private func buildSelectionOverlay(for key: String) {
        selectionOverlay?.removeFromParent()
        guard let node = draggableNodes[key] else { return }
        let frame = node.calculateAccumulatedFrame()

        let overlay = SKNode()
        overlay.zPosition = 60

        // Dotted outline hugging the prop.
        let outlineRect = frame.insetBy(dx: -8, dy: -8)
        let dashed = CGPath(roundedRect: outlineRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
            .copy(dashingWithPhase: 0, lengths: [7, 5])
        let outline = SKShapeNode(path: dashed)
        outline.strokeColor = SKColor(red: 0.88, green: 0.22, blue: 0.38, alpha: 0.95)
        outline.lineWidth = 2.5
        outline.fillColor = .clear
        overlay.addChild(outline)

        addChild(overlay)
        selectionOverlay = overlay
    }

    func setCustomizeMode(_ enabled: Bool) {
        isCustomizeMode = enabled
        if enabled {
            stopMovement()
            catVisual.removeAction(forKey: "anim")
            catVisual.removeAction(forKey: "pounce")
            // Drop any interaction lock (e.g. a mid-greeting eat/drink) so the
            // ambient loop resumes cleanly when customize mode exits.
            isInteracting = false
            runBehavior()
            pictureFrameNode?.zPosition = pictureFrameCustomizeZ
        } else {
            endCustomizeDrag()
            clearSelection()
            dragCandidateKey = nil
            isActivelyDragging = false
            pictureFrameNode?.zPosition = pictureFrameZ
            // Behavior keeps running during customize; only restart if it stalled.
            if cat.action(forKey: "behavior") == nil, !isInteracting, !isHoldingPose {
                runBehavior()
            }
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
        guard !isPlaying, !isTrickMode else { return }
        if isCustomizeMode, kind == .eat || kind == .drink { return }
        stopMovement()
        switch kind {
        case .happy: petCat()
        case .eat:   eatAtBowl()
        case .drink: drinkAtBowl()
        }
    }

    /// Walks the cat to the food bowl and plays the eat animation, then resumes.
    private func eatAtBowl() {
        guard let bowl = propNodes[.foodBowl] else { petCat(); return }
        isInteracting = true
        goToBowl(bowl, pose: .eat, hold: 2.2) { [weak self] in
            guard let self else { return }
            self.isInteracting = false
            self.startAnimation(.idle)
            self.runBehavior()
        }
    }

    /// Walks the cat to the water bowl and plays the drink animation, then resumes.
    private func drinkAtBowl() {
        guard let bowl = propNodes[.waterBowl] else { petCat(); return }
        isInteracting = true
        goToBowl(bowl, pose: .drink, hold: 2.2) { [weak self] in
            guard let self else { return }
            self.isInteracting = false
            self.startAnimation(.idle)
            self.runBehavior()
        }
    }

    /// When you open the room, the cat greets you: it trots to the food bowl
    /// for a bite, then the water bowl for a drink, before its ambient routine
    /// starts. Cosmetic only — it never refills hunger/thirst, which the care
    /// economy owns and depletes on its own schedule regardless of this.
    private func playWelcomeSequence() {
        guard let food = propNodes[.foodBowl], let water = propNodes[.waterBowl] else {
            startAnimation(.idle)
            runBehavior()
            return
        }
        isInteracting = true
        goToBowl(food, pose: .eat, hold: 1.8) { [weak self] in
            guard let self else { return }
            self.goToBowl(water, pose: .drink, hold: 1.8) { [weak self] in
                guard let self else { return }
                self.isInteracting = false
                self.startAnimation(.idle)
                self.runBehavior()
            }
        }
    }

    /// Walks the cat beside `bowl`, turns to face it, holds the eat/drink pose
    /// for `hold` seconds, then calls `completion`. Cancelable via the shared
    /// "behavior" key so customize/trick mode can interrupt it cleanly.
    private func goToBowl(_ bowl: SKNode, pose: CatAction, hold: TimeInterval, completion: @escaping () -> Void) {
        if isCustomizeMode, pose == .eat || pose == .drink {
            completion()
            return
        }
        stopMovement()
        catVisual.removeAction(forKey: "anim")
        cat.zPosition = max(bowl.zPosition + 1, catAtBowlZ)
        let approach = bowlApproachPoint(for: bowl, from: cat.position)
        face(towards: approach.target.x)
        startAnimation(.walk)
        let distance = hypot(approach.target.x - cat.position.x, approach.target.y - cat.position.y)
        let move = SKAction.move(to: approach.target, duration: max(0.3, TimeInterval(distance / walkSpeed)))
        move.timingMode = .easeInEaseOut
        let arrive = SKAction.run { [weak self] in
            guard let self else { return }
            self.cat.zPosition = max(bowl.zPosition + 1, self.catAtBowlZ)
            self.face(towards: approach.faceX)
            self.applyBowlPose(pose)
        }
        let finish = SKAction.run { [weak self] in
            guard let self else { return }
            self.cat.zPosition = self.catDefaultZ
            completion()
        }
        cat.run(.sequence([move, arrive, .wait(forDuration: hold), finish]), withKey: "behavior")
    }

    // MARK: Laser play

    /// Enters laser-pointer play: a glowing dot appears and the cat chases it
    /// (steered each frame in `update`). The dot follows the user's touch.
    func startLaserPlay() {
        guard !isPlaying, !isTrickMode else { return }
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
        if !isTrickMode { runBehavior() }
    }

    // MARK: Trick training

    /// Pauses ambient behavior while the user trains voice commands. On entering,
    /// the cat trots to the middle of the floor and sits — its resting spot for
    /// training.
    func setTrickMode(_ active: Bool) {
        isTrickMode = active
        if active {
            if isPlaying { endLaserPlay() }
            stopMovement()
            catVisual.removeAction(forKey: "anim")
            isInteracting = false
            isHoldingPose = false
            walkToCenterAndSit()
        } else {
            clearSnack()
            isInteracting = false
            startAnimation(.idle)
            runBehavior()
        }
    }

    /// Sends the cat to the middle of the floor band and sits it down. Cancelable
    /// via the shared "behavior" key, so a trick command or snack interrupts it.
    private func walkToCenterAndSit() {
        stopMovement()
        catVisual.removeAction(forKey: "anim")
        isInteracting = false
        isHoldingPose = false
        let centerY = size.height * (catFloorBand.lowerBound + catFloorBand.upperBound) / 2
        let target = CGPoint(x: size.width * 0.5, y: centerY)
        face(towards: target.x)
        let distance = hypot(target.x - cat.position.x, target.y - cat.position.y)
        if distance < 12 {
            cat.removeAction(forKey: "behavior")
            if isTrickMode {
                beginTrickModeAttentiveSit()
            } else {
                isHoldingPose = true
                startAnimation(.sit)
            }
            return
        }
        startAnimation(.walk)
        let move = SKAction.move(to: target, duration: max(0.3, TimeInterval(distance / walkSpeed)))
        move.timingMode = .easeInEaseOut
        let arrive = SKAction.run { [weak self] in
            guard let self else { return }
            if self.isTrickMode {
                self.beginTrickModeAttentiveSit()
            } else {
                self.isHoldingPose = true
                self.startAnimation(.sit)
            }
        }
        cat.run(.sequence([move, arrive]), withKey: "behavior")
    }

    /// Sits the cat in a steady pose for trick training, facing the player.
    private func beginTrickModeAttentiveSit() {
        guard isTrickMode else { return }
        isHoldingPose = true
        face(towards: size.width * 0.5)
        startAnimation(.sit)
    }

    // MARK: Trick-training snack

    /// Moves (or spawns) the dragged snack to a scene point, following the finger.
    func moveSnack(toSceneX x: CGFloat, sceneY y: CGFloat) {
        guard isTrickMode, !isSnackBeingEaten else { return }
        let snack: SKNode
        if let existing = snackNode {
            snack = existing
        } else {
            snack = makeSnackNode()
            addChild(snack)
            snackNode = snack
        }
        snack.position = CGPoint(x: x, y: y)
        lookAtSnackWhileWaiting(at: x)
    }

    /// While a treat is held above the floor, the cat turns to face it.
    private func lookAtSnackWhileWaiting(at sceneX: CGFloat) {
        guard isTrickMode, !isInteracting, isHoldingPose, currentAction == .sit else { return }
        face(towards: sceneX)
    }

    /// Drops the snack onto the floor; the cat walks over, eats, and the snack
    /// fades away after a couple of seconds.
    func dropSnack(atSceneX x: CGFloat, sceneY y: CGFloat) {
        guard isTrickMode, let snack = snackNode, !isSnackBeingEaten else { return }
        isSnackBeingEaten = true
        let floorY = min(max(y, size.height * catFloorBand.lowerBound),
                         size.height * catFloorBand.upperBound)
        let target = CGPoint(x: min(max(x, size.width * 0.08), size.width * 0.92), y: floorY)
        snack.removeAllActions()
        snack.zPosition = 0.5   // on the floor, behind the cat as it eats
        snack.run(.move(to: target, duration: 0.16)) { [weak self] in
            self?.eatSnack(snack)
        }
    }

    /// Removes a snack that's only being dragged (never started being eaten).
    func cancelSnack() {
        guard !isSnackBeingEaten else { return }
        snackNode?.removeFromParent()
        snackNode = nil
        if isTrickMode, isHoldingPose, currentAction == .sit {
            face(towards: size.width * 0.5)
        }
    }

    private func clearSnack() {
        snackNode?.removeFromParent()
        snackNode = nil
        isSnackBeingEaten = false
    }

    private func eatSnack(_ snack: SKNode) {
        isInteracting = true
        goToBowl(snack, pose: .snack, hold: 2.0) { [weak self] in
            guard let self else { return }
            snack.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
            self.snackNode = nil
            self.isSnackBeingEaten = false
            self.isInteracting = false
            self.walkToCenterAndSit()
            self.onSnackEaten?()
        }
    }

    private func makeSnackNode() -> SKNode {
        let treat = SKLabelNode(text: "🐟")
        treat.fontSize = 34
        treat.verticalAlignmentMode = .center
        treat.horizontalAlignmentMode = .center
        let container = SKNode()
        container.addChild(treat)
        container.zPosition = 45   // above the cat while held by the finger
        return container
    }

    /// Plays a trick animation. `succeeded` false shows the confused pose.
    func playTrick(_ trick: PetTrick, succeeded: Bool, completion: (() -> Void)? = nil) {
        guard isTrickMode else { completion?(); return }
        clearSnack()   // a command interrupts any in-progress snack eat
        stopMovement()
        catVisual.removeAllActions()
        isInteracting = true
        isHoldingPose = true

        if succeeded {
            let action = catAction(for: trick)
            startTrickAnimation(action, duration: trick == .spin ? 1.4 : 1.8) { [weak self] in
                guard let self else { completion?(); return }
                self.isInteracting = false
                self.walkToCenterAndSit()
                completion?()
            }
        } else {
            startTrickAnimation(.confused, duration: 1.5) { [weak self] in
                guard let self else { completion?(); return }
                self.isInteracting = false
                self.beginTrickModeAttentiveSit()
                completion?()
            }
        }
    }

    private func catAction(for trick: PetTrick) -> CatAction {
        switch trick {
        case .paw: return .paw
        case .highFive: return .highFive
        case .up: return .up
        case .spin: return .spin
        case .down: return .down
        case .sayHi: return .sayHi
        }
    }

    private func startTrickAnimation(_ state: CatAction, duration: TimeInterval, completion: @escaping () -> Void) {
        currentAction = state
        catVisual.removeAction(forKey: "anim")
        let actionFrames = frames(for: state)
        if actionFrames.count > 1 {
            applyCatFrame(actionFrames[0])
            let animate = SKAction.animate(with: actionFrames.map(\.texture), timePerFrame: 0.22)
            catVisual.run(animate, withKey: "anim")
        } else if let single = actionFrames.first {
            applyCatFrame(single)
        }
        resetVisualTransform()
        cat.run(.wait(forDuration: duration)) { completion() }
    }

    private func moveLaser(to point: CGPoint) {
        // Keep the dot within the floor band so the cat can reach it.
        let y = min(max(point.y, size.height * catFloorBand.lowerBound), size.height * catFloorBand.upperBound)
        laserDot?.position = CGPoint(x: point.x, y: y)
        face(towards: point.x)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime

        // Match the props' floor perspective: the cat shrinks as it walks toward
        // the back of the room and grows as it comes forward. Scales around its
        // feet (the cat node's origin), so it stays planted on the floor.
        cat.setScale(depthPerspectiveScale(baseY: cat.position.y, backScale: catDepthBackScale))
        cat.position = clampCatPosition(cat.position)

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
            cat.position = clampCatPosition(CGPoint(
                x: cat.position.x + dx / distance * step,
                y: cat.position.y + dy / distance * step
            ))
            if catVisual.action(forKey: "anim") == nil { startAnimation(.walk) }
        } else if catVisual.action(forKey: "pounce") == nil {
            // Caught up — leap toward the dot, then keep chasing.
            startAnimation(.pounce)
            let offset = pounceTowardOffset(from: cat.position, to: dot.position, distance: PounceHop.laserDistance)
            runPounceAnimation(squash: 0.88, offset: offset)
        }
    }

    private func petCat() {
        guard !isInteracting else { return }
        isInteracting = true
        stopMovement()
        // Wake to a standing pose first, so petting a sleeping/grooming cat
        // reads as "woke up", then it bounces happily.
        startAnimation(.idle)

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
        case .eat: return ["eat_"]
        case .drink: return ["drink_"]
        case .snack: return ["snack_"]
        default: return ["\(action.rawValue)_"]
        }
    }

    private func frameIndex(_ name: String) -> Int {
        let base = (name as NSString).deletingPathExtension
        if let n = base.split(separator: "_").last.flatMap({ Int($0) }) { return n }
        return 0
    }

    /// The cat keeps a little forward of the back wall so it never looks like
    /// it's standing on the seam — a shallower slice of `floorBand`.
    private var catFloorBand: ClosedRange<CGFloat> {
        let backInset: CGFloat = 0.035
        return floorBand.lowerBound...max(floorBand.lowerBound, floorBand.upperBound - backInset)
    }

    private func randomFloorY() -> CGFloat {
        CGFloat.random(in: size.height * catFloorBand.lowerBound...size.height * catFloorBand.upperBound)
    }

    /// Widest atlas frame at full front-of-room scale — used when picking walk
    /// targets so even broad poses (e.g. Arabella's walk frames) stay on screen.
    private var maxCatHorizontalHalfWidth: CGFloat {
        let maxFrameWidth = frameDisplaySizes.values.map(\.width).max() ?? catDisplayHeight
        return maxFrameWidth * depthFrontScale / 2 + catScreenEdgeInset
    }

    /// Keeps the cat's feet anchor on screen. The sprite is centered on the
    /// anchor horizontally, so clamp by half the drawn width.
    private func clampCatPosition(_ point: CGPoint) -> CGPoint {
        let measured = cat.calculateAccumulatedFrame().width / 2 + catScreenEdgeInset
        let halfW = measured > catScreenEdgeInset ? measured : maxCatHorizontalHalfWidth
        let minX = halfW
        let maxX = max(minX, size.width - halfW)
        let minY = size.height * catFloorBand.lowerBound
        let maxY = size.height * catFloorBand.upperBound
        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
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
