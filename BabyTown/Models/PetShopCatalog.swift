import SwiftUI
import UIKit

enum PetEquipSlot: String, Codable, CaseIterable {
    case catTree
    case foodBowl
    case waterBowl
    case litterBox
    case collar
}

enum PetShopCategory: String, CaseIterable, Identifiable {
    case catTrees
    case catBeds
    case bowls
    case catFood
    case litterBoxes
    case collars
    case catToys
    case plants
    case pictureFrames
    case furniture
    case wallColors

    var id: String { rawValue }

    /// Market and "Your room items" category pills (collar & couch hidden for now).
    static let pickerCategories: [PetShopCategory] = [
        .catTrees,
        .catBeds,
        .catFood,
        .catToys,
        .bowls,
        .litterBoxes,
        .plants,
        .pictureFrames,
        .wallColors,
    ]

    var title: String {
        switch self {
        case .catTrees: return "Cat Tree"
        case .catBeds: return "Cat Bed"
        case .bowls: return "Bowls"
        case .catFood: return "Cat Food"
        case .litterBoxes: return "Litter Box"
        case .collars: return "Collar"
        case .furniture: return "Couch"
        case .catToys: return "Cat Toys"
        case .plants: return "Plants"
        case .wallColors: return "Wall Color"
        case .pictureFrames: return "Picture Frames"
        }
    }

    var systemImage: String {
        switch self {
        case .catTrees: return "tree.fill"
        case .catBeds: return "bed.double.fill"
        case .bowls: return "takeoutbag.and.cup.and.straw.fill"
        case .catFood: return "fish.fill"
        case .litterBoxes: return "shippingbox.fill"
        case .collars: return "bell.fill"
        case .furniture: return "sofa.fill"
        case .catToys: return "balloon.fill"
        case .plants: return "leaf.fill"
        case .wallColors: return "paintpalette.fill"
        case .pictureFrames: return "photo.artframe"
        }
    }
}

struct PetShopItem: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let category: PetShopCategory
    let cost: Int
    /// Asset catalog image for furniture / toys; nil for swatch-only items.
    let imageName: String?
    let systemImage: String
    let placeholderCaption: String
    let defaultSize: CGSize
    let isFloorItem: Bool
    let isPlayToy: Bool
    let isWallColor: Bool
    let isPictureFrame: Bool
    let equipSlot: PetEquipSlot?
    /// Servings added to the pantry when purchased (cat food only).
    let servingsGranted: Int?
    /// Free classic style; selected when nothing else is equipped for the slot.
    let isStarter: Bool
    /// Auto-cleaning litter box: never goes dirty and passively collects the
    /// litter coins for the player.
    let isAutoLitter: Bool

    var isCatFood: Bool { servingsGranted != nil }

    init(
        id: String,
        name: String,
        detail: String,
        category: PetShopCategory,
        cost: Int,
        imageName: String?,
        systemImage: String,
        placeholderCaption: String,
        defaultSize: CGSize,
        isFloorItem: Bool,
        isPlayToy: Bool = false,
        isWallColor: Bool,
        isPictureFrame: Bool,
        equipSlot: PetEquipSlot? = nil,
        servingsGranted: Int? = nil,
        isStarter: Bool = false,
        isAutoLitter: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.category = category
        self.cost = cost
        self.imageName = imageName
        self.systemImage = systemImage
        self.placeholderCaption = placeholderCaption
        self.defaultSize = defaultSize
        self.isFloorItem = isFloorItem
        self.isPlayToy = isPlayToy
        self.isWallColor = isWallColor
        self.isPictureFrame = isPictureFrame
        self.equipSlot = equipSlot
        self.servingsGranted = servingsGranted
        self.isStarter = isStarter
        self.isAutoLitter = isAutoLitter
    }
}

enum PetShopCatalog {

    static let legacyPictureFrameID = "decor_memory_frame"
    static let defaultPictureFrameID = "decor_frame_cat"

