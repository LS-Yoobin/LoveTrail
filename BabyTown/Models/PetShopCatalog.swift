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
    case furniture
    case catToys
    case wallColors
    case pictureFrames

    var id: String { rawValue }

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
    let isWallColor: Bool
    let isPictureFrame: Bool
    let equipSlot: PetEquipSlot?
    /// Servings added to the pantry when purchased (cat food only).
    let servingsGranted: Int?
    /// Free classic style; selected when nothing else is equipped for the slot.
    let isStarter: Bool

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
        isWallColor: Bool,
        isPictureFrame: Bool,
        equipSlot: PetEquipSlot? = nil,
        servingsGranted: Int? = nil,
        isStarter: Bool = false
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
        self.isWallColor = isWallColor
        self.isPictureFrame = isPictureFrame
        self.equipSlot = equipSlot
        self.servingsGranted = servingsGranted
        self.isStarter = isStarter
    }
}

enum PetShopCatalog {

    static let pictureFrameID = "decor_memory_frame"

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
            defaultSize: CGSize(width: 120, height: 220),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .catTree,
            isStarter: true
        ),
        PetShopItem(
            id: "cat_tree_sky",
            name: "Sky Tower",
            detail: "A taller perch for bird-watching daydreams.",
            category: .catTrees,
            cost: 48,
            imageName: nil,
            systemImage: "tree.fill",
            placeholderCaption: "Sky Tower",
            defaultSize: CGSize(width: 120, height: 240),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .catTree
        ),
        PetShopItem(
            id: "cat_tree_cozy",
            name: "Cozy Perch",
            detail: "Extra platforms for afternoon sun naps.",
            category: .catTrees,
            cost: 38,
            imageName: nil,
            systemImage: "leaf.fill",
            placeholderCaption: "Perch",
            defaultSize: CGSize(width: 110, height: 200),
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
            id: "bowl_food_rose",
            name: "Rose Ceramic Bowl",
            detail: "A deeper dish for hearty dinner portions.",
            category: .bowls,
            cost: 22,
            imageName: nil,
            systemImage: "circle.fill",
            placeholderCaption: "Rose Bowl",
            defaultSize: CGSize(width: 52, height: 40),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .foodBowl
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
            imageName: nil,
            systemImage: "drop.circle.fill",
            placeholderCaption: "Water",
            defaultSize: CGSize(width: 52, height: 40),
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
            cost: 8,
            imageName: nil,
            systemImage: "leaf.fill",
            placeholderCaption: "Kibble",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            servingsGranted: 5
        ),
        PetShopItem(
            id: "food_wet_food",
            name: "Wet Food",
            detail: "Savory pâté — 4 hearty servings.",
            category: .catFood,
            cost: 12,
            imageName: nil,
            systemImage: "drop.fill",
            placeholderCaption: "Wet",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            servingsGranted: 4
        ),
        PetShopItem(
            id: "food_dental_treats",
            name: "Dental Treats",
            detail: "Crunchy bites for shiny teeth — 3 servings.",
            category: .catFood,
            cost: 14,
            imageName: nil,
            systemImage: "sparkles",
            placeholderCaption: "Dental",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            servingsGranted: 3
        ),
        PetShopItem(
            id: "food_catnip_treats",
            name: "Catnip Treats",
            detail: "A playful sprinkle — 3 servings of fun.",
            category: .catFood,
            cost: 10,
            imageName: nil,
            systemImage: "leaf.circle.fill",
            placeholderCaption: "Catnip",
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
            detail: "The tidy box already in the corner.",
            category: .litterBoxes,
            cost: 0,
            imageName: "prop_litter_box",
            systemImage: "shippingbox.fill",
            placeholderCaption: "Litter",
            defaultSize: CGSize(width: 200, height: 120),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .litterBox,
            isStarter: true
        ),
        PetShopItem(
            id: "litter_covered",
            name: "Covered Litter Box",
            detail: "A hooded box for extra privacy.",
            category: .litterBoxes,
            cost: 28,
            imageName: nil,
            systemImage: "house.fill",
            placeholderCaption: "Covered",
            defaultSize: CGSize(width: 200, height: 130),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .litterBox
        ),
        PetShopItem(
            id: "litter_corner",
            name: "Corner Litter Box",
            detail: "Space-saving design for small rooms.",
            category: .litterBoxes,
            cost: 32,
            imageName: nil,
            systemImage: "square.split.2x1.fill",
            placeholderCaption: "Corner",
            defaultSize: CGSize(width: 180, height: 110),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: false,
            equipSlot: .litterBox
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
            id: "furniture_cat_bed",
            name: "Plush Cat Bed",
            detail: "A soft nest for afternoon naps.",
            category: .catBeds,
            cost: 35,
            imageName: "prop_cat_bed",
            systemImage: "bed.double.fill",
            placeholderCaption: "Cat Bed",
            defaultSize: CGSize(width: 90, height: 56),
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

        // MARK: Cat Toys
        PetShopItem(
            id: "toy_yarn_ball",
            name: "Yarn Ball",
            detail: "Rolls around when the cat pounces.",
            category: .catToys,
            cost: 22,
            imageName: nil,
            systemImage: "circle.fill",
            placeholderCaption: "Yarn",
            defaultSize: CGSize(width: 36, height: 36),
            isFloorItem: true,
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
            id: pictureFrameID,
            name: "Memory Frame",
            detail: "Hang a Baby Town moment on your wall.",
            category: .pictureFrames,
            cost: 32,
            imageName: nil,
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 88, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
    ]

    static func item(id: String) -> PetShopItem? {
        all.first { $0.id == id }
    }

    static func items(in category: PetShopCategory) -> [PetShopItem] {
        all.filter { $0.category == category }
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
