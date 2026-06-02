import CoreGraphics
import Foundation

/// Normalized coordinates for draggable room props (0…1 across scene size).
struct NormalizedPoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
}

/// Purchased décor + prop positions for the pet room.
struct PetRoomLayoutState: Codable, Equatable {
    /// Bumped when built-in prop defaults change so saved positions can refresh.
    var builtInLayoutVersion: Int
    var ownedItemIDs: [String]
    /// Owned items the user has stashed out of the room. Still owned, just not
    /// placed; restored from My Items via "Select".
    var stashedItemIDs: [String]
    var propPositions: [String: NormalizedPoint]
    /// Props the user has flipped horizontally (mirrored) during customization.
    var flippedItemIDs: [String]
    var wallColorID: String?
    var pictureFrameMomentID: UUID?
    /// Active cosmetic variant per equip slot (`PetEquipSlot.rawValue` → shop item id).
    var equippedItems: [String: String]

    private static let currentBuiltInLayoutVersion = 2

    init(
        builtInLayoutVersion: Int = currentBuiltInLayoutVersion,
        ownedItemIDs: [String] = [],
        stashedItemIDs: [String] = [],
        propPositions: [String: NormalizedPoint] = [:],
        flippedItemIDs: [String] = [],
        wallColorID: String? = nil,
        pictureFrameMomentID: UUID? = nil,
        equippedItems: [String: String] = [:]
    ) {
        self.builtInLayoutVersion = builtInLayoutVersion
        self.ownedItemIDs = ownedItemIDs
        self.stashedItemIDs = stashedItemIDs
        self.propPositions = propPositions
        self.flippedItemIDs = flippedItemIDs
        self.wallColorID = wallColorID
        self.pictureFrameMomentID = pictureFrameMomentID
        self.equippedItems = equippedItems
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        builtInLayoutVersion = try c.decodeIfPresent(Int.self, forKey: .builtInLayoutVersion) ?? 1
        ownedItemIDs = try c.decodeIfPresent([String].self, forKey: .ownedItemIDs) ?? []
        stashedItemIDs = try c.decodeIfPresent([String].self, forKey: .stashedItemIDs) ?? []
        propPositions = try c.decodeIfPresent([String: NormalizedPoint].self, forKey: .propPositions) ?? [:]
        flippedItemIDs = try c.decodeIfPresent([String].self, forKey: .flippedItemIDs) ?? []
        wallColorID = try c.decodeIfPresent(String.self, forKey: .wallColorID)
        pictureFrameMomentID = try c.decodeIfPresent(UUID.self, forKey: .pictureFrameMomentID)
        equippedItems = try c.decodeIfPresent([String: String].self, forKey: .equippedItems) ?? [:]
    }

    mutating func migrateBuiltInLayoutIfNeeded() {
        guard builtInLayoutVersion < Self.currentBuiltInLayoutVersion else { return }
        for key in [
            PetRoomPropKey.catTree,
            PetRoomPropKey.foodBowl,
            PetRoomPropKey.waterBowl,
            PetRoomPropKey.litterBox
        ] {
            propPositions.removeValue(forKey: key)
        }
        builtInLayoutVersion = Self.currentBuiltInLayoutVersion
    }

    func owns(_ itemID: String) -> Bool {
        ownedItemIDs.contains(itemID)
    }

    func isStashed(_ itemID: String) -> Bool {
        stashedItemIDs.contains(itemID)
    }

    func isFlipped(_ itemID: String) -> Bool {
        flippedItemIDs.contains(itemID)
    }

    func equippedItemID(for slot: PetEquipSlot) -> String? {
        equippedItems[slot.rawValue]
    }

    mutating func setEquippedItem(_ itemID: String?, for slot: PetEquipSlot) {
        if let itemID {
            equippedItems[slot.rawValue] = itemID
        } else {
            equippedItems.removeValue(forKey: slot.rawValue)
        }
    }
}

/// Keys for built-in and shop floor props in `propPositions`.
enum PetRoomPropKey {
    static let catTree = "prop_cat_tree"
    static let foodBowl = "prop_food_bowl"
    static let waterBowl = "prop_water_bowl"
    static let litterBox = "prop_litter_box"
    static let couch = "furniture_couch"
    static let catBed = "furniture_cat_bed"
    static let yarnBall = "toy_yarn_ball"
}