    static let pictureFrameItemIDs: [String] = [
        "decor_frame_cat",
        "decor_frame_floral",
        "decor_frame_hearts",
        "decor_frame_ribbon",
        "decor_frame_moon",
        "decor_frame_leaves",
        "decor_frame_bear",
        "decor_frame_ornate",
    ]

    static let all: [PetShopItem] = [
        // MARK: Cat Tree
        PetShopItem(
            id: "cat_tree_classic",
            name: "Classic Cat Tree",
            detail: "The cozy tower already in your room.",
            category: .catTrees,
            cost: 0,
            imageName: "prop_cat_tree",
            systemImage: "tree.fill",
            placeholderCaption: "Cat Tree",
            defaultSize: CGSize(width: 150, height: 275),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .catTree,
            isStarter: true
        ),
        PetShopItem(
            id: "cat_tree_sky",
            name: "Sage Garden Tower",
            detail: "A premium multi-level lounge with leafy dangling toys.",
            category: .catTrees,
            cost: 95,
            imageName: "prop_cat_tree_1",
            systemImage: "tree.fill",
            placeholderCaption: "Sky Tower",
            defaultSize: CGSize(width: 150, height: 300),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .catTree
        ),
        PetShopItem(
            id: "cat_tree_cozy",
            name: "Royal Lavender Loft",
            detail: "Top-tier luxury cat tree with plush loft and scratch ramp.",
            category: .catTrees,
            cost: 120,
            imageName: "prop_cat_tree_2",
            systemImage: "leaf.fill",
            placeholderCaption: "Perch",
            defaultSize: CGSize(width: 137.5, height: 250),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .catTree
        ),

        // MARK: Bowls
        PetShopItem(
            id: "bowl_food_classic",
            name: "Classic Food Bowl",
            detail: "The pink bowl your kitty eats from now.",
            category: .bowls,
            cost: 0,
            imageName: "prop_food_bowl",
            systemImage: "fork.knife",
            placeholderCaption: "Food",
            defaultSize: CGSize(width: 52, height: 40),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .foodBowl,
            isStarter: true
        ),
        PetShopItem(
            id: "bowl_water_classic",
            name: "Classic Water Bowl",
            detail: "Fresh water, always within paw's reach.",
            category: .bowls,
            cost: 0,
            imageName: "prop_water_bowl",
            systemImage: "drop.fill",
            placeholderCaption: "Water",
            defaultSize: CGSize(width: 52, height: 40),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .waterBowl,
            isStarter: true
        ),
        PetShopItem(
            id: "bowl_water_sky",
            name: "Sky Blue Water Bowl",
            detail: "Cool ceramic for crisp, clean sips.",
            category: .bowls,
            cost: 20,
            imageName: "prop_water_bowl_2",
            systemImage: "drop.circle.fill",
            placeholderCaption: "Water",
            defaultSize: CGSize(width: 72, height: 56),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .waterBowl
        ),
        PetShopItem(
            id: "bowl_water_flower",
            name: "Garden Bloom Water Bowl",
            detail: "A floral ceramic bowl for calm hydration breaks.",
            category: .bowls,
            cost: 34,
            imageName: "prop_water_bowl_1",
            systemImage: "camera.macro.circle.fill",
            placeholderCaption: "Water",
            defaultSize: CGSize(width: 72, height: 56),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .waterBowl
        ),
        PetShopItem(
            id: "bowl_water_luxe",
            name: "Luxe Stone Water Bowl",
            detail: "Premium stone finish that keeps water cool.",
            category: .bowls,
            cost: 48,
            imageName: "prop_water_bowl_4",
            systemImage: "sparkles",
            placeholderCaption: "Water",
            defaultSize: CGSize(width: 72, height: 56),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .waterBowl
        ),

        // MARK: Cat Food
        PetShopItem(
            id: "food_dry_kibble",
            name: "Dry Kibble",
            detail: "Everyday crunch — 5 servings for the bowl.",
            category: .catFood,
            cost: 9,
            imageName: "prop_cat_food_kibble",
            systemImage: "leaf.fill",
            placeholderCaption: "Kibble",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            servingsGranted: 5
        ),
        PetShopItem(
            id: "food_wet_chicken",
            name: "Wet Food, Chicken",
            detail: "Tender chicken recipe — 4 hearty servings.",
            category: .catFood,
            cost: 14,
            imageName: "prop_cat_food_chicken",
            systemImage: "drop.fill",
            placeholderCaption: "Chicken",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            servingsGranted: 4
        ),
        PetShopItem(
            id: "food_wet_tuna",
            name: "Wet Food, Tuna",
            detail: "Rich tuna bites — 4 flavorful servings.",
            category: .catFood,
            cost: 16,
            imageName: "prop_cat_food_tuna",
            systemImage: "fish.fill",
            placeholderCaption: "Tuna",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            servingsGranted: 4
        ),
        PetShopItem(
            id: "food_sashimi_premium",
            name: "Sashimi for Cats",
            detail: "Premium-grade sashimi — 3 luxury servings.",
            category: .catFood,
            cost: 32,
            imageName: "prop_cat_food_sashimi",
            systemImage: "sparkles",
            placeholderCaption: "Sashimi",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            servingsGranted: 3
        ),

        // MARK: Litter Box
        PetShopItem(
            id: "litter_classic",
            name: "Classic Litter Box",
            detail: "The tidy blue box already in the corner.",
            category: .litterBoxes,
            cost: 0,
            imageName: "prop_litter_box_1_sheet",
            systemImage: "shippingbox.fill",
            placeholderCaption: "Litter",
            defaultSize: CGSize(width: 250, height: 150),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .litterBox,
            isStarter: true
        ),
        PetShopItem(
            id: "litter_steel",
            name: "Stainless Steel Litter Box",
            detail: "A sleek brushed-metal tray that wipes clean.",
            category: .litterBoxes,
            cost: 40,
            imageName: "prop_litter_box_2_sheet",
            systemImage: "tray.fill",
            placeholderCaption: "Litter",
            defaultSize: CGSize(width: 250, height: 150),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .litterBox
        ),
        PetShopItem(
            id: "litter_hooded",
            name: "Hooded Litter Box",
            detail: "A cozy pink hood for extra privacy.",
            category: .litterBoxes,
            cost: 70,
            imageName: "prop_litter_box_3_sheet",
            systemImage: "house.fill",
            placeholderCaption: "Litter",
            defaultSize: CGSize(width: 237.5, height: 175),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .litterBox
        ),
        PetShopItem(
            id: "litter_auto",
            name: "Auto-Clean Litter Box",
            detail: "Cleans itself and collects the coins for you — never scoop again.",
            category: .litterBoxes,
            cost: 2500,
            imageName: "prop_litter_box_4_sheet",
            systemImage: "gearshape.2.fill",
            placeholderCaption: "Litter",
            defaultSize: CGSize(width: 237.5, height: 187.5),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .litterBox,
            isAutoLitter: true
        ),

        // MARK: Collars
        PetShopItem(
            id: "collar_pink_bow",
            name: "Pink Bow Collar",
            detail: "A sweet bow for your kitty's neck.",
            category: .collars,
            cost: 15,
            imageName: nil,
            systemImage: "heart.circle.fill",
            placeholderCaption: "Bow",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .collar
        ),
        PetShopItem(
            id: "collar_bell",
            name: "Bell Collar",
            detail: "A tiny jingle when they prance around.",
            category: .collars,
            cost: 18,
            imageName: nil,
            systemImage: "bell.fill",
            placeholderCaption: "Bell",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .collar
        ),
        PetShopItem(
            id: "collar_star",
            name: "Star Tag Collar",
            detail: "A lucky star charm for adventures.",
            category: .collars,
            cost: 20,
            imageName: nil,
            systemImage: "star.circle.fill",
            placeholderCaption: "Star",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .collar
        ),

        // MARK: Cat Bed
        PetShopItem(
            id: "furniture_cat_bed_1",
            name: "Garden Charm Bed",
            detail: "Soft green bed with a ribbon charm for cozy naps.",
            category: .catBeds,
            cost: 35,
            imageName: "prop_cat_bed_1",
            systemImage: "bed.double.fill",
            placeholderCaption: "Cat Bed",
            defaultSize: CGSize(width: 230, height: 150),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "furniture_cat_bed_2",
            name: "Pink Snuggle Bed",
            detail: "A plush pink bed with sweet kitty pattern accents.",
            category: .catBeds,
            cost: 35,
            imageName: "prop_cat_bed_2",
            systemImage: "heart.fill",
            placeholderCaption: "Cat Bed",
            defaultSize: CGSize(width: 230, height: 150),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "furniture_cat_bed_3",
            name: "Blue Paw Cloud Bed",
            detail: "Round cloud-soft bed with a paw design and star toy.",
            category: .catBeds,
            cost: 35,
            imageName: "prop_cat_bed_3",
            systemImage: "star.fill",
            placeholderCaption: "Cat Bed",
            defaultSize: CGSize(width: 230, height: 150),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),

        // MARK: Furniture
        PetShopItem(
            id: "furniture_couch",
            name: "Cozy Couch",
            detail: "A soft spot for lounging on the floor.",
            category: .furniture,
            cost: 45,
            imageName: "prop_couch",
            systemImage: "sofa.fill",
            placeholderCaption: "Couch",
            defaultSize: CGSize(width: 140, height: 80),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),

        // MARK: Plants
        PetShopItem(
            id: "furniture_small_plant",
            name: "Tulip Pot Plant",
            detail: "A leafy little plant in a tulip pot. Tap to water it.",
            category: .plants,
            cost: 45,
            imageName: "prop_small_plant",
            systemImage: "leaf.fill",
            placeholderCaption: "Plant",
            defaultSize: CGSize(width: 105, height: 126),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "furniture_big_plant",
            name: "Monstera Pot Plant",
            detail: "A lush statement monstera. Tap to water it.",
            category: .plants,
            cost: 80,
            imageName: "prop_big_plant",
            systemImage: "leaf.fill",
            placeholderCaption: "Plant",
            defaultSize: CGSize(width: 150.5, height: 182),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),

        // MARK: Cat Toys
        PetShopItem(
            id: "toy_yarn_ball",
            name: "Yarn Ball",
            detail: "A classic pink yarn ball for playful chase sessions.",
            category: .catToys,
            cost: 24,
            imageName: "prop_cat_toy_0",
            systemImage: "circle.fill",
            placeholderCaption: "Yarn",
            defaultSize: CGSize(width: 39.6, height: 39.6),
            isFloorItem: false,
            isPlayToy: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "toy_little_fish",
            name: "Little Fish",
            detail: "A catnip fish plush for bouncy pounce practice.",
            category: .catToys,
            cost: 28,
            imageName: "prop_cat_toy_1",
            systemImage: "fish.fill",
            placeholderCaption: "Fish",
            defaultSize: CGSize(width: 54, height: 28),
            isFloorItem: false,
            isPlayToy: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "toy_catnip_pouch",
            name: "Catnip Pouch",
            detail: "A fragrant catnip pouch for focused toy training.",
            category: .catToys,
            cost: 32,
            imageName: "prop_cat_toy_2",
            systemImage: "leaf.fill",
            placeholderCaption: "Catnip",
            defaultSize: CGSize(width: 63.8, height: 35.2),
            isFloorItem: false,
            isPlayToy: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "toy_cardboard_box",
            name: "Cardboard Box",
            detail: "Every cat's favorite hideout. Free forever.",
            category: .catToys,
            cost: 0,
            imageName: "prop_cat_toy_box",
            systemImage: "shippingbox.fill",
            placeholderCaption: "Box",
            defaultSize: CGSize(width: 64, height: 52),
            isFloorItem: false,
            isPlayToy: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "toy_play_tunnel",
            name: "Play Tunnel",
            detail: "A crinkly tunnel toy for zoomies and ambushes.",
            category: .catToys,
            cost: 36,
            imageName: "prop_cat_toy_tunnel",
            systemImage: "circle.dashed.inset.filled",
            placeholderCaption: "Tunnel",
            defaultSize: CGSize(width: 72, height: 40),
            isFloorItem: false,
            isPlayToy: true,
            isWallColor: false,
            isPictureFrame: false
        ),

        // MARK: Wall Color
        PetShopItem(
            id: "wall_blush",
            name: "Blush Pink",
            detail: "Warm rose-tinted walls.",
            category: .wallColors,
            cost: 18,
            imageName: nil,
            systemImage: "paintpalette.fill",
            placeholderCaption: "",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: true,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "wall_sage",
            name: "Soft Sage",
            detail: "Calm green wall wash.",
            category: .wallColors,
            cost: 18,
            imageName: nil,
            systemImage: "paintpalette.fill",
            placeholderCaption: "",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: true,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "wall_lavender",
            name: "Lavender Mist",
            detail: "Gentle purple evening tone.",
            category: .wallColors,
            cost: 18,
            imageName: nil,
            systemImage: "paintpalette.fill",
            placeholderCaption: "",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: true,
            isPictureFrame: false
        ),

        // MARK: Picture Frames
        PetShopItem(
            id: "decor_frame_cat",
            name: "Peek-a-Boo Cat Frame",
            detail: "A curious kitten peeks over your favorite moment.",
            category: .pictureFrames,
            cost: 32,
            imageName: "prop_frame_cat",
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 76, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
        PetShopItem(
            id: "decor_frame_floral",
            name: "Floral Scallop Frame",
            detail: "Soft flowers and a little heart for sweet memories.",
            category: .pictureFrames,
            cost: 38,
            imageName: "prop_frame_floral",
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 90, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
        PetShopItem(
            id: "decor_frame_hearts",
            name: "Sweetheart Frame",
            detail: "Tiny hearts on every side for extra love.",
            category: .pictureFrames,
            cost: 34,
            imageName: "prop_frame_hearts",
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 87, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
        PetShopItem(
            id: "decor_frame_ribbon",
            name: "Ribbon Tag Frame",
            detail: "A bow and paw-print tag for your wall gallery.",
            category: .pictureFrames,
            cost: 42,
            imageName: "prop_frame_ribbon",
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 85, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
        PetShopItem(
            id: "decor_frame_moon",
            name: "Starry Night Frame",
            detail: "Moon, stars, and clouds for dreamy snapshots.",
            category: .pictureFrames,
            cost: 40,
            imageName: "prop_frame_moon",
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 81, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
        PetShopItem(
            id: "decor_frame_leaves",
            name: "Garden Vine Frame",
            detail: "Climbing leaves for a calm, natural look.",
            category: .pictureFrames,
            cost: 36,
            imageName: "prop_frame_leaves",
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 75, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
        PetShopItem(
            id: "decor_frame_bear",
            name: "Teddy Bear Frame",
            detail: "A cozy bear friend guards your cutest photo.",
            category: .pictureFrames,
            cost: 44,
            imageName: "prop_frame_bear",
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 75, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
        PetShopItem(
            id: "decor_frame_ornate",
            name: "Ribbon Heart Frame",
            detail: "Ornate scallops with a ribbon banner finish.",
            category: .pictureFrames,
            cost: 48,
            imageName: "prop_frame_ornate",
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 78, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
    ]

    static func item(id: String) -> PetShopItem? {
        all.first { $0.id == id }
    }

    /// Default litter box sheet (the free blue starter) used when nothing is equipped.
    static let defaultLitterSheetName = "prop_litter_box_1_sheet"

    /// 6-frame sprite sheet for the currently equipped litter box.
    static func litterSheetName(forEquippedItemID equippedItemID: String?) -> String {
        if let equippedItemID, let item = item(id: equippedItemID), let sheet = item.imageName {
            return sheet
        }
        return starter(for: .litterBox)?.imageName ?? defaultLitterSheetName
    }

    /// Whether the equipped litter box is the self-cleaning auto box.
    static func isAutoLitter(equippedItemID: String?) -> Bool {
        guard let equippedItemID, let item = item(id: equippedItemID) else { return false }
        return item.isAutoLitter
    }

    /// Number of frames packed left-to-right in a litter box sheet.
    static let litterFrameCount = 6

    private static let litterCleanCropCache = NSCache<NSString, UIImage>()

    /// Crops the first (clean) frame out of a 6-frame litter box sheet, for
    /// market thumbnails and the inspect card.
    static func litterCleanCrop(sheetName: String) -> UIImage? {
        let key = NSString(string: "\(sheetName)#clean")
        if let cached = litterCleanCropCache.object(forKey: key) { return cached }
        guard let original = UIImage(named: sheetName), let cg = original.cgImage else { return nil }
        let frameWidth = cg.width / litterFrameCount
        guard frameWidth > 0 else { return nil }
        let rect = CGRect(x: 0, y: 0, width: frameWidth, height: cg.height)
        guard let cropped = cg.cropping(to: rect) else { return nil }
        let image = UIImage(cgImage: cropped, scale: original.scale, orientation: original.imageOrientation)
        litterCleanCropCache.setObject(image, forKey: key)
        return image
    }

    /// Clean-frame art for the litter box currently equipped (or the starter).
    static func equippedLitterCleanCrop(equippedItemID: String?) -> UIImage? {
        litterCleanCrop(sheetName: litterSheetName(forEquippedItemID: equippedItemID))
    }

    /// Floor décor IDs in a category, in catalog (declaration) order. This is the
    /// priority order used to pick the single piece shown for "one at a time"
    /// categories (beds, couch, plants), so the room never stacks duplicates and
    /// the market marks exactly one item "Active". Both the scene and the
    /// view-model must read this same order to agree on which item is active.
    static func floorItemIDs(in category: PetShopCategory) -> [String] {
        all.filter { $0.isFloorItem && $0.category == category }.map(\.id)
    }

    /// The single picture frame currently placed on the wall, if any.
    static func activePictureFrameID(in layout: PetRoomLayoutState) -> String? {
        layout.activeItem(among: pictureFrameItemIDs)
    }

    private static let frameArtCache = NSCache<NSString, UIImage>()

    /// Frame PNG with any export matte keyed to transparency.
    static func frameArtImage(named name: String) -> UIImage? {
        let key = NSString(string: name)
        if let cached = frameArtCache.object(forKey: key) { return cached }
        guard let original = UIImage(named: name) else { return nil }
        let processed = removeBlackMatteIfNeeded(from: original)
        frameArtCache.setObject(processed, forKey: key)
        return processed
    }

    /// Art for a placed picture frame, keyed by shop item id.
    static func frameArtImage(forItemID itemID: String) -> UIImage? {
        guard let imageName = item(id: itemID)?.imageName else { return nil }
        return frameArtImage(named: imageName)
    }

    /// Overscan applied to every frame window so aspect-filled photos hide edge gaps.
    private static let framePhotoOpeningScale: CGFloat = 1.06
    private static let framePhotoCenterYNudge: CGFloat = -0.012

    private struct FramePhotoOpeningOverscan {
        var width: CGFloat
        var height: CGFloat

        static func uniform(_ scale: CGFloat) -> FramePhotoOpeningOverscan {
            FramePhotoOpeningOverscan(width: scale, height: scale)
        }
    }

    /// Arch-topped frames can overscan width while keeping height tighter so photos fill
    /// the window without peeking past the vine shoulders.
    private static let framePhotoOpeningOverscanOverrides: [String: FramePhotoOpeningOverscan] = [
        "prop_frame_leaves": FramePhotoOpeningOverscan(width: 1.07, height: 0.97),
    ]

    private static func framePhotoOpeningOverscan(for imageName: String?) -> FramePhotoOpeningOverscan {
        if let imageName, let overscan = framePhotoOpeningOverscanOverrides[imageName] {
            return overscan
        }
        return .uniform(framePhotoOpeningScale)
    }

    /// Size and center for the photo layer behind a frame's transparent window.
    static func pictureFramePhotoPlacement(
        frameSize: CGSize,
        photo: UIImage,
        frameImageName: String? = nil
    ) -> (size: CGSize, position: CGPoint) {
        let layout = framePhotoLayout(for: frameImageName)
        let overscan = framePhotoOpeningOverscan(for: frameImageName)
        let openingWidth = frameSize.width * layout.openingWidthFraction * overscan.width
        let openingHeight = frameSize.height * layout.openingHeightFraction * overscan.height
        let openingCenter = CGPoint(
            x: frameSize.width * layout.centerXFraction,
            y: frameSize.height * (layout.centerYFraction + framePhotoCenterYNudge)
        )

        let displayPhoto = photo.normalizedForSpriteKit()
        let filledSize = displayPhoto.sizeAspectFilling(CGSize(width: openingWidth, height: openingHeight))
        return (filledSize, openingCenter)
    }

    private struct FramePhotoLayout {
        let openingWidthFraction: CGFloat
        let openingHeightFraction: CGFloat
        let centerXFraction: CGFloat
        let centerYFraction: CGFloat
    }

    /// Measured transparent-window layout for each frame asset (fractions of frame size).
    private static let framePhotoLayouts: [String: FramePhotoLayout] = [
        "prop_frame_cat": FramePhotoLayout(openingWidthFraction: 0.464, openingHeightFraction: 0.522, centerXFraction: 0.022, centerYFraction: -0.023),
        "prop_frame_floral": FramePhotoLayout(openingWidthFraction: 0.487, openingHeightFraction: 0.519, centerXFraction: 0.001, centerYFraction: -0.012),
        "prop_frame_hearts": FramePhotoLayout(openingWidthFraction: 0.549, openingHeightFraction: 0.562, centerXFraction: -0.003, centerYFraction: -0.034),
        "prop_frame_ribbon": FramePhotoLayout(openingWidthFraction: 0.510, openingHeightFraction: 0.562, centerXFraction: -0.009, centerYFraction: -0.034),
        "prop_frame_moon": FramePhotoLayout(openingWidthFraction: 0.504, openingHeightFraction: 0.580, centerXFraction: 0.004, centerYFraction: -0.002),
        "prop_frame_leaves": FramePhotoLayout(openingWidthFraction: 0.656, openingHeightFraction: 0.648, centerXFraction: 0.000, centerYFraction: -0.028),
        "prop_frame_bear": FramePhotoLayout(openingWidthFraction: 0.503, openingHeightFraction: 0.578, centerXFraction: 0.010, centerYFraction: -0.010),
        "prop_frame_ornate": FramePhotoLayout(openingWidthFraction: 0.566, openingHeightFraction: 0.586, centerXFraction: -0.006, centerYFraction: -0.005),
    ]

    private static func framePhotoLayout(for imageName: String?) -> FramePhotoLayout {
        guard let imageName, let layout = framePhotoLayouts[imageName] else {
            return FramePhotoLayout(
                openingWidthFraction: 0.52,
                openingHeightFraction: 0.56,
                centerXFraction: 0.004,
                centerYFraction: -0.016
            )
        }
        return layout
    }

    private static func removeBlackMatteIfNeeded(from image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let width = cg.width
        let height = cg.height
        guard width > 1, height > 1 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        func isNearBlack(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Bool {
            r <= 24 && g <= 24 && b <= 24
        }

        // Only strip a black export matte when the image border is mostly black.
        // Pre-made transparent PNGs (e.g. frame art with dark eyes or line art) must be left alone.
        var borderOpaque = 0
        var borderBlack = 0
        for x in stride(from: 0, to: width, by: max(1, width / 80)) {
            for y in [0, height - 1] {
                let i = (y * width + x) * bytesPerPixel
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                if a > 220 {
                    borderOpaque += 1
                    if isNearBlack(r, g, b) { borderBlack += 1 }
                }
            }
        }
        for y in stride(from: 0, to: height, by: max(1, height / 80)) {
            for x in [0, width - 1] {
                let i = (y * width + x) * bytesPerPixel
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                if a > 220 {
                    borderOpaque += 1
                    if isNearBlack(r, g, b) { borderBlack += 1 }
                }
            }
        }

        guard borderOpaque > 0 else { return image }
        let borderBlackRatio = Double(borderBlack) / Double(borderOpaque)
        guard borderBlackRatio >= 0.80 else { return image }

        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
            if a >= 245 && isNearBlack(r, g, b) {
                pixels[i + 3] = 0
            }
        }

        guard let out = ctx.makeImage() else { return image }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }

    static func items(in category: PetShopCategory) -> [PetShopItem] {
        all
            .filter { $0.category == category }
            .sorted { lhs, rhs in
                if lhs.cost != rhs.cost { return lhs.cost < rhs.cost }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    static func starter(for slot: PetEquipSlot) -> PetShopItem? {
        all.first { $0.equipSlot == slot && $0.isStarter }
    }

    /// Image shown in-room for an equip slot (starter art when nothing else is equipped).
    static func equippedImageName(for slot: PetEquipSlot, equippedItemID: String?) -> String? {
        if let equippedItemID, let item = item(id: equippedItemID) {
            return item.imageName
        }
        return starter(for: slot)?.imageName
    }

    static func equippedPlaceholder(for slot: PetEquipSlot, equippedItemID: String?) -> (caption: String, size: CGSize) {
        if let equippedItemID, let item = item(id: equippedItemID) {
            return (item.placeholderCaption, item.defaultSize)
        }
        if let starter = starter(for: slot) {
            return (starter.placeholderCaption, starter.defaultSize)
        }
        return ("", .zero)
    }

    static func wallColor(for id: String?) -> Color {
        Color(uiColor: wallUIColor(for: id))
    }

    static func wallUIColor(for id: String?) -> UIColor {
        switch id {
        case "wall_sage":
            return UIColor(red: 0.82, green: 0.90, blue: 0.84, alpha: 1)
        case "wall_lavender":
            return UIColor(red: 0.88, green: 0.84, blue: 0.94, alpha: 1)
        case "wall_blush", nil:
            return UIColor(red: 1.0, green: 0.93, blue: 0.95, alpha: 1)
        default:
            return UIColor(red: 1.0, green: 0.93, blue: 0.95, alpha: 1)
        }
    }

    static func collarAccentColor(for itemID: String) -> UIColor {
        switch itemID {
        case "collar_pink_bow":
            return UIColor(red: 0.92, green: 0.30, blue: 0.45, alpha: 1)
        case "collar_bell":
            return UIColor(red: 0.98, green: 0.78, blue: 0.20, alpha: 1)
        case "collar_star":
            return UIColor(red: 0.55, green: 0.42, blue: 0.92, alpha: 1)
        default:
            return UIColor(red: 0.88, green: 0.22, blue: 0.38, alpha: 1)
        }
    }
}
