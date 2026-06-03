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
        case cat, foodBowl, waterBowl, litterBox, toiletPaperMess, smallPlant, bigPlant
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
    private let laserFloorLowerBound: CGFloat = 0.06
    /// Points/second the cat walks.
    private let walkSpeed: CGFloat = 70
    /// On-screen cat height; width follows each frame's aspect ratio.
    private let catDisplayHeight: CGFloat = 150
    /// Pick-up pose is drawn smaller in the source art — scale up to match standing size.
    private let catPickUpDisplayHeight: CGFloat = 220
    /// Extra padding so the cat sprite never touches the screen edge.
    private let catScreenEdgeInset: CGFloat = 8
    /// Draw order while eating/drinking so the cat renders in front of the bowl.
    private let catAtBowlZ: CGFloat = 8
    /// While sleeping, nudge the cat slightly behind its floor-depth z for overlap polish.
    private let catSleepDepthOffset: CGFloat = 0.5
    /// Floor prop draw-order band: back props render lower, front props higher.
    private let propDepthBackZ: CGFloat = 4.7
    private let propDepthFrontZ: CGFloat = 6.3
    /// Toilet-paper mess draws above all floor props (it sits "on top" of the mess).
    private let toiletPaperZ: CGFloat = 8
    /// How far in front of a bowl (toward the camera / bottom of screen) the cat stops.
    private let bowlApproachFrontInset: CGFloat = 22
    /// Eat/drink poses lower the muzzle — negative inset raises the landing point
    /// toward the bowl so the head sits over the rim instead of below it.
    private let bowlEatDrinkFrontInset: CGFloat = -36
    /// Horizontal gap from the bowl's visual center to the cat's feet.
    private let bowlApproachLateralGap: CGFloat = 30
    /// Tighter side offset for eat/drink so the muzzle lines up with the bowl opening.
    private let bowlEatDrinkLateralGap: CGFloat = 22
    /// Extra shift right at the water bowl so the drink pose lines up with the rim.
    private let bowlDrinkRightShift: CGFloat = 18
    /// Extra upward nudge when eating a floor snack so the lowered head aligns.
    private let snackApproachRaise: CGFloat = 12
    /// Shop item ids for cat beds that support occupied art (`_0` calico, `_1` cow cat).
    private static let catBedItemIDs: Set<String> = [
        "furniture_cat_bed_1",
        "furniture_cat_bed_2",
        "furniture_cat_bed_3",
        PetRoomPropKey.catBed
    ]

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
    /// Secret-garden backdrop: ~30% gentler shrink so cats stay larger toward the hills.
    private let gardenCatDepthBackScale: CGFloat = 0.5625
    /// Front (closest) edge of the prop drag region — props may slide all the way
    /// down to near the bottom of the screen, ahead of the cat's floor band.
    private let propFrontBound: CGFloat = 0.02
    /// Smallest a prop may shrink. Also caps how far back a prop's base may go,
    /// so even at its smallest the prop's top never crosses the floor/wall seam.
    private let depthMinScale: CGFloat = 0.45
    /// Props taller than this may lean on the wall; shorter props are kept fully
    /// on the floor (top stays under the seam). Set high so tall floor décor like
    /// plants stay bounded to the floorband rather than floating up the wall.
    private let depthTallPropThreshold: CGFloat = 320
    /// Reference height for a wall-leaning prop's back limit — gives it the same
    /// deep drag range as a small floor prop instead of being held down by its
    /// own height.
    private let depthWallLeanReference: CGFloat = 36

    /// Extra "midpoint lift" used only for the cat tree's draw-order switch.
    /// The scene otherwise orders by prop base (feet) Y; shifting the tree's
    /// effective depth base makes the cat go in-front/behind at a higher point
    /// on tall props.
    private let catTreeZMidpointLift: CGFloat = 28

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
    private weak var litterBoxSprite: SKSpriteNode?
    private var isLitterBoxDirty = false
    private var toiletPaperMessNode: SKNode?
    private var isToiletPaperMessVisible = false
    /// Sticky floor anchor for the active toilet-paper mess so room-layout
    /// rebuilds (for other props) don't make it jump around.
    private var toiletPaperMessStableAnchor: CGPoint?
    /// Each litter box is a horizontal 6-frame sheet:
    /// clean, dirty, calico-use A/B, cow-use A/B.
    private static let litterBoxFrameCount = 6
    /// Cached sheet texture for the currently equipped box, keyed by sheet name
    /// so it reloads when the player swaps litter boxes.
    private var litterBoxSheetName: String?
    private var litterBoxSheetTexture: SKTexture?
    private static let toiletPaperAssetName = "prop_toilet_paper"
    private enum LitterBoxFrame: Int {
        case clean = 0
        case dirty = 1
        case calicoUseA = 2
        case calicoUseB = 3
        case cowUseA = 4
        case cowUseB = 5
    }

    /// Whether the equipped litter box is the self-cleaning auto box.
    private var isAutoLitterEquipped: Bool {
        PetShopCatalog.isAutoLitter(equippedItemID: layoutState.equippedItemID(for: .litterBox))
    }

    /// Loads (and caches) the 6-frame sheet for the equipped litter box.
    private func currentLitterSheetTexture() -> SKTexture? {
        let name = PetShopCatalog.litterSheetName(
            forEquippedItemID: layoutState.equippedItemID(for: .litterBox)
        )
        if litterBoxSheetName == name, let cached = litterBoxSheetTexture {
            return cached
        }
        guard let image = UIImage(named: name) else { return nil }
        let texture = SKTexture(image: image)
        litterBoxSheetName = name
        litterBoxSheetTexture = texture
        return texture
    }

    private var isInteracting = false
    private var currentAction: CatAction = .idle
    /// True while the cat is in a sit / sleep / groom pose and should not wander.
    private var isHoldingPose = false

    // MARK: Laser play

    /// Called when the user taps a prop (or the cat). Set by `PetRoomView`.
    var onTapProp: ((RoomProp) -> Void)?

    /// Called when the user taps the wall picture frame in customize mode (opens photo picker).
    var onTapPictureFrame: (() -> Void)?

    /// When true, renders only the adopted cat on a transparent scene (Couples
    /// Profile garden). The ambient routine omits bowl/litter activities because
    /// those props only exist in the pet room.
    var isGardenBackdrop = false
    /// When multiple pets roam the garden, spreads each cat's starting X across
    /// the grass band so they don't stack on top of each other.
    var gardenSpawnIndex = 0
    var gardenSpawnCount = 1

    /// Fired when the default-mode "walk up to the frame" inspect zoom begins or ends.
    var onPictureFrameInspectChanged: ((Bool) -> Void)?

    /// Fired when the user taps the frame while zoomed in (opens the full moment viewer).
    var onTapPictureFrameWhileInspecting: (() -> Void)?

    /// Fired when the walk-up / walk-away camera animation starts or finishes.
    var onPictureFrameInspectAnimatingChanged: ((Bool) -> Void)?

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
    private var roomCamera: SKCameraNode?
    private(set) var isInspectingPictureFrame = false
    private var isPictureFrameInspectAnimating = false
    private let pictureFrameInspectZoomFraction: CGFloat = 0.78
    private let pictureFrameInspectDuration: TimeInterval = 1.05
    /// Fixed draw order behind floor props during normal play.
    private let pictureFrameZ: CGFloat = -2
    /// Raised while customizing so the frame can be tapped above floor décor.
    private let pictureFrameCustomizeZ: CGFloat = 25
    private let pictureFrameWallScale: CGFloat = 1.6
    private var collarNode: SKNode?
    private var draggableNodes: [String: SKNode] = [:]
    /// Bed prop showing the skin-specific occupied sprite while the cat is hidden.
    private var occupiedBedKey: String?
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

    // MARK: Pick up & carry (long-press the cat)

    private var isCarryingCat = false
    private var catPickUpCandidate = false
    private var catPickUpStartLocation = CGPoint.zero
    private var catPickUpTouchOffset = CGPoint.zero
    private var catPickUpStartedAt: TimeInterval = 0
    private var catPickUpLastLocation = CGPoint.zero
    private let catPickUpLongPressDuration: TimeInterval = 0.45
    /// Draw above floor props while the cat is being carried.
    private let catCarryZPosition: CGFloat = 55

    /// Currently selected prop (shows the dotted outline in customize mode).
    private var selectedKey: String?
    private var selectionOverlay: SKNode?

    private var isPlaying = false
    /// Keeps the broader play movement band active briefly after play ends so
    /// the cat can visibly walk back to recovery targets instead of snapping.
    private var isPostPlayRecovering = false
    private var activePlayToyID: String?
    /// Catnip toy only: each successful bat nudges chase speed up a bit so the
    /// cat feels progressively more "hyped" while playing.
    private var catnipHitCount = 0
    private let catnipToyID = "toy_catnip_pouch"
    private let catnipSpeedStep: CGFloat = 0.06
    private let catnipMaxExtraSpeed: CGFloat = 0.9
    private var playToyNode: SKNode?
    private var playToyIsStatic = false
    private let staticPlayToyIDs: Set<String> = ["toy_play_tunnel", "toy_cardboard_box"]
    private let plantPropKeys: Set<String> = ["furniture_small_plant", "furniture_big_plant"]
    /// Keep dragged toys away from hard side edges so the cat can always reach.
    private let playToySideInsetNormalized: CGFloat = 0.14
    private enum CardboardBoxVisualState {
        case closed, peek
    }
    private enum CardboardBoxCatState {
        case approachBox, hiddenInBox, staringAtBox, wanderingAway, returningToBox
    }
    private var cardboardBoxVisualState: CardboardBoxVisualState = .closed
    private var cardboardBoxCatState: CardboardBoxCatState = .approachBox
    private var cardboardBoxStateDeadline: TimeInterval = 0
    private var cardboardBoxWanderTarget: CGPoint?
    private var isTrickMode = false
    /// The treat the player is dragging / has dropped during trick training.
    private var snackNode: SKNode?
    /// True from the moment a snack is dropped until the cat finishes eating it,
    /// so a second drop can't interrupt the eat sequence.
    private var isSnackBeingEaten = false
    private var laserDot: SKShapeNode?
    private var lastToyBatAt: TimeInterval = 0
    private let toiletPaperBatInterval: TimeInterval = 30
    private var nextToiletPaperBatAt: TimeInterval?
    private var isToiletPaperBatInProgress = false
    private var lastUpdateTime: TimeInterval = 0
    /// Sprites face right by default; true when mirrored to face left.
    private var facesLeft = false
    private var isLaserEngaged = false
    private var playEngagementSeconds: TimeInterval = 0
    private var playDurationMetFired = false
    private enum NeedThoughtKind {
        case none, food, water
    }
    private var needThoughtKind: NeedThoughtKind = .none
    private var needThoughtBubbleNode: SKNode?
    /// Water bowl fill 0–100 (mirrors pet thirst); at 0 the cat shows confused at the bowl.
    private var waterBowlLevel: Int = 100
    /// True while `goToBowl` is holding an eat/drink/confused pose at a bowl.
    private var isHoldingBowlInteraction = false

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
        view.allowsTransparency = true
        removeAllChildren()
        if isGardenBackdrop {
            buildCat()
            startAnimation(.idle)
            let stagger = Double(gardenSpawnIndex) * 0.65 + Double.random(in: 0...0.4)
            runBehaviorAction(.wait(forDuration: stagger)) { [weak self] in
                self?.runBehavior()
            }
        } else {
            setupRoomCamera()
            buildRoom()
            buildCat()
            playWelcomeSequence()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard let cam = roomCamera, !isInspectingPictureFrame, !isPictureFrameInspectAnimating else { return }
        cam.position = defaultCameraPosition()
    }

    // MARK: Room

    func applyRoomLayout(_ layout: PetRoomLayoutState, frameImage: UIImage?) {
        layoutState = layout
        pictureFrameImage = frameImage
        rebuildRoomDecor()
    }

    func setLitterBoxDirty(_ dirty: Bool) {
        guard isLitterBoxDirty != dirty else { return }
        isLitterBoxDirty = dirty
        updateLitterBoxAppearance()
    }

    func setToiletPaperMessVisible(_ visible: Bool) {
        guard isToiletPaperMessVisible != visible else { return }
        isToiletPaperMessVisible = visible
        if !visible {
            nextToiletPaperBatAt = nil
            isToiletPaperBatInProgress = false
            toiletPaperMessStableAnchor = nil
        }
        rebuildRoomDecor()
    }

    /// Updates which need-thought bubble (if any) should appear above the cat.
    /// Food takes priority when both are low.
    func setNeedThoughts(showFood: Bool, showWater: Bool) {
        let next: NeedThoughtKind
        if showFood {
            next = .food
        } else if showWater {
            next = .water
        } else {
            next = .none
        }
        guard next != needThoughtKind else { return }
        needThoughtKind = next
        rebuildNeedThoughtBubble()
    }

    /// Syncs bowl fill from the care economy so drink visits can show confused at 0%.
    func setWaterBowlLevel(_ level: Int) {
        waterBowlLevel = min(100, max(0, level))
    }

    /// Scene-space frame for the litter box sprite, used by SwiftUI overlay
    /// interactions (e.g. drag-to-clean mini game hit-testing).
    func litterBoxFrameInScene() -> CGRect? {
        litterBoxSprite?.calculateAccumulatedFrame()
    }

    /// Scene-space frame for the food bowl sprite, used by SwiftUI overlay
    /// interactions (e.g. drag-to-refill mini game hit-testing).
    func foodBowlFrameInScene() -> CGRect? {
        propNodes[.foodBowl]?.calculateAccumulatedFrame()
    }

    /// Scene-space frame for a plant sprite, used by the watering mini-game's
    /// drag-over hit-testing.
    func plantFrameInScene(for prop: RoomProp) -> CGRect? {
        propNodes[prop]?.calculateAccumulatedFrame()
    }

    /// Quick water-splash + bounce delight when a plant finishes being watered.
    func playPlantWaterReaction(for prop: RoomProp) {
        guard let node = propNodes[prop] else { return }
        node.removeAction(forKey: "plantWater")
        let baseX = node.xScale
        let baseY = node.yScale
        let baseRotation = node.zRotation
        let popScale: CGFloat = 1.045
        let wobble: CGFloat = 0.07

        let reaction = SKAction.sequence([
            .group([
                .scaleX(to: baseX * popScale, duration: 0.10),
                .scaleY(to: baseY * popScale, duration: 0.10)
            ]),
            .group([
                .rotate(toAngle: baseRotation + wobble, duration: 0.09, shortestUnitArc: true),
                .scaleX(to: baseX, duration: 0.09),
                .scaleY(to: baseY, duration: 0.09)
            ]),
            .rotate(toAngle: baseRotation - wobble * 0.65, duration: 0.10, shortestUnitArc: true),
            .rotate(toAngle: baseRotation, duration: 0.11, shortestUnitArc: true)
        ])
        node.run(reaction, withKey: "plantWater")

        let frame = node.calculateAccumulatedFrame()
        for _ in 0..<6 {
            let drop = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...4.5))
            drop.fillColor = SKColor(red: 0.40, green: 0.72, blue: 0.95, alpha: 0.9)
            drop.strokeColor = .clear
            drop.zPosition = node.zPosition + 1
            drop.position = CGPoint(
                x: frame.midX + CGFloat.random(in: -frame.width * 0.25...frame.width * 0.25),
                y: frame.maxY - CGFloat.random(in: 0...frame.height * 0.2)
            )
            addChild(drop)
            let fall = SKAction.moveBy(x: 0, y: -CGFloat.random(in: 24...44), duration: 0.6)
            drop.run(.sequence([
                .group([fall, .fadeOut(withDuration: 0.6)]),
                .removeFromParent()
            ]))
        }
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
        clearOccupiedBedState(showCat: true)
        clearSelection()
        wallWashNode?.removeFromParent()
        pictureFrameNode?.removeFromParent()
        draggableNodes.values.forEach { $0.removeFromParent() }
        draggableNodes.removeAll()
        // Built-in care props (food/water/litter) aren't draggable, so they live
        // only in `propNodes`. Remove them from the scene too, or each rebuild
        // (e.g. equipping a different litter box) stacks a new one on the old.
        propNodes.values.forEach { $0.removeFromParent() }
        propNodes.removeAll()

        applyWallWash()
        buildPictureFrame()

        placeBuiltInProps()
        placeOwnedFurniture()
        placeToiletPaperMess()
        updateFloorPropLayering()
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
        guard let frameID = PetShopCatalog.activePictureFrameID(in: layoutState),
              layoutState.owns(frameID),
              !layoutState.isStashed(frameID),
              let item = PetShopCatalog.item(id: frameID) else { return }

        let container = SKNode()
        let defaultPoint = NormalizedPoint(x: 0.72, y: 0.62)
        let normalized = clampNormalizedToWall(
            layoutState.propPositions[frameID] ?? defaultPoint
        )
        let center = scenePoint(from: normalized)
        container.position = center
        container.zPosition = isCustomizeMode ? pictureFrameCustomizeZ : pictureFrameZ

        let catalogSize = item.defaultSize
        let frameSize = CGSize(
            width: catalogSize.width * pictureFrameWallScale,
            height: catalogSize.height * pictureFrameWallScale
        )

        if let pictureFrameImage {
            let displayPhoto = pictureFrameImage.normalizedForSpriteKit()
            let placement = PetShopCatalog.pictureFramePhotoPlacement(
                frameSize: frameSize,
                photo: displayPhoto,
                frameImageName: item.imageName
            )
            let tex = SKTexture(image: displayPhoto)
            let photo = SKSpriteNode(texture: tex)
            photo.size = placement.size
            photo.position = placement.position
            photo.zPosition = 0
            container.addChild(photo)
        }

        if let frameUIImage = PetShopCatalog.frameArtImage(forItemID: frameID) {
            let frameTex = SKTexture(image: frameUIImage)
            let frameSprite = SKSpriteNode(texture: frameTex)
            frameSprite.size = frameSize
            frameSprite.zPosition = 1
            container.addChild(frameSprite)
        }

        addChild(container)
        pictureFrameNode = container
        draggableNodes[frameID] = container
        applyFlip(to: container, key: frameID)
        if layoutState.propPositions[frameID] == nil {
            var positions = layoutState.propPositions
            positions[frameID] = normalized
            layoutState.propPositions = positions
        }
        if isCustomizeMode { highlightDraggable(container) }
    }

    private func placeBuiltInProps() {
        let sharedDepthHeight: CGFloat = 120
        installEquippedProp(
            key: PetRoomPropKey.catTree,
            slot: .catTree,
            roomProp: nil,
            defaultPoint: NormalizedPoint(x: 0.84, y: 0.30),
            pixelOffset: CGPoint(x: 0, y: -15),
            depthHeight: sharedDepthHeight
        )
        installEquippedProp(
            key: PetRoomPropKey.foodBowl,
            slot: .foodBowl,
            roomProp: .foodBowl,
            defaultPoint: NormalizedPoint(x: 0.18, y: 0.22),
            pixelOffset: CGPoint(x: -14, y: 0),
            depthHeight: sharedDepthHeight,
            draggableInCustomize: false
        )
        installEquippedProp(
            key: PetRoomPropKey.waterBowl,
            slot: .waterBowl,
            roomProp: .waterBowl,
            defaultPoint: NormalizedPoint(x: 0.34, y: 0.21),
            pixelOffset: waterBowlPixelOffset(
                for: layoutState.equippedItemID(for: .waterBowl)
            ),
            depthHeight: sharedDepthHeight,
            draggableInCustomize: false
        )
        installEquippedProp(
            key: PetRoomPropKey.litterBox,
            slot: .litterBox,
            roomProp: .litterBox,
            defaultPoint: NormalizedPoint(x: 0.93, y: 0.12),
            pixelOffset: litterBoxPixelOffset(
                for: layoutState.equippedItemID(for: .litterBox)
            ),
            depthHeight: sharedDepthHeight,
            // Litter box can be moved and flipped in customize; only the food and
            // water bowls stay locked in their fixed positions.
            draggableInCustomize: true
        )
    }

    /// Vertical nudge so alternate water bowl art sits on the same floor line as the food bowl.
    private func waterBowlPixelOffset(for equippedItemID: String?) -> CGPoint {
        let x: CGFloat = -14
        switch equippedItemID {
        case "bowl_water_classic", nil:
            return CGPoint(x: x, y: 0)
        case "bowl_water_sky", "bowl_water_flower":
            return CGPoint(x: x, y: -2)
        case "bowl_water_luxe":
            return CGPoint(x: x, y: -5)
        default:
            return CGPoint(x: x, y: -3)
        }
    }

    /// Horizontal nudge so each litter variant lines up on the floor (art anchors differ).
    private func litterBoxPixelOffset(for equippedItemID: String?) -> CGPoint {
        switch equippedItemID {
        case "litter_auto":
            return CGPoint(x: 40, y: 0)
        case "litter_steel", "litter_classic":
            return CGPoint(x: 30, y: 0)
        case nil:
            // Starter classic when nothing is explicitly equipped.
            return CGPoint(x: 30, y: 0)
        default:
            return .zero
        }
    }

    private func installEquippedProp(
        key: String,
        slot: PetEquipSlot,
        roomProp: RoomProp?,
        defaultPoint: NormalizedPoint,
        pixelOffset: CGPoint = .zero,
        depthHeight: CGFloat? = nil,
        draggableInCustomize: Bool = true
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
            draggableInCustomize: draggableInCustomize,
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
        let sharedDepthHeight: CGFloat = 120
        // One décor piece per category: even if several are owned (e.g. after the
        // unlock-all cheat or legacy saves), only the single active item in each
        // category is placed so beds/plants never stack on top of each other.
        let activeFloorIDs = Set(
            PetShopCategory.allCases.compactMap {
                layoutState.activeItem(among: PetShopCatalog.floorItemIDs(in: $0))
            }
        )
        for item in PetShopCatalog.all where item.isFloorItem {
            guard activeFloorIDs.contains(item.id) else { continue }
            let key = item.id
            let defaultPoint: NormalizedPoint
            let depthHeight: CGFloat
            var roomProp: RoomProp? = nil
            switch key {
            case PetRoomPropKey.couch:
                defaultPoint = NormalizedPoint(x: 0.56, y: 0.19)
                depthHeight = sharedDepthHeight
            case "furniture_cat_bed_1", "furniture_cat_bed_2", "furniture_cat_bed_3", PetRoomPropKey.catBed:
                defaultPoint = NormalizedPoint(x: 0.44, y: 0.20)
                // Beds should obey the same "can’t drag too far up" feel as the cat tree.
                depthHeight = sharedDepthHeight
            case PetRoomPropKey.yarnBall:
                defaultPoint = NormalizedPoint(x: 0.70, y: 0.23)
                depthHeight = sharedDepthHeight
            case "furniture_small_plant":
                defaultPoint = NormalizedPoint(x: 0.30, y: 0.20)
                // Cap by true height so the whole plant stays under the floor seam.
                depthHeight = item.defaultSize.height
                roomProp = .smallPlant
            case "furniture_big_plant":
                defaultPoint = NormalizedPoint(x: 0.72, y: 0.20)
                depthHeight = item.defaultSize.height
                roomProp = .bigPlant
            default:
                defaultPoint = NormalizedPoint(x: 0.5, y: 0.2)
                depthHeight = sharedDepthHeight
            }
            installProp(
                key: key,
                imageName: item.imageName ?? "",
                caption: item.placeholderCaption,
                roomProp: roomProp,
                defaultPoint: defaultPoint,
                placeholderSize: item.defaultSize,
                draggableInCustomize: true,
                depthHeight: depthHeight
            )
        }
    }

    private func placeToiletPaperMess() {
        toiletPaperMessNode?.removeFromParent()
        toiletPaperMessNode = nil
        propNodes.removeValue(forKey: .toiletPaperMess)
        guard isToiletPaperMessVisible else { return }

        let node = makeToiletPaperMessNode()
        let anchor: CGPoint
        if let stableAnchor = toiletPaperMessStableAnchor {
            anchor = stableAnchor
        } else {
            guard let generatedAnchor = toiletPaperMessAnchor(for: node) else { return }
            anchor = generatedAnchor
            toiletPaperMessStableAnchor = generatedAnchor
        }
        if let sprite = node as? SKSpriteNode {
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.position = anchor
            sprite.zPosition = 6
        } else {
            let h = node.calculateAccumulatedFrame().height
            node.position = CGPoint(x: anchor.x, y: anchor.y + h / 2)
            node.zPosition = 6
        }
        addChild(node)
        toiletPaperMessNode = node
        propNodes[.toiletPaperMess] = node
        if nextToiletPaperBatAt == nil {
            nextToiletPaperBatAt = (lastUpdateTime > 0 ? lastUpdateTime : 0) + toiletPaperBatInterval
        }
    }

    private func makeToiletPaperMessNode() -> SKNode {
        if let image = UIImage(named: Self.toiletPaperAssetName) {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.size = sprite.size.scaledToHeight(88)
            return sprite
        }

        let fallback = SKLabelNode(text: "🧻")
        fallback.fontSize = 54
        fallback.verticalAlignmentMode = .center
        let container = SKNode()
        container.addChild(fallback)
        return container
    }

    private func toiletPaperMessAnchor(for node: SKNode) -> CGPoint? {
        let y = size.height * (floorBand.lowerBound + 0.02)
        let candidates: [CGPoint] = [
            CGPoint(x: size.width * 0.12, y: y),
            CGPoint(x: size.width * 0.26, y: y),
            CGPoint(x: size.width * 0.50, y: y),
            CGPoint(x: size.width * 0.72, y: y),
            CGPoint(x: size.width * 0.86, y: y)
        ].shuffled()

        // Avoid both the built-in care props and every movable floor prop
        // (beds, couch, cat tree, plants) so the mess never lands on top of them.
        var obstacles: [SKNode] = propNodes
            .filter { $0.key != .toiletPaperMess }
            .map { $0.value }
        for (key, node) in draggableNodes where !isPictureFrame(key) {
            if !obstacles.contains(where: { $0 === node }) { obstacles.append(node) }
        }

        for candidate in candidates {
            let frame = candidateMessFrame(for: node, anchor: candidate)
            let overlaps = obstacles.contains {
                frame.intersects($0.calculateAccumulatedFrame().insetBy(dx: -10, dy: -8))
            }
            if !overlaps { return candidate }
        }
        return candidates.first
    }

    private func candidateMessFrame(for node: SKNode, anchor: CGPoint) -> CGRect {
        let size = node.calculateAccumulatedFrame().size
        if node is SKSpriteNode {
            return CGRect(x: anchor.x - size.width / 2, y: anchor.y, width: size.width, height: size.height)
        }
        return CGRect(x: anchor.x - size.width / 2, y: anchor.y - size.height / 2, width: size.width, height: size.height)
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
        let node = makePropNode(
            key: key,
            imageName: imageName,
            caption: caption,
            placeholderSize: placeholderSize,
            point: point,
            roomProp: roomProp,
            draggableInCustomize: draggableInCustomize
        )
        addChild(node)
        applyDepthTransform(
            to: node,
            key: key,
            baseAnchor: clampPropAnchor(point, key: key, naturalHeight: naturalHeight),
            naturalHeight: naturalHeight
        )
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
        key: String,
        imageName: String,
        caption: String,
        placeholderSize: CGSize,
        point: CGPoint,
        roomProp: RoomProp?,
        draggableInCustomize: Bool
    ) -> SKNode {
        if key == PetRoomPropKey.litterBox {
            let litterSprite = makeLitterBoxSprite(
                fallbackImageName: imageName,
                placeholderSize: placeholderSize,
                point: point,
                roomProp: roomProp,
                draggableInCustomize: draggableInCustomize
            )
            litterBoxSprite = litterSprite
            updateLitterBoxAppearance()
            return litterSprite
        }
        if !imageName.isEmpty, let sprite = loadImage(imageName) {
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.position = point
            if sprite.size.height > 0 {
                sprite.size = sprite.size.scaledToHeight(placeholderSize.height)
            }
            if roomProp != nil {
                sprite.zPosition = propDepthZ(for: point.y)
            } else {
                sprite.zPosition = 0
            }
            if isCustomizeMode, draggableInCustomize { highlightDraggable(sprite) }
            return sprite
        }

        let rect = SKShapeNode(rectOf: placeholderSize, cornerRadius: 12)
        rect.fillColor = SKColor(red: 0.90, green: 0.62, blue: 0.66, alpha: 0.55)
        rect.strokeColor = SKColor(red: 0.88, green: 0.22, blue: 0.38, alpha: 0.6)
        rect.lineWidth = 2
        rect.position = CGPoint(x: point.x, y: point.y + placeholderSize.height / 2)
        rect.zPosition = roomProp == nil ? 0 : propDepthZ(for: point.y)
        let label = SKLabelNode(text: caption)
        label.fontName = "HelveticaNeue-Medium"
        label.fontSize = 14
        label.fontColor = SKColor(red: 0.55, green: 0.15, blue: 0.27, alpha: 1)
        label.verticalAlignmentMode = .center
        rect.addChild(label)
        if isCustomizeMode, draggableInCustomize { highlightDraggable(rect) }
        return rect
    }

    private func makeLitterBoxSprite(
        fallbackImageName: String,
        placeholderSize: CGSize,
        point: CGPoint,
        roomProp: RoomProp?,
        draggableInCustomize: Bool
    ) -> SKSpriteNode {
        let texture = litterBoxTexture(for: isLitterBoxDirty ? .dirty : .clean)
            ?? SKTexture(image: UIImage(named: fallbackImageName) ?? UIImage())
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = point
        if sprite.size.height > 0 {
            sprite.size = sprite.size.scaledToHeight(placeholderSize.height)
        }
        sprite.zPosition = roomProp == nil ? 0 : propDepthZ(for: point.y)
        if isCustomizeMode, draggableInCustomize { highlightDraggable(sprite) }
        return sprite
    }

    private func updateLitterBoxAppearance() {
        guard let sprite = litterBoxSprite else { return }
        sprite.removeAction(forKey: "litterUse")
        let frame: LitterBoxFrame = isLitterBoxDirty ? .dirty : .clean
        guard let texture = litterBoxTexture(for: frame) else { return }
        sprite.texture = texture
    }

    /// Alternates the cat's two "using" frames for ~10 seconds, then settles on
    /// the dirty frame (or back to clean for the self-cleaning auto box).
    func playLitterBoxUseAnimation(for skin: CatSkin) {
        guard let sprite = litterBoxSprite else { return }
        let usingFrames: (LitterBoxFrame, LitterBoxFrame) =
            (skin == .calico) ? (.calicoUseA, .calicoUseB) : (.cowUseA, .cowUseB)
        guard let textureA = litterBoxTexture(for: usingFrames.0),
              let textureB = litterBoxTexture(for: usingFrames.1) else {
            return
        }
        let auto = isAutoLitterEquipped
        let endFrame: LitterBoxFrame = auto ? .clean : .dirty
        guard let endTexture = litterBoxTexture(for: endFrame) else { return }

        sprite.removeAction(forKey: "litterUse")
        // ~10s total: each A/B cycle is 1s, repeated 10 times.
        let cycle = SKAction.sequence([
            .setTexture(textureA), .wait(forDuration: 0.5),
            .setTexture(textureB), .wait(forDuration: 0.5)
        ])
        let loop = SKAction.repeat(cycle, count: 10)
        let finish = SKAction.run { [weak self, weak sprite] in
            guard let self, let sprite else { return }
            self.isLitterBoxDirty = !auto
            sprite.texture = endTexture
        }
        sprite.run(.sequence([loop, finish]), withKey: "litterUse")
    }

    private func litterBoxTexture(for frame: LitterBoxFrame) -> SKTexture? {
        guard let sheet = currentLitterSheetTexture() else { return nil }
        let width = 1.0 / CGFloat(Self.litterBoxFrameCount)
        let rect = CGRect(
            x: CGFloat(frame.rawValue) * width,
            y: 0,
            width: width,
            height: 1.0
        )
        return SKTexture(rect: rect, in: sheet)
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
        PetShopCatalog.item(id: key)?.isPictureFrame == true
    }

    private func pictureFrameHit(at location: CGPoint) -> Bool {
        guard let pictureFrameNode else { return false }
        return pictureFrameNode.calculateAccumulatedFrame()
            .insetBy(dx: -10, dy: -10)
            .contains(location)
    }

    private func setPictureFrameInspectAnimating(_ animating: Bool) {
        guard isPictureFrameInspectAnimating != animating else { return }
        isPictureFrameInspectAnimating = animating
        onPictureFrameInspectAnimatingChanged?(animating)
    }

    private func handlePictureFrameInspectTouch(at location: CGPoint) {
        guard isInspectingPictureFrame, !isPictureFrameInspectAnimating else { return }
        if pictureFrameHit(at: location) {
            onTapPictureFrameWhileInspecting?()
        } else {
            exitPictureFrameInspect()
        }
    }

    private func setupRoomCamera() {
        let cam = SKCameraNode()
        cam.position = defaultCameraPosition()
        addChild(cam)
        camera = cam
        roomCamera = cam
    }

    private func defaultCameraPosition() -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// Camera scale for inspect mode. SpriteKit scales below 1 zoom in; above 1 zoom out.
    private func pictureFrameInspectCameraScale(for frameRect: CGRect) -> CGFloat {
        let scaleForWidth = max(frameRect.width, 1) / (size.width * pictureFrameInspectZoomFraction)
        let scaleForHeight = max(frameRect.height, 1) / (size.height * pictureFrameInspectZoomFraction)
        // Pick the larger scale so the full frame fits, then clamp to a sensible zoom range.
        return min(max(max(scaleForWidth, scaleForHeight), 0.12), 1.0)
    }

    /// Pans and zooms the room camera toward the wall frame, like walking up for a closer look.
    func enterPictureFrameInspect() {
        guard !isCustomizeMode,
              !isInspectingPictureFrame,
              !isPictureFrameInspectAnimating,
              let frameNode = pictureFrameNode,
              let cam = roomCamera else { return }

        setPictureFrameInspectAnimating(true)
        isInspectingPictureFrame = true
        onPictureFrameInspectChanged?(true)
        stopMovement()
        cat.removeAction(forKey: "behavior")
        startAnimation(.idle)
        isInteracting = true

        let frameRect = frameNode.calculateAccumulatedFrame()
        let targetCenter = CGPoint(x: frameRect.midX, y: frameRect.midY)
        let targetScale = pictureFrameInspectCameraScale(for: frameRect)

        let move = SKAction.move(to: targetCenter, duration: pictureFrameInspectDuration)
        let zoom = SKAction.scale(to: targetScale, duration: pictureFrameInspectDuration)
        move.timingMode = .easeInEaseOut
        zoom.timingMode = .easeInEaseOut

        cam.removeAction(forKey: "pictureFrameInspect")
        let finish = SKAction.run { [weak self] in
            self?.setPictureFrameInspectAnimating(false)
        }
        cam.run(.sequence([.group([move, zoom]), finish]), withKey: "pictureFrameInspect")
    }

    /// Re-frames the camera on the wall picture after the photo inside the frame changes.
    func refreshPictureFrameInspect() {
        guard isInspectingPictureFrame,
              !isCustomizeMode,
              let frameNode = pictureFrameNode,
              let cam = roomCamera else { return }

        let frameRect = frameNode.calculateAccumulatedFrame()
        let targetCenter = CGPoint(x: frameRect.midX, y: frameRect.midY)
        let targetScale = pictureFrameInspectCameraScale(for: frameRect)
        let duration = pictureFrameInspectDuration * 0.45

        setPictureFrameInspectAnimating(true)
        let move = SKAction.move(to: targetCenter, duration: duration)
        let zoom = SKAction.scale(to: targetScale, duration: duration)
        move.timingMode = .easeInEaseOut
        zoom.timingMode = .easeInEaseOut

        cam.removeAction(forKey: "pictureFrameInspect")
        let finish = SKAction.run { [weak self] in
            self?.setPictureFrameInspectAnimating(false)
        }
        cam.run(.sequence([.group([move, zoom]), finish]), withKey: "pictureFrameInspect")
    }

    /// Returns the camera to the default room view.
    func exitPictureFrameInspect() {
        guard isInspectingPictureFrame || isPictureFrameInspectAnimating,
              let cam = roomCamera else { return }

        setPictureFrameInspectAnimating(true)
        isInspectingPictureFrame = false
        onPictureFrameInspectChanged?(false)

        let home = defaultCameraPosition()
        let move = SKAction.move(to: home, duration: pictureFrameInspectDuration * 0.82)
        let zoom = SKAction.scale(to: 1, duration: pictureFrameInspectDuration * 0.82)
        move.timingMode = .easeInEaseOut
        zoom.timingMode = .easeInEaseOut

        cam.removeAction(forKey: "pictureFrameInspect")
        let finish = SKAction.run { [weak self] in
            guard let self else { return }
            self.setPictureFrameInspectAnimating(false)
            self.isInteracting = false
            self.runBehavior()
        }
        cam.run(.sequence([.group([move, zoom]), finish]), withKey: "pictureFrameInspect")
    }

    private func resetPictureFrameInspectImmediately() {
        guard let cam = roomCamera else { return }
        cam.removeAction(forKey: "pictureFrameInspect")
        cam.position = defaultCameraPosition()
        cam.setScale(1)
        let wasActive = isInspectingPictureFrame || isPictureFrameInspectAnimating
        setPictureFrameInspectAnimating(false)
        isInspectingPictureFrame = false
        guard wasActive else { return }
        onPictureFrameInspectChanged?(false)
        isInteracting = false
        runBehavior()
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
    private func clampPropAnchor(_ point: CGPoint, key: String, naturalHeight: CGFloat) -> CGPoint {
        let floorBottom = size.height * propFrontBound
        let seam = size.height * floorBand.upperBound
        // Floor-bound props are held back by their own height so their top stays
        // under the seam. Tall props lean on the wall, so they use a small
        // reference height and get the same deep range as the bowls.
        let referenceHeight = naturalHeight <= depthTallPropThreshold ? naturalHeight : depthWallLeanReference
        var backLimit = seam - depthMinScale * referenceHeight
        if key == "furniture_small_plant" || key == "furniture_big_plant" {
            // Give plants a little more upward travel so they can sit behind
            // nearby furniture (like beds) while still staying on the floor band.
            backLimit += 36
        }
        return CGPoint(
            x: min(
                max(point.x, size.width * (plantPropKeys.contains(key) ? 0.03 : 0.06)),
                size.width * (plantPropKeys.contains(key) ? 0.97 : 0.94)
            ),
            y: min(max(point.y, floorBottom), max(backLimit, floorBottom))
        )
    }

    /// Raw perspective scale for anything standing on the floor at `baseY`: full
    /// size at the front of the band, shrinking toward the back. Shared by props
    /// and the cat so they recede together.
    private func depthPerspectiveScale(baseY: CGFloat, backScale: CGFloat) -> CGFloat {
        let band = perspectiveFloorBand
        let floorBottom = size.height * band.lowerBound
        let seam = size.height * band.upperBound
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

    private func depthScale(baseY: CGFloat, key: String, naturalHeight: CGFloat) -> CGFloat {
        var perspective = propPerspectiveScale(baseY: baseY)
        if key == "furniture_big_plant" {
            // Keep the big plant from shrinking too aggressively in deep/back positions.
            perspective = max(perspective, 0.70)
        }
        // Tall props lean on the wall: scale by perspective only, no seam cap.
        guard naturalHeight <= depthTallPropThreshold else { return perspective }
        let seam = size.height * floorBand.upperBound
        let fitCap = naturalHeight > 0 ? (seam - baseY) / naturalHeight : perspective
        return max(min(perspective, fitCap), depthMinScale)
    }

    /// Scales a prop for depth and pins its base (feet) to `baseAnchor`, so it
    /// grows upward from the floor rather than around its center.
    private func applyDepthTransform(to node: SKNode, key: String, baseAnchor: CGPoint, naturalHeight: CGFloat) {
        node.setScale(depthScale(baseY: baseAnchor.y, key: key, naturalHeight: naturalHeight))
        setPropFloorAnchor(node, to: baseAnchor)
    }

    /// Draw order for floor props using the same depth direction as perspective:
    /// lower (closer) Y draws in front of higher (deeper) Y.
    private func propDepthZ(for baseY: CGFloat) -> CGFloat {
        let frontEdge = size.height * propFrontBound
        let backEdge = size.height * perspectiveFloorBand.upperBound
        let span = max(backEdge - frontEdge, 1)
        let t = min(max((baseY - frontEdge) / span, 0), 1) // 0 front ... 1 back
        return propDepthFrontZ + (propDepthBackZ - propDepthFrontZ) * t
    }

    /// Cat draw order on the floor — same curve as `propDepthZ` so the cat
    /// naturally renders in front of props closer to the camera and behind
    /// props farther up the room.
    private func catFloorDepthZ(for baseY: CGFloat) -> CGFloat {
        propDepthZ(for: baseY)
    }

    /// Keeps all floor props (care props + movable furniture + toilet paper mess)
    /// depth-sorted against each other so dragged props can overlap bowls/litter
    /// correctly when placed closer to camera.
    private func updateFloorPropLayering() {
        var floorNodes: [SKNode] = []
        for node in propNodes.values where !floorNodes.contains(where: { $0 === node }) {
            floorNodes.append(node)
        }
        for (key, node) in draggableNodes
        where !isPictureFrame(key) && !floorNodes.contains(where: { $0 === node }) {
            floorNodes.append(node)
        }

        let draggingNode: SKNode? = {
            guard isActivelyDragging, let draggingKey else { return nil }
            return draggableNodes[draggingKey]
        }()

        let catTreeNode = draggableNodes[PetRoomPropKey.catTree]
        for node in floorNodes where node !== draggingNode {
            if node === toiletPaperMessNode {
                // Always sits in front of the litter box and food/water bowls.
                node.zPosition = toiletPaperZ
            } else {
                let baseY = propFloorAnchor(for: node).y
                // Tall props like the cat tree feel better when the switch is tied
                // to the tree's "mid" instead of its base/feet.
                if let catTreeNode, node === catTreeNode {
                    node.zPosition = propDepthZ(for: baseY + catTreeZMidpointLift)
                } else {
                    node.zPosition = propDepthZ(for: baseY)
                }
            }
        }
    }

    // MARK: Cat

    private func buildCat() {
        addChild(cat)

        cat.addChild(catFacing)
        catVisual.anchorPoint = CGPoint(x: 0.5, y: 0) // feet at the node origin
        catFacing.addChild(catVisual)

        if let frame = frames(for: .idle).first {
            applyCatFrame(frame)
            currentAction = .idle
        }
        let spawnX: CGFloat
        if isGardenBackdrop, gardenSpawnCount > 1 {
            let margin = maxCatHorizontalHalfWidth
            let usable = max(1, size.width - margin * 2)
            let slot = CGFloat(gardenSpawnIndex + 1) / CGFloat(gardenSpawnCount + 1)
            spawnX = margin + usable * slot
        } else {
            spawnX = size.width * 0.5
        }
        cat.position = clampCatPosition(CGPoint(x: spawnX, y: randomFloorY()))
        cat.zPosition = catFloorDepthZ(for: cat.position.y)
    }

    private func preloadFrameDisplaySizes() {
        for name in atlas.textureNames {
            let texture = atlas.textureNamed(name)
            frameDisplaySizes[name] = Self.displaySize(for: texture, targetHeight: catDisplayHeight)
        }
    }

    /// Sets the cat sprite frame and resizes from that frame's pixel aspect ratio.
    private func applyCatFrame(_ frame: CatFrame) {
        catVisual.anchorPoint = CGPoint(x: 0.5, y: 0)
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
        case wander, sit, groom, sleep, play, eat, drink, peekLitter
    }

    /// The previous activity, so we avoid repeating it back-to-back and the
    /// routine doesn't fall into an obvious loop.
    private var lastBehavior: AmbientBehavior?
    /// Wander hops taken in a row, so a stroll can chain a few steps but never
    /// wanders forever before doing something else.
    private var wanderStreak = 0

    private func runBehavior() {
        guard !isInteracting, !isHoldingPose, !isTrickMode, !isCarryingCat else { return }
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
        case .peekLitter: ambientPeekLitterBox()
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
        // The garden backdrop has no care props at all.
        if !isGardenBackdrop, !isCustomizeMode {
            if propNodes[.foodBowl] != nil { weights[.eat] = 8 }
            if propNodes[.waterBowl] != nil { weights[.drink] = 8 }
            if propNodes[.litterBox] != nil { weights[.peekLitter] = 5 }
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

    /// Curls up for a long nap. When a purchased bed is in the room, the cat
    /// walks to it and uses the occupied bed art (composite per skin). Quick naps
    /// elsewhere use `idleFor(state: .sleep, …)` directly. Petting (`petCat`)
    /// cancels this and wakes the cat early.
    private func sleep() {
        if isGardenBackdrop {
            idleFor(state: .sleep, duration: Double.random(in: 8...16))
        } else if let bed = nearestPlacedCatBed() {
            goToBedAndSleep(bedKey: bed.key, bed: bed.node, duration: 30)
        } else {
            idleFor(state: .sleep, duration: 30)
        }
    }

    private func nearestPlacedCatBed() -> (key: String, node: SKNode)? {
        let beds = Self.catBedItemIDs.compactMap { key -> (String, SKNode)? in
            guard layoutState.owns(key),
                  !layoutState.isStashed(key),
                  let node = draggableNodes[key] else { return nil }
            return (key, node)
        }
        guard !beds.isEmpty else { return nil }
        return beds.min { lhs, rhs in
            let la = propFloorAnchor(for: lhs.1)
            let ra = propFloorAnchor(for: rhs.1)
            let ld = hypot(la.x - cat.position.x, la.y - cat.position.y)
            let rd = hypot(ra.x - cat.position.x, ra.y - cat.position.y)
            return ld < rd
        }
    }

    private func catBedBaseImageName(for key: String) -> String? {
        PetShopCatalog.item(id: key)?.imageName
    }

    private func catBedOccupiedImageName(for key: String) -> String? {
        guard let base = catBedBaseImageName(for: key) else { return nil }
        let suffix = (skin == .calico) ? "_0" : "_1"
        let occupied = "\(base)\(suffix)"
        return UIImage(named: occupied) != nil ? occupied : nil
    }

    private func setCatBedVisualState(key: String, occupied: Bool) {
        guard let sprite = draggableNodes[key] as? SKSpriteNode else { return }
        let imageName: String?
        if occupied {
            imageName = catBedOccupiedImageName(for: key) ?? catBedBaseImageName(for: key)
        } else {
            imageName = catBedBaseImageName(for: key)
        }
        // Use the shared asset loader so the black matte is stripped — a raw
        // SKTexture(image:) here would bring the black background back when the
        // cat leaves the bed and we swap to the base art.
        guard let imageName, let texture = textureForAsset(named: imageName) else { return }
        let displayHeight = sprite.size.height
        sprite.texture = texture
        if displayHeight > 0 {
            sprite.size = sprite.size.scaledToHeight(displayHeight)
        }
    }

    private func clearOccupiedBedState(showCat: Bool) {
        let surfacingFromComposite = showCat && occupiedBedKey != nil
        if let key = occupiedBedKey {
            setCatBedVisualState(key: key, occupied: false)
        }
        occupiedBedKey = nil
        if showCat {
            cat.alpha = 1
            // Room rebuilds can surface the cat while a sleep sequence is still
            // running — drop any stale walk loop left from the approach.
            if surfacingFromComposite {
                catVisual.removeAction(forKey: "anim")
                startAnimation(.sleep)
            }
        }
    }

    /// Wakes the cat from a composite bed (occupied art hides the live sprite).
    private func wakeFromOccupiedBedIfNeeded() {
        guard let bedKey = occupiedBedKey, let bed = draggableNodes[bedKey] else { return }
        clearOccupiedBedState(showCat: true)
        cat.position = catBedWakePoint(near: bed)
        cat.zPosition = catFloorDepthZ(for: cat.position.y)
    }

    private func catBedApproachPoint(for bed: SKNode) -> CGPoint {
        let anchor = propFloorAnchor(for: bed)
        let frame = bed.calculateAccumulatedFrame()
        let margin = maxCatHorizontalHalfWidth
        let targetX = min(max(frame.midX, margin), size.width - margin)
        let targetY = min(max(anchor.y, size.height * catFloorBand.lowerBound),
                          size.height * catFloorBand.upperBound)
        return CGPoint(x: targetX, y: targetY)
    }

    private func catBedWakePoint(near bed: SKNode) -> CGPoint {
        let anchor = propFloorAnchor(for: bed)
        let frame = bed.calculateAccumulatedFrame()
        let side: CGFloat = Bool.random() ? -1 : 1
        let lateral = max(44, frame.width * 0.22)
        let x = min(max(frame.midX + lateral * side, maxCatHorizontalHalfWidth),
                    size.width - maxCatHorizontalHalfWidth)
        return clampCatPosition(CGPoint(x: x, y: anchor.y))
    }

    private func goToBedAndSleep(bedKey: String, bed: SKNode, duration: TimeInterval) {
        guard !isCustomizeMode else {
            idleFor(state: .sleep, duration: duration)
            return
        }
        stopMovement()
        isHoldingPose = true
        let target = catBedApproachPoint(for: bed)
        face(towards: target.x)
        startAnimation(.walk)
        let distance = hypot(target.x - cat.position.x, target.y - cat.position.y)
        let move = SKAction.move(to: target, duration: max(0.35, TimeInterval(distance / walkSpeed)))
        move.timingMode = .easeInEaseOut
        let arrive = SKAction.run { [weak self] in
            guard let self else { return }
            self.occupiedBedKey = bedKey
            if self.catBedOccupiedImageName(for: bedKey) != nil {
                self.cat.alpha = 0
                self.catVisual.removeAction(forKey: "anim")
                self.setCatBedVisualState(key: bedKey, occupied: true)
            } else {
                self.face(towards: propFloorAnchor(for: bed).x)
                self.startAnimation(.sleep)
            }
            self.cat.zPosition = self.catFloorDepthZ(for: self.cat.position.y)
        }
        let finish = SKAction.run { [weak self] in
            guard let self else { return }
            let wasCompositeBed = self.cat.alpha < 0.01
            self.clearOccupiedBedState(showCat: true)
            if wasCompositeBed {
                self.cat.position = self.catBedWakePoint(near: bed)
            }
            self.cat.zPosition = self.catFloorDepthZ(for: self.cat.position.y)
            self.isHoldingPose = false
            self.startAnimation(.idle)
            self.runBehavior()
        }
        cat.run(.sequence([move, arrive, .wait(forDuration: duration), finish]), withKey: "behavior")
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
        let resolvedPose = pose == .drink ? waterBowlInteractionPose() : pose
        goToBowl(bowl, pose: resolvedPose, hold: Double.random(in: 1.8...2.8)) { [weak self] in
            guard let self else { return }
            self.startAnimation(.idle)
            self.runBehavior()
        }
    }

    /// Cosmetic litter check-in: the cat occasionally walks up to the litter box
    /// and immediately steps away without using it. This is purely ambient and
    /// does not affect the timed 8AM/8PM litter-use economy events.
    private func ambientPeekLitterBox() {
        guard !isCustomizeMode, let litter = propNodes[.litterBox] else {
            runBehavior()
            return
        }

        stopMovement()
        catVisual.removeAction(forKey: "anim")
        let approach = bowlApproachPoint(for: litter, from: cat.position)
        let approachTarget = clampCatPosition(approach.target)
        face(towards: approachTarget.x)
        startAnimation(.walk)

        let approachDistance = hypot(approachTarget.x - cat.position.x, approachTarget.y - cat.position.y)
        let walkIn = SKAction.move(
            to: approachTarget,
            duration: max(0.28, TimeInterval(approachDistance / walkSpeed))
        )
        walkIn.timingMode = .easeInEaseOut

        let walkOutTarget = clampCatPosition(CGPoint(
            x: approachTarget.x + (approach.faceX >= approachTarget.x ? -1 : 1) * CGFloat.random(in: 42...72),
            y: randomFloorY()
        ))
        let walkOutDistance = hypot(walkOutTarget.x - approachTarget.x, walkOutTarget.y - approachTarget.y)
        let walkOut = SKAction.move(
            to: walkOutTarget,
            duration: max(0.28, TimeInterval(walkOutDistance / walkSpeed))
        )
        walkOut.timingMode = .easeInEaseOut

        let faceBox = SKAction.run { [weak self] in
            guard let self else { return }
            self.face(towards: approach.faceX)
        }
        let faceAway = SKAction.run { [weak self] in
            guard let self else { return }
            self.face(towards: walkOutTarget.x)
        }
        let finish = SKAction.run { [weak self] in
            guard let self else { return }
            self.cat.zPosition = self.catFloorDepthZ(for: self.cat.position.y)
            self.startAnimation(.idle)
            self.runBehavior()
        }

        cat.run(.sequence([
            walkIn,
            faceBox,
            .wait(forDuration: Double.random(in: 0.08...0.2)),
            faceAway,
            walkOut,
            finish
        ]), withKey: "behavior")
    }

    private func isCatBedKey(_ key: String) -> Bool {
        Self.catBedItemIDs.contains(key)
    }

    private func isTappableFurnitureKey(_ key: String) -> Bool {
        isCatBedKey(key) || key == PetRoomPropKey.catTree
    }

    /// True when the cat overlaps `location` and draws in front of the given furniture node.
    private func catObscuresFurnitureTap(at location: CGPoint, furnitureNode: SKNode) -> Bool {
        isCatHit(at: location) && cat.zPosition > furnitureNode.zPosition
    }

    /// Tap target for the cat bed and cat tree (draggable décor, not in `propNodes`).
    private func furnitureTapHit(at location: CGPoint) -> (key: String, node: SKNode)? {
        var topHit: (key: String, node: SKNode, z: CGFloat)?
        for (key, node) in draggableNodes {
            guard isTappableFurnitureKey(key) else { continue }
            if isCatBedKey(key) {
                guard layoutState.owns(key), !layoutState.isStashed(key) else { continue }
            }
            let hitFrame = node.calculateAccumulatedFrame().insetBy(dx: -16, dy: -16)
            guard hitFrame.contains(location) else { continue }
            if topHit == nil || node.zPosition > topHit!.z {
                topHit = (key, node, node.zPosition)
            }
        }
        if let topHit { return (topHit.key, topHit.node) }
        return nil
    }

    private func furnitureApproachPoint(for node: SKNode, key: String) -> CGPoint {
        if isCatBedKey(key) {
            return catBedApproachPoint(for: node)
        }
        let anchor = propFloorAnchor(for: node)
        let frame = node.calculateAccumulatedFrame()
        let margin = maxCatHorizontalHalfWidth
        let targetX = min(max(frame.midX, margin), size.width - margin)
        let targetY = min(max(anchor.y, size.height * catFloorBand.lowerBound),
                          size.height * catFloorBand.upperBound)
        return clampCatPosition(CGPoint(x: targetX, y: targetY))
    }

    /// User tapped the cat bed or cat tree — stroll over, sit briefly, then resume ambient life.
    private func walkToFurnitureAndSit(key: String, node: SKNode) {
        guard !isCustomizeMode, !isPlaying, !isTrickMode, !isCarryingCat else { return }

        stopMovement()
        wakeFromOccupiedBedIfNeeded()
        isInteracting = true

        let target = furnitureApproachPoint(for: node, key: key)
        face(towards: target.x)
        startAnimation(.walk)

        let distance = hypot(target.x - cat.position.x, target.y - cat.position.y)
        let move = SKAction.move(
            to: target,
            duration: max(0.35, TimeInterval(distance / walkSpeed))
        )
        move.timingMode = .easeInEaseOut

        let sitDuration = Double.random(in: 2.5...4.5)
        let faceTarget = node.calculateAccumulatedFrame().midX

        let arrive = SKAction.run { [weak self] in
            guard let self else { return }
            self.cat.zPosition = self.catFloorDepthZ(for: self.cat.position.y)
            self.face(towards: faceTarget)
            self.startAnimation(.sit)
            self.isHoldingPose = true
        }
        let finish = SKAction.run { [weak self] in
            guard let self else { return }
            self.isHoldingPose = false
            self.isInteracting = false
            self.startAnimation(.idle)
            self.runBehavior()
        }

        cat.run(.sequence([move, arrive, .wait(forDuration: sitDuration), finish]), withKey: "behavior")
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
        cat.zPosition = catFloorDepthZ(for: cat.position.y)
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

    private func updateToiletPaperAutoBat(currentTime: TimeInterval) {
        guard isToiletPaperMessVisible,
              toiletPaperMessNode != nil,
              !isCustomizeMode,
              !isPlaying,
              !isTrickMode,
              !isInteracting,
              !isHoldingPose,
              !isCarryingCat,
              !isToiletPaperBatInProgress
        else { return }

        if nextToiletPaperBatAt == nil {
            nextToiletPaperBatAt = currentTime + toiletPaperBatInterval
            return
        }
        guard let dueAt = nextToiletPaperBatAt, currentTime >= dueAt else { return }

        // Don't interrupt a currently running behavior; retry shortly.
        guard cat.action(forKey: "behavior") == nil else {
            nextToiletPaperBatAt = currentTime + 1.5
            return
        }

        beginToiletPaperBat(currentTime: currentTime)
    }

    private func beginToiletPaperBat(currentTime: TimeInterval) {
        guard let messNode = toiletPaperMessNode else {
            nextToiletPaperBatAt = currentTime + toiletPaperBatInterval
            return
        }

        let messAnchor = propFloorAnchor(for: messNode)
        let catAnchor = cat.position
        let approachInsetX: CGFloat = 26
        let direction: CGFloat = catAnchor.x < messAnchor.x ? -1 : 1
        let targetX = messAnchor.x + direction * approachInsetX
        let targetY = min(max(messAnchor.y, size.height * floorBand.lowerBound),
                          size.height * floorBand.upperBound)
        let target = clampCatPosition(CGPoint(x: targetX, y: targetY))
        let distance = hypot(target.x - catAnchor.x, target.y - catAnchor.y)
        let duration = max(0.24, TimeInterval(distance / walkSpeed))

        isToiletPaperBatInProgress = true
        stopMovement()
        face(towards: messAnchor.x)
        startAnimation(.walk)

        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        let hit = SKAction.run { [weak self] in
            guard let self else { return }
            self.face(towards: messAnchor.x)
            self.startAnimation(.pounce)
            let offset = self.pounceTowardOffset(from: self.cat.position, to: messAnchor, distance: 22)
            self.runPounceAnimation(squash: 0.88, offset: offset)
        }
        let contact = SKAction.run { [weak self] in
            guard let self else { return }
            self.nudgeToiletPaperMessOnContact()
            self.startAnimation(.idle)
            self.isToiletPaperBatInProgress = false
            self.nextToiletPaperBatAt = max(currentTime, self.lastUpdateTime) + self.toiletPaperBatInterval
            self.runBehavior()
        }
        cat.run(.sequence([move, hit, .wait(forDuration: PounceHop.hopDuration + 0.02), contact]), withKey: "behavior")
    }

    private func nudgeToiletPaperMessOnContact() {
        guard let node = toiletPaperMessNode else { return }
        let anchor = propFloorAnchor(for: node)
        let nudged = CGPoint(
            x: anchor.x + CGFloat.random(in: -40...40),
            y: anchor.y + CGFloat.random(in: -14...18)
        )
        let sideInset: CGFloat = 20
        let clamped = CGPoint(
            x: min(max(nudged.x, sideInset), max(sideInset, size.width - sideInset)),
            y: min(max(nudged.y, size.height * floorBand.lowerBound),
                   size.height * floorBand.upperBound)
        )
        toiletPaperMessStableAnchor = clamped

        if let sprite = node as? SKSpriteNode {
            sprite.run(.move(to: clamped, duration: 0.2))
        } else {
            let h = node.calculateAccumulatedFrame().height
            let center = CGPoint(x: clamped.x, y: clamped.y + h / 2)
            node.run(.move(to: center, duration: 0.2))
        }
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

    /// Stand beside a bowl; eat/drink land higher and closer so the lowered muzzle
    /// meets the bowl opening instead of dipping below the rim.
    private func bowlApproachPoint(
        for bowl: SKNode,
        from catPosition: CGPoint,
        pose: CatAction? = nil
    ) -> (target: CGPoint, faceX: CGFloat) {
        let anchor = propFloorAnchor(for: bowl)
        let frame = bowl.calculateAccumulatedFrame()
        let bowlCenterX = frame.midX
        let forEatDrink = pose == .eat || pose == .drink
        let lateralGap = forEatDrink
            ? max(bowlEatDrinkLateralGap, frame.width * 0.22)
            : max(bowlApproachLateralGap, frame.width * 0.32)
        let side: CGFloat = catPosition.x < bowlCenterX ? -1 : 1
        let margin = maxCatHorizontalHalfWidth
        let targetX = min(max(bowlCenterX + lateralGap * side, margin), size.width - margin)
        let frontInset = forEatDrink ? bowlEatDrinkFrontInset : bowlApproachFrontInset
        let frontY = anchor.y - frontInset
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

    private var pickUpAssetName: String {
        skin == .calico ? "pick_up_0" : "pick_up_1"
    }

    private func canBeginCatPickUp() -> Bool {
        !isCustomizeMode
            && !isPlaying
            && !isPostPlayRecovering
            && !isTrickMode
            && !isCarryingCat
            && currentAction != .eat
            && currentAction != .drink
            && currentAction != .confused
            && currentAction != .snack
            && currentAction != .sleep
    }

    private func isCatHit(at location: CGPoint) -> Bool {
        cat.calculateAccumulatedFrame().insetBy(dx: -24, dy: -24).contains(location)
    }

    /// Tap target for care props. Litter uses a tight zone on the tray graphic so
    /// sheet padding at the corners doesn't block taps on props behind it.
    private func propTapHitFrame(for prop: RoomProp, node: SKNode) -> CGRect {
        let frame = node.calculateAccumulatedFrame()
        guard prop == .litterBox else {
            return frame.insetBy(dx: -16, dy: -16)
        }
        let width = frame.width * 0.56
        let height = frame.height * 0.48
        return CGRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func beginCatPickUpCandidate(at location: CGPoint) {
        catPickUpCandidate = true
        catPickUpStartLocation = location
        catPickUpLastLocation = location
        catPickUpStartedAt = CACurrentMediaTime()
        catPickUpTouchOffset = CGPoint(x: cat.position.x - location.x, y: cat.position.y - location.y)
    }

    private func cancelCatPickUpCandidate() {
        catPickUpCandidate = false
    }

    private func evaluateCatPickUp(at location: CGPoint) {
        guard catPickUpCandidate, !isCarryingCat else { return }
        let moved = hypot(location.x - catPickUpStartLocation.x, location.y - catPickUpStartLocation.y)
        if moved >= dragPromoteThreshold {
            cancelCatPickUpCandidate()
            return
        }
        if CACurrentMediaTime() - catPickUpStartedAt >= catPickUpLongPressDuration {
            beginCarryingCat(at: location)
        }
    }

    private func applyPickUpPose() {
        catVisual.removeAction(forKey: "anim")
        catVisual.removeAction(forKey: "pounce")
        cat.removeAction(forKey: "pounceMove")
        guard let texture = textureForAsset(named: pickUpAssetName) else {
            startAnimation(.idle)
            return
        }
        currentAction = .idle
        currentFrameName = pickUpAssetName
        catVisual.texture = texture
        catVisual.anchorPoint = CGPoint(x: 0.5, y: 0.88)
        catVisual.size = Self.displaySize(for: texture, targetHeight: catPickUpDisplayHeight)
        collarNode?.removeFromParent()
        collarNode = nil
        resetVisualTransform()
    }

    private func beginCarryingCat(at location: CGPoint) {
        guard canBeginCatPickUp() else { return }
        cancelCatPickUpCandidate()
        stopMovement()
        catVisual.removeAllActions()
        isInteracting = true
        isCarryingCat = true
        applyPickUpPose()
        catPickUpTouchOffset = .zero
        moveCarriedCat(to: location)
        cat.zPosition = catCarryZPosition
    }

    private func moveCarriedCat(to location: CGPoint) {
        let next = CGPoint(
            x: location.x + catPickUpTouchOffset.x,
            y: location.y + catPickUpTouchOffset.y
        )
        let halfW = maxCatHorizontalHalfWidth
        let minX = halfW
        let maxX = max(minX, size.width - halfW)
        let band = catFloorBand
        let minY = size.height * band.lowerBound
        let maxY = size.height * band.upperBound
        cat.position = CGPoint(
            x: min(max(next.x, minX), maxX),
            y: min(max(next.y, minY), maxY)
        )
        cat.setScale(depthPerspectiveScale(baseY: cat.position.y, backScale: activeCatDepthBackScale))
    }

    private func dropCarriedCat() {
        guard isCarryingCat else { return }
        isCarryingCat = false
        let feetPoint = CGPoint(
            x: cat.position.x,
            y: cat.calculateAccumulatedFrame().minY
        )
        catVisual.anchorPoint = CGPoint(x: 0.5, y: 0)
        startAnimation(.idle)
        cat.position = clampCatPosition(feetPoint)
        cat.setScale(depthPerspectiveScale(baseY: cat.position.y, backScale: activeCatDepthBackScale))
        updateCatFloorDepthLayering()
        isInteracting = false
        runBehavior()
    }

    // MARK: Interaction

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGardenBackdrop else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if isInspectingPictureFrame || isPictureFrameInspectAnimating {
            handlePictureFrameInspectTouch(at: location)
            return
        }

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
            movePlayTarget(to: location)
            return
        }

        if pictureFrameHit(at: location) {
            enterPictureFrameInspect()
            return
        }

        // Prioritize care props over the cat hit target so taps near bowls/litter
        // still open the inspect card even when the cat is standing in front.
        var topPropHit: (prop: RoomProp, z: CGFloat)?
        for (prop, node) in propNodes {
            let hitFrame = propTapHitFrame(for: prop, node: node)
            guard hitFrame.contains(location) else { continue }
            if topPropHit == nil || node.zPosition > topPropHit!.z {
                topPropHit = (prop, node.zPosition)
            }
        }
        if let topPropHit {
            handleTap(topPropHit.prop)
            return
        }

        if let furniture = furnitureTapHit(at: location) {
            // Cat tree / bed sit when the prop is reachable, but if the cat is
            // already drawn on top at this spot, treat the tap as the cat.
            if canBeginCatPickUp(),
               catObscuresFurnitureTap(at: location, furnitureNode: furniture.node) {
                beginCatPickUpCandidate(at: location)
                return
            }
            walkToFurnitureAndSit(key: furniture.key, node: furniture.node)
            return
        }

        if isCarryingCat {
            moveCarriedCat(to: location)
            return
        }

        if canBeginCatPickUp(), isCatHit(at: location) {
            beginCatPickUpCandidate(at: location)
            return
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if isCarryingCat {
            moveCarriedCat(to: location)
            return
        }

        if catPickUpCandidate {
            catPickUpLastLocation = location
            evaluateCatPickUp(at: location)
            return
        }

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
            let anchor = clampPropAnchor(rawAnchor, key: key, naturalHeight: naturalHeight)
            applyDepthTransform(to: node, key: key, baseAnchor: anchor, naturalHeight: naturalHeight)
            applyFlip(to: node, key: key)
            updateFloorPropLayering()
            return
        }

        guard isPlaying else { return }
        isLaserEngaged = true
        movePlayTarget(to: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPlaying { isLaserEngaged = false }
        let location = touches.first?.location(in: self) ?? .zero
        if isCarryingCat {
            dropCarriedCat()
            return
        }
        if catPickUpCandidate {
            let wasQuickTap = CACurrentMediaTime() - catPickUpStartedAt < catPickUpLongPressDuration
            cancelCatPickUpCandidate()
            if wasQuickTap, isCatHit(at: location) {
                handleTap(.cat)
            }
            return
        }
        if isCustomizeMode {
            finishCustomizeTouch(at: location)
            return
        }
        endCustomizeDrag(at: location)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPlaying { isLaserEngaged = false }
        if isCarryingCat {
            dropCarriedCat()
        }
        cancelCatPickUpCandidate()
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
            if isPictureFrame(key) {
                onTapPictureFrame?()
            } else {
                selectProp(key)
            }
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
        updateFloorPropLayering()
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
        let mirrored = propShouldMirrorHorizontally(key: key)
        node.xScale = abs(node.xScale) * (mirrored ? -1 : 1)
    }

    /// Litter box art opens toward the room center by default (right-side placement).
    /// Arabella's box faces the opposite way by default; a user flip toggles from
    /// whichever default the current cat has.
    private func propShouldMirrorHorizontally(key: String) -> Bool {
        if key == PetRoomPropKey.litterBox {
            let defaultMirrored = (skin != .cowCat)
            return defaultMirrored != layoutState.isFlipped(key)   // XOR: flip from default
        }
        return layoutState.isFlipped(key)
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
        if enabled {
            resetPictureFrameInspectImmediately()
        }
        isCustomizeMode = enabled
        if enabled {
            if isCarryingCat { dropCarriedCat() }
            cancelCatPickUpCandidate()
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

    // MARK: Scene visibility (SwiftUI sheets)

    /// Pauses the scene while a modal sheet covers the room; on dismiss, heals
    /// animation/state desync when the walk loop outlives its behavior action.
    func setSheetCoverActive(_ active: Bool) {
        isPaused = active
        if !active {
            recoverFromStalledBehavior()
        }
    }

    /// Restarts ambient life when locomotion visuals and the behavior driver drift apart
    /// (e.g. after SKView pause or a cancelled `behavior` action).
    func recoverFromStalledBehavior() {
        guard !isPlaying,
              !isTrickMode,
              !isCarryingCat,
              !isCustomizeMode,
              !isInspectingPictureFrame,
              !isPictureFrameInspectAnimating else { return }

        let behaviorRunning = cat.action(forKey: "behavior") != nil
        if behaviorRunning { return }

        if currentAction == .walk || currentAction == .pounce {
            isHoldingPose = false
            isInteracting = false
            startAnimation(.idle)
            runBehavior()
            return
        }

        if isHoldingPose && !isHoldingBowlInteraction {
            isHoldingPose = false
            isInteracting = false
            startAnimation(.idle)
            runBehavior()
            return
        }

        if isInteracting {
            isInteracting = false
            startAnimation(.idle)
            runBehavior()
            return
        }

        if !isHoldingPose {
            runBehavior()
        }
    }

    // MARK: Reactions driven by the view (after a care action)

    /// Asks the cat to perform a reaction the view triggers after a care action.
    func playReaction(_ kind: ReactionKind) {
        guard !isPlaying, !isTrickMode, !isCarryingCat else { return }
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
            self.spawnHearts(count: 2)
            self.isInteracting = false
            self.startAnimation(.idle)
            self.runBehavior()
        }
    }

    /// Pose at the water bowl: drink when there is water, confused when the bowl is empty.
    private func waterBowlInteractionPose() -> CatAction {
        waterBowlLevel > 0 ? .drink : .confused
    }

    /// Walks the cat to the water bowl and plays the drink animation, then resumes.
    private func drinkAtBowl() {
        guard let bowl = propNodes[.waterBowl] else { petCat(); return }
        isInteracting = true
        goToBowl(bowl, pose: waterBowlInteractionPose(), hold: 2.2) { [weak self] in
            guard let self else { return }
            self.spawnHearts(count: 2)
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
        if isGardenBackdrop {
            startAnimation(.idle)
            runBehavior()
            return
        }
        guard let food = propNodes[.foodBowl], let water = propNodes[.waterBowl] else {
            startAnimation(.idle)
            runBehavior()
            return
        }
        isInteracting = true
        goToBowl(food, pose: .eat, hold: 1.8) { [weak self] in
            guard let self else { return }
            self.goToBowl(water, pose: self.waterBowlInteractionPose(), hold: 1.8) { [weak self] in
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
    /// Alignment pose for standing at a bowl (confused at an empty water bowl uses drink spacing).
    private func bowlApproachPose(for interaction: CatAction) -> CatAction? {
        switch interaction {
        case .eat: return .eat
        case .drink, .confused: return .drink
        case .snack: return .snack
        default: return nil
        }
    }

    private func goToBowl(_ bowl: SKNode, pose: CatAction, hold: TimeInterval, completion: @escaping () -> Void) {
        if isCustomizeMode, pose == .eat || pose == .drink || pose == .confused {
            completion()
            return
        }
        stopMovement()
        catVisual.removeAction(forKey: "anim")
        cat.zPosition = max(bowl.zPosition + 1, catAtBowlZ)
        let approachPose = bowlApproachPose(for: pose) ?? pose
        let approach = bowlApproachPoint(for: bowl, from: cat.position, pose: approachPose)
        var target = approach.target
        if pose == .eat || pose == .drink || pose == .confused {
            // Pull the landing point toward bowl center so the lowered muzzle
            // sits over the food/water instead of missing to one side.
            let bowlCenterX = bowl.calculateAccumulatedFrame().midX
            let centerDelta = bowlCenterX - target.x
            let maxCenterPull: CGFloat = 20
            let centerPull = max(-maxCenterPull, min(maxCenterPull, centerDelta * 0.6))
            target.x += centerPull
            if pose == .drink || pose == .confused {
                target.x = min(size.width - maxCatHorizontalHalfWidth, target.x + bowlDrinkRightShift)
            }
        } else if pose == .snack {
            // Floor snacks read better when the cat stops slightly farther "up"
            // (toward the back of the floor band), so the lowered muzzle lands
            // directly over the treat instead of dipping below it.
            target.y = min(size.height * catFloorBand.upperBound, target.y + snackApproachRaise)
        }
        face(towards: target.x)
        startAnimation(.walk)
        let distance = hypot(target.x - cat.position.x, target.y - cat.position.y)
        let move = SKAction.move(to: target, duration: max(0.3, TimeInterval(distance / walkSpeed)))
        move.timingMode = .easeInEaseOut
        let arrive = SKAction.run { [weak self] in
            guard let self else { return }
            self.cat.zPosition = max(bowl.zPosition + 1, self.catAtBowlZ)
            self.isHoldingBowlInteraction = pose == .eat || pose == .drink || pose == .confused || pose == .snack
            if pose == .eat || pose == .drink || pose == .confused {
                // Bowls are fixed at the lower-left corner; keep eat/drink frames
                // in their original orientation so the head aligns with the bowl.
                self.facesLeft = false
                self.updateFacingFlip()
            } else {
                self.face(towards: approach.faceX)
            }
            self.applyBowlPose(pose)
        }
        let finish = SKAction.run { [weak self] in
            guard let self else { return }
            self.isHoldingBowlInteraction = false
            self.cat.zPosition = self.catFloorDepthZ(for: self.cat.position.y)
            completion()
        }
        cat.run(.sequence([move, arrive, .wait(forDuration: hold), finish]), withKey: "behavior")
    }

    // MARK: Laser play

    /// Enters play mode. `selectedToyID == nil` uses the laser pointer.
    func startPlay(selectedToyID: String?) {
        guard !isPlaying, !isTrickMode else { return }
        isPlaying = true
        activePlayToyID = selectedToyID
        playToyIsStatic = selectedToyID.map { staticPlayToyIDs.contains($0) } ?? false
        isInteracting = true
        isLaserEngaged = false
        playEngagementSeconds = 0
        playDurationMetFired = false
        onPlayProgress?(0)
        stopMovement()
        catVisual.removeAction(forKey: "anim")
        resetVisualTransform()
        wakeFromOccupiedBedIfNeeded()

        // Wake from sleep (or any idle pose) into standing before chasing.
        startAnimation(.idle)

        if let toyID = selectedToyID {
            spawnPlayToy(id: toyID)
            return
        }

        let dot = SKShapeNode(circleOfRadius: 9)
        dot.fillColor = SKColor(red: 1.0, green: 0.18, blue: 0.22, alpha: 0.95)
        dot.strokeColor = SKColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 0.5)
        dot.glowWidth = 6
        dot.lineWidth = 4
        dot.zPosition = 40
        dot.position = CGPoint(x: size.width * 0.5, y: size.height * laserFloorBand.lowerBound)
        addChild(dot)
        laserDot = dot
        face(towards: dot.position.x)
    }

    /// Backward-compat wrapper: defaults to laser play.
    func startLaserPlay() {
        startPlay(selectedToyID: nil)
    }

    /// While play mode is active, switching hotbar toys updates the spawned target.
    func setPlayToySelection(_ selectedToyID: String?) {
        activePlayToyID = selectedToyID
        playToyIsStatic = selectedToyID.map { staticPlayToyIDs.contains($0) } ?? false
        catnipHitCount = 0
        resetCardboardBoxRoutineState()
        guard isPlaying else { return }
        laserDot?.removeFromParent()
        laserDot = nil
        playToyNode?.removeFromParent()
        playToyNode = nil
        if let selectedToyID {
            spawnPlayToy(id: selectedToyID)
        } else {
            let dot = SKShapeNode(circleOfRadius: 9)
            dot.fillColor = SKColor(red: 1.0, green: 0.18, blue: 0.22, alpha: 0.95)
            dot.strokeColor = SKColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 0.5)
            dot.glowWidth = 6
            dot.lineWidth = 4
            dot.zPosition = 40
            dot.position = CGPoint(x: size.width * 0.5, y: size.height * laserFloorBand.lowerBound)
            addChild(dot)
            laserDot = dot
        }
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
        playToyNode?.removeFromParent()
        playToyNode = nil
        activePlayToyID = nil
        playToyIsStatic = false
        catnipHitCount = 0
        resetCardboardBoxRoutineState()
        isInteracting = false
        if !isTrickMode, !isCustomizeMode {
            isPostPlayRecovering = true
            runPostPlayRecoveryRoutine()
        } else {
            isPostPlayRecovering = false
            startAnimation(.idle)
            if !isTrickMode { runBehavior() }
        }
    }

    /// After active laser play, the cat cools down by taking a drink and then a
    /// short nap before returning to ambient behavior.
    private func runPostPlayRecoveryRoutine() {
        guard let water = propNodes[.waterBowl] else {
            isPostPlayRecovering = false
            idleFor(state: .sleep, duration: 10)
            return
        }
        isInteracting = true
        goToBowl(water, pose: waterBowlInteractionPose(), hold: 1.8) { [weak self] in
            guard let self else { return }
            self.isInteracting = false
            self.isPostPlayRecovering = false
            self.idleFor(state: .sleep, duration: 10)
        }
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
            resetVisualTransform()
            wakeFromOccupiedBedIfNeeded()
            isInteracting = false
            isHoldingPose = false
            walkToCenterAndSit()
        } else {
            clearSnack()
            stopMovement()
            isInteracting = false
            isHoldingPose = false
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
                isHoldingPose = false
                startAnimation(.idle)
                runBehavior()
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
                self.isHoldingPose = false
                self.startAnimation(.idle)
                self.runBehavior()
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
        // Let the beam travel lower toward screen-bottom controls while still
        // keeping it on the floor region where chase behavior feels natural.
        let y = min(max(point.y, size.height * laserFloorBand.lowerBound), size.height * laserFloorBand.upperBound)
        laserDot?.position = CGPoint(x: point.x, y: y)
        face(towards: point.x)
    }

    private func movePlayTarget(to point: CGPoint) {
        if activePlayToyID == nil {
            moveLaser(to: point)
            return
        }
        let x = min(
            max(point.x, size.width * playToySideInsetNormalized),
            size.width * (1 - playToySideInsetNormalized)
        )
        let next = CGPoint(x: x, y: point.y)
        playToyNode?.position = next
        if let toy = playToyNode {
            applyPlayToyFloorDepth(for: toy)
        }
        face(towards: x)
    }

    /// Front edge matches other floor props; back edge uses the same height-based
    /// cap as the cat bed so box/tunnel can't slide as far up the room.
    private func playToyBackLimitY() -> CGFloat {
        let floorBottom = size.height * propFrontBound
        let seam = size.height * floorBand.upperBound
        let referenceHeight: CGFloat = 120
        return max(seam - depthMinScale * referenceHeight, floorBottom)
    }

    private func clampPlayToyFloorY(_ y: CGFloat) -> CGFloat {
        let floorBottom = size.height * propFrontBound
        return min(max(y, floorBottom), playToyBackLimitY())
    }

    /// Floor depth for play toys — feet/base Y on static box/tunnel, bottom edge otherwise.
    private func playToyDepthBaseY(for node: SKNode) -> CGFloat {
        if let sprite = node as? SKSpriteNode, sprite.anchorPoint.y == 0 {
            return sprite.position.y
        }
        return node.calculateAccumulatedFrame().minY
    }

    private func spawnPlayToy(id: String) {
        playToyNode?.removeFromParent()
        let node = makePlayToyNode(id: id)
        let midY = size.height * (catFloorBand.lowerBound + catFloorBand.upperBound) / 2
        let spawnPoint = CGPoint(x: size.width * 0.5, y: midY)
        node.position = spawnPoint
        addChild(node)
        playToyNode = node
        applyPlayToyFloorDepth(for: node)
        resetCardboardBoxRoutineState()
        face(towards: node.position.x)
    }

    private func makePlayToyNode(id: String) -> SKNode {
        guard let item = PetShopCatalog.item(id: id),
              let imageName = item.imageName,
              let sprite = loadImage(imageName) else {
            let fallback = SKLabelNode(text: "🧶")
            fallback.fontSize = 36
            fallback.verticalAlignmentMode = .center
            let container = SKNode()
            container.addChild(fallback)
            return container
        }

        // Box/tunnel use floor feet like other props so depth sorting matches the cat.
        sprite.anchorPoint = staticPlayToyIDs.contains(id)
            ? CGPoint(x: 0.5, y: 0)
            : CGPoint(x: 0.5, y: 0.5)
        let displayHeight: CGFloat
        switch id {
        case "toy_play_tunnel":
            displayHeight = 110
        case "toy_cardboard_box":
            displayHeight = 94
        case "toy_yarn_ball":
            displayHeight = 48.4
        case "toy_catnip_pouch":
            displayHeight = 48.4
        default:
            displayHeight = 44
        }
        if sprite.size.height > 0 {
            sprite.size = sprite.size.scaledToHeight(displayHeight)
        }
        return sprite
    }

    private func setCardboardBoxVisualState(_ state: CardboardBoxVisualState) {
        cardboardBoxVisualState = state
        guard activePlayToyID == "toy_cardboard_box" || activePlayToyID == "toy_play_tunnel",
              let sprite = playToyNode as? SKSpriteNode else { return }
        let imageName: String
        switch state {
        case .closed:
            imageName = activePlayToyID == "toy_play_tunnel" ? "prop_cat_toy_tunnel" : "prop_cat_toy_box"
        case .peek:
            if activePlayToyID == "toy_play_tunnel" {
                imageName = (skin == .calico) ? "prop_cat_toy_tunnel_0" : "prop_cat_toy_tunnel_1"
            } else {
                imageName = (skin == .calico) ? "prop_cat_toy_box_0" : "prop_cat_toy_box_1"
            }
        }
        guard let texture = textureForAsset(named: imageName) else { return }
        sprite.texture = texture
        let baseDisplayHeight: CGFloat = activePlayToyID == "toy_play_tunnel" ? 110 : 94
        let displayHeight: CGFloat = (state == .peek) ? baseDisplayHeight * 1.10 : baseDisplayHeight
        sprite.size = sprite.size.scaledToHeight(displayHeight)
        if let toy = playToyNode {
            applyPlayToyFloorDepth(for: toy)
        }
    }

    private func resetCardboardBoxRoutineState() {
        cardboardBoxCatState = .approachBox
        cardboardBoxStateDeadline = 0
        cardboardBoxWanderTarget = nil
        cat.alpha = 1
        setCardboardBoxVisualState(.closed)
    }

    private func walkCatToward(_ target: CGPoint, dt: TimeInterval, speedMultiplier: CGFloat) -> Bool {
        let dx = target.x - cat.position.x
        let dy = target.y - cat.position.y
        let distance = hypot(dx, dy)
        guard distance > 12 else {
            startAnimation(.idle)
            return true
        }
        face(towards: target.x)
        let step = min(CGFloat(walkSpeed * speedMultiplier) * CGFloat(dt), distance)
        cat.position = clampCatPosition(CGPoint(
            x: cat.position.x + dx / distance * step,
            y: cat.position.y + dy / distance * step
        ))
        if catVisual.action(forKey: "anim") == nil || currentAction != .walk {
            startAnimation(.walk)
        }
        return false
    }

    /// Special loop for the cardboard box toy while the player leaves the scene
    /// idling: approach -> hide up to 10s -> peek -> stare -> brief wander/return.
    private func updateCardboardBoxRoutine(currentTime: TimeInterval, dt: TimeInterval) {
        guard let boxNode = playToyNode else { return }
        let boxPosition = boxNode.position
        switch cardboardBoxCatState {
        case .approachBox:
            if walkCatToward(boxPosition, dt: dt, speedMultiplier: 1.45) {
                cat.alpha = 0
                setCardboardBoxVisualState(.peek)
                cardboardBoxStateDeadline = currentTime + Double.random(in: 0.8...10.0)
                cardboardBoxCatState = .hiddenInBox
            }
        case .hiddenInBox:
            guard currentTime >= cardboardBoxStateDeadline else { return }
            cat.alpha = 1
            let emergeSide: CGFloat = Bool.random() ? -1 : 1
            let emergeX = min(max(boxPosition.x + 52 * emergeSide, maxCatHorizontalHalfWidth),
                              size.width - maxCatHorizontalHalfWidth)
            cat.position = clampCatPosition(CGPoint(x: emergeX, y: boxPosition.y))
            setCardboardBoxVisualState(.closed)
            face(towards: boxPosition.x)
            startAnimation(.idle)
            cardboardBoxStateDeadline = currentTime + Double.random(in: 0.7...2.0)
            cardboardBoxCatState = .staringAtBox
        case .staringAtBox:
            face(towards: boxPosition.x)
            guard currentTime >= cardboardBoxStateDeadline else { return }
            if Double.random(in: 0...1) < 0.55 {
                let direction: CGFloat = cat.position.x < boxPosition.x ? -1 : 1
                let wanderX = min(max(cat.position.x + CGFloat.random(in: 70...130) * direction, maxCatHorizontalHalfWidth),
                                  size.width - maxCatHorizontalHalfWidth)
                let wanderY = min(max(boxPosition.y + CGFloat.random(in: -24...22),
                                      size.height * catFloorBand.lowerBound),
                                  size.height * catFloorBand.upperBound)
                cardboardBoxWanderTarget = CGPoint(x: wanderX, y: wanderY)
                cardboardBoxCatState = .wanderingAway
            } else {
                cardboardBoxCatState = .returningToBox
            }
        case .wanderingAway:
            guard let target = cardboardBoxWanderTarget else {
                cardboardBoxCatState = .returningToBox
                return
            }
            if walkCatToward(target, dt: dt, speedMultiplier: 1.55) {
                cardboardBoxWanderTarget = nil
                cardboardBoxStateDeadline = currentTime + Double.random(in: 1.0...2.0)
                cardboardBoxCatState = .returningToBox
            }
        case .returningToBox:
            if currentTime < cardboardBoxStateDeadline {
                face(towards: boxPosition.x)
                startAnimation(.idle)
                return
            }
            cardboardBoxStateDeadline = 0
            if walkCatToward(boxPosition, dt: dt, speedMultiplier: 1.6) {
                cat.alpha = 0
                setCardboardBoxVisualState(.peek)
                cardboardBoxStateDeadline = currentTime + Double.random(in: 0.8...10.0)
                cardboardBoxCatState = .hiddenInBox
            }
        }
    }

    /// Keeps play toys on the same perspective scale and z-order curve as floor
    /// props and the cat (`propDepthZ`), so they pass in front/behind correctly.
    private func applyPlayToyFloorDepth(for node: SKNode) {
        var baseY = playToyDepthBaseY(for: node)
        let clampedBaseY = clampPlayToyFloorY(baseY)
        if abs(clampedBaseY - baseY) > 0.5 {
            node.position.y += clampedBaseY - baseY
        }
        baseY = clampedBaseY
        node.setScale(playToyDepthScale(for: baseY))
        node.zPosition = propDepthZ(for: baseY)
    }

    /// Food/water bowls use the same front/back depth curve as other floor props
    /// (refreshed each frame so the cat layers correctly as it walks).
    private func applyCareBowlFloorDepth(for prop: RoomProp, key: String) {
        guard let node = propNodes[prop] else { return }
        let naturalHeight = propNaturalHeights[key] ?? node.calculateAccumulatedFrame().height
        let anchor = propFloorAnchor(for: node)
        let clamped = clampPropAnchor(anchor, key: key, naturalHeight: naturalHeight)
        applyDepthTransform(to: node, key: key, baseAnchor: clamped, naturalHeight: naturalHeight)
        node.zPosition = propDepthZ(for: clamped.y)
    }

    private func refreshCareBowlDepthLayering() {
        applyCareBowlFloorDepth(for: .foodBowl, key: PetRoomPropKey.foodBowl)
        applyCareBowlFloorDepth(for: .waterBowl, key: PetRoomPropKey.waterBowl)
    }

    private func playToyDepthScale(for baseY: CGFloat) -> CGFloat {
        propPerspectiveScale(baseY: baseY)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime

        // Match the props' floor perspective: the cat shrinks as it walks toward
        // the back of the room and grows as it comes forward. Scales around its
        // feet (the cat node's origin), so it stays planted on the floor.
        cat.setScale(depthPerspectiveScale(baseY: cat.position.y, backScale: activeCatDepthBackScale))
        if !isCarryingCat {
            cat.position = clampCatPosition(cat.position)
        }
        if catPickUpCandidate {
            evaluateCatPickUp(at: catPickUpLastLocation)
        }
        updateCatFloorDepthLayering()
        refreshCareBowlDepthLayering()
        if let toy = playToyNode {
            applyPlayToyFloorDepth(for: toy)
        }
        updateNeedThoughtBubblePosition()
        updateToiletPaperAutoBat(currentTime: currentTime)

        if isPlaying, isLaserEngaged {
            playEngagementSeconds += dt
            onPlayProgress?(playEngagementSeconds)
            if !playDurationMetFired,
               playEngagementSeconds >= PetEconomy.playDurationRequired {
                playDurationMetFired = true
                onPlayDurationMet?()
            }
        }

        guard isPlaying, !isHoldingPose else { return }
        if activePlayToyID == "toy_cardboard_box" || activePlayToyID == "toy_play_tunnel" {
            updateCardboardBoxRoutine(currentTime: currentTime, dt: dt)
            return
        }
        let targetPoint: CGPoint
        if let toy = playToyNode {
            targetPoint = toy.position
        } else if let dot = laserDot {
            targetPoint = dot.position
        } else {
            return
        }

        let dx = targetPoint.x - cat.position.x
        let dy = targetPoint.y - cat.position.y
        let distance = hypot(dx, dy)
        face(towards: targetPoint.x)

        if distance > 12 {
            let chaseSpeedMultiplier = currentPlayChaseSpeedMultiplier()
            let step = min(CGFloat(walkSpeed * chaseSpeedMultiplier) * CGFloat(dt), distance)
            cat.position = clampCatPosition(CGPoint(
                x: cat.position.x + dx / distance * step,
                y: cat.position.y + dy / distance * step
            ))
            if catVisual.action(forKey: "anim") == nil { startAnimation(.walk) }
        } else if catVisual.action(forKey: "pounce") == nil {
            // Caught up — leap toward the dot, then keep chasing.
            startAnimation(.pounce)
            let offset = pounceTowardOffset(from: cat.position, to: targetPoint, distance: PounceHop.laserDistance)
            runPounceAnimation(squash: 0.88, offset: offset)
            if let toy = playToyNode, !playToyIsStatic, currentTime - lastToyBatAt > 0.25 {
                // Light bat/kick reaction for small toys the cat can move.
                lastToyBatAt = currentTime
                if activePlayToyID == catnipToyID {
                    catnipHitCount += 1
                }
                let nudged = CGPoint(
                    x: toy.position.x + CGFloat.random(in: -36...36),
                    y: toy.position.y + CGFloat.random(in: -14...18)
                )
                let clampedX = min(
                    max(nudged.x, size.width * playToySideInsetNormalized),
                    size.width * (1 - playToySideInsetNormalized)
                )
                toy.position = CGPoint(x: clampedX, y: nudged.y)
                applyPlayToyFloorDepth(for: toy)
                toy.run(.move(to: toy.position, duration: 0.18))
            }
        }
    }

    private func currentPlayChaseSpeedMultiplier() -> CGFloat {
        let base: CGFloat = 1.6
        guard activePlayToyID == catnipToyID else { return base }
        let extra = min(CGFloat(catnipHitCount) * catnipSpeedStep, catnipMaxExtraSpeed)
        return base + extra
    }

    /// Matches the cat's draw order to floor props (bed, tree, bowls, litter, etc.)
    /// using the same depth curve as `updateFloorPropLayering`.
    private func updateCatFloorDepthLayering() {
        if isCarryingCat {
            cat.zPosition = catCarryZPosition
            return
        }
        // While explicit interactions drive z-order (eat/drink/snack/confused at bowl), keep that.
        if isHoldingBowlInteraction
            || currentAction == .eat || currentAction == .drink || currentAction == .snack {
            return
        }
        if currentAction == .sleep {
            cat.zPosition = catFloorDepthZ(for: cat.position.y) - catSleepDepthOffset
            return
        }
        cat.zPosition = catFloorDepthZ(for: cat.position.y)
    }

    private func petCat() {
        guard !isInteracting else { return }
        isInteracting = true
        stopMovement()
        wakeFromOccupiedBedIfNeeded()
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

    private func spawnHearts(count: Int = 4) {
        for i in 0..<count {
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

    private func rebuildNeedThoughtBubble() {
        needThoughtBubbleNode?.removeFromParent()
        needThoughtBubbleNode = nil
        guard needThoughtKind != .none else { return }

        let bubble = SKNode()
        bubble.zPosition = 52

        let bubbleBody = SKShapeNode(ellipseOf: CGSize(width: 64, height: 50))
        bubbleBody.fillColor = .white
        bubbleBody.strokeColor = SKColor(white: 0.8, alpha: 1)
        bubbleBody.lineWidth = 2
        bubble.addChild(bubbleBody)

        let tailMid = SKShapeNode(circleOfRadius: 5.5)
        tailMid.fillColor = .white
        tailMid.strokeColor = bubbleBody.strokeColor
        tailMid.lineWidth = 1.4
        tailMid.position = CGPoint(x: -16, y: -30)
        bubble.addChild(tailMid)

        let tailEnd = SKShapeNode(circleOfRadius: 3.5)
        tailEnd.fillColor = .white
        tailEnd.strokeColor = bubbleBody.strokeColor
        tailEnd.lineWidth = 1.2
        tailEnd.position = CGPoint(x: -25, y: -40)
        bubble.addChild(tailEnd)

        let iconNode: SKNode
        switch needThoughtKind {
        case .food:
            if let image = UIImage(named: "prop_cat_food_kibble") {
                let sprite = SKSpriteNode(texture: SKTexture(image: image))
                sprite.size = sprite.size.scaledToHeight(24)
                iconNode = sprite
            } else {
                let label = SKLabelNode(text: "🍖")
                label.fontSize = 20
                label.verticalAlignmentMode = .center
                iconNode = label
            }
        case .water:
            let label = SKLabelNode(text: "💧")
            label.fontSize = 22
            label.verticalAlignmentMode = .center
            iconNode = label
        case .none:
            return
        }
        iconNode.position = CGPoint(x: 0, y: 0)
        bubble.addChild(iconNode)

        addChild(bubble)
        needThoughtBubbleNode = bubble
        updateNeedThoughtBubblePosition()
    }

    private func updateNeedThoughtBubblePosition() {
        guard let bubble = needThoughtBubbleNode else { return }
        guard let anchor = catHeadAnchorPoint(verticalOffset: 56) else { return }
        bubble.position = anchor
    }

    /// Scene point for anchoring the level pill above the cat (nil when the cat is hidden).
    func catHeadAnchorPoint(verticalOffset: CGFloat = 22) -> CGPoint? {
        guard cat.alpha > 0.5 else { return nil }
        let catFrame = cat.calculateAccumulatedFrame()
        guard catFrame.width > 1, catFrame.height > 1 else { return nil }
        let headX = catFrame.midX
        let headY = catFrame.maxY + verticalOffset
        return CGPoint(
            x: min(max(headX, 46), size.width - 46),
            y: min(max(headY, 64), size.height - 46)
        )
    }

    // MARK: Asset helpers

    private static let maxTextureDimension: CGFloat = 2048

    /// Loads a sprite from a catalog image name, or nil if missing.
    private func loadImage(_ name: String) -> SKSpriteNode? {
        guard let texture = textureForAsset(named: name) else { return nil }
        return SKSpriteNode(texture: texture)
    }

    /// Builds a SpriteKit texture with black-matte removal for catalog PNGs.
    private func textureForAsset(named name: String) -> SKTexture? {
        guard let image = UIImage(named: name) else { return nil }
        let alphaFixed = Self.imageByRemovingBlackMatteIfNeeded(image)
        return SKTexture(image: Self.imageFittingTextureLimits(alphaFixed))
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

    /// Some imported PNGs have an opaque black matte instead of true alpha.
    /// If the border is mostly black, convert near-black fully-opaque pixels to transparent.
    private static func imageByRemovingBlackMatteIfNeeded(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let width = cg.width
        let height = cg.height
        guard width > 1, height > 1 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        func isNearBlack(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Bool {
            r <= 24 && g <= 24 && b <= 24
        }

        var borderOpaqueCount = 0
        var borderBlackCount = 0
        for x in stride(from: 0, to: width, by: max(1, width / 80)) {
            for y in [0, height - 1] {
                let i = (y * width + x) * bytesPerPixel
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                if a > 220 {
                    borderOpaqueCount += 1
                    if isNearBlack(r, g, b) { borderBlackCount += 1 }
                }
            }
        }
        for y in stride(from: 0, to: height, by: max(1, height / 80)) {
            for x in [0, width - 1] {
                let i = (y * width + x) * bytesPerPixel
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                if a > 220 {
                    borderOpaqueCount += 1
                    if isNearBlack(r, g, b) { borderBlackCount += 1 }
                }
            }
        }

        guard borderOpaqueCount > 0 else { return image }
        let blackBorderRatio = Double(borderBlackCount) / Double(borderOpaqueCount)
        guard blackBorderRatio >= 0.80 else { return image }

        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
            if a >= 245 && isNearBlack(r, g, b) {
                pixels[i + 3] = 0
            }
        }

        guard let out = ctx.makeImage() else { return image }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
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

    /// Grass band on the Couples Profile garden backdrop (fraction of scene height).
    private let gardenFloorBand: ClosedRange<CGFloat> = 0.08...0.46

    /// Floor band used for perspective scale and draw order (garden vs pet room).
    private var perspectiveFloorBand: ClosedRange<CGFloat> {
        isGardenBackdrop ? gardenFloorBand : floorBand
    }

    private var activeCatDepthBackScale: CGFloat {
        isGardenBackdrop ? gardenCatDepthBackScale : catDepthBackScale
    }

    /// Vertical band the cat may walk in — same front reach as play mode
    /// (`laserFloorLowerBound`), with a small back inset so it stays off the seam.
    private var catFloorBand: ClosedRange<CGFloat> {
        if isGardenBackdrop { return gardenFloorBand }
        let backInset: CGFloat = 0.035
        let lower = max(0.01, min(laserFloorLowerBound, floorBand.upperBound))
        return lower...max(lower, floorBand.upperBound - backInset)
    }

    /// Play mode uses the same walk band as ambient (kept for call sites that
    /// reference it explicitly, e.g. laser dot placement and small chase toys).
    private var laserFloorBand: ClosedRange<CGFloat> {
        catFloorBand
    }

    private var activeCatMovementBand: ClosedRange<CGFloat> {
        catFloorBand
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
        let movementBand = activeCatMovementBand
        let minY = size.height * movementBand.lowerBound
        let maxY = size.height * movementBand.upperBound
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
