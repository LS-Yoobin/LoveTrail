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
    /// Selected gallery photo per picture-frame shop item id.
    var pictureFrameMoments: [String: UUID]
    /// Active cosmetic variant per equip slot (`PetEquipSlot.rawValue` → shop item id).
    var equippedItems: [String: String]
    /// Active toy used in the play hotbar (`PetShopItem.id`), nil = laser pointer.
    var selectedPlayToyID: String?
    /// Most-recently-used play toys, newest first (`PetShopItem.id`).
    var playToyUsageOrder: [String]

    private static let currentBuiltInLayoutVersion = 2

    init(
        builtInLayoutVersion: Int = currentBuiltInLayoutVersion,
        ownedItemIDs: [String] = [],
        stashedItemIDs: [String] = [],
        propPositions: [String: NormalizedPoint] = [:],
        flippedItemIDs: [String] = [],
        wallColorID: String? = nil,
        pictureFrameMoments: [String: UUID] = [:],
        equippedItems: [String: String] = [:],
        selectedPlayToyID: String? = nil,
        playToyUsageOrder: [String] = []
    ) {
        self.builtInLayoutVersion = builtInLayoutVersion
        self.ownedItemIDs = ownedItemIDs
        self.stashedItemIDs = stashedItemIDs
        self.propPositions = propPositions
        self.flippedItemIDs = flippedItemIDs
        self.wallColorID = wallColorID
        self.pictureFrameMoments = pictureFrameMoments
        self.equippedItems = equippedItems
        self.selectedPlayToyID = selectedPlayToyID
        self.playToyUsageOrder = playToyUsageOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        builtInLayoutVersion = try c.decodeIfPresent(Int.self, forKey: .builtInLayoutVersion) ?? 1
        ownedItemIDs = try c.decodeIfPresent([String].self, forKey: .ownedItemIDs) ?? []
        stashedItemIDs = try c.decodeIfPresent([String].self, forKey: .stashedItemIDs) ?? []
        propPositions = try c.decodeIfPresent([String: NormalizedPoint].self, forKey: .propPositions) ?? [:]
        flippedItemIDs = try c.decodeIfPresent([String].self, forKey: .flippedItemIDs) ?? []
        wallColorID = try c.decodeIfPresent(String.self, forKey: .wallColorID)
        pictureFrameMoments = try c.decodeIfPresent([String: UUID].self, forKey: .pictureFrameMoments) ?? [:]
        if pictureFrameMoments.isEmpty,
           let legacyMoment = try c.decodeIfPresent(UUID.self, forKey: .pictureFrameMomentID) {
            pictureFrameMoments[PetShopCatalog.legacyPictureFrameID] = legacyMoment
        }
        equippedItems = try c.decodeIfPresent([String: String].self, forKey: .equippedItems) ?? [:]
        selectedPlayToyID = try c.decodeIfPresent(String.self, forKey: .selectedPlayToyID)
        playToyUsageOrder = try c.decodeIfPresent([String].self, forKey: .playToyUsageOrder) ?? []
        migratePictureFrameLayoutIfNeeded()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(builtInLayoutVersion, forKey: .builtInLayoutVersion)
        try c.encode(ownedItemIDs, forKey: .ownedItemIDs)
        try c.encode(stashedItemIDs, forKey: .stashedItemIDs)
        try c.encode(propPositions, forKey: .propPositions)
        try c.encode(flippedItemIDs, forKey: .flippedItemIDs)
        try c.encodeIfPresent(wallColorID, forKey: .wallColorID)
        try c.encode(pictureFrameMoments, forKey: .pictureFrameMoments)
        try c.encode(equippedItems, forKey: .equippedItems)
        try c.encodeIfPresent(selectedPlayToyID, forKey: .selectedPlayToyID)
        try c.encode(playToyUsageOrder, forKey: .playToyUsageOrder)
    }

    private enum CodingKeys: String, CodingKey {
        case builtInLayoutVersion
        case ownedItemIDs
        case stashedItemIDs
        case propPositions
        case flippedItemIDs
        case wallColorID
        case pictureFrameMoments
        case pictureFrameMomentID
        case equippedItems
        case selectedPlayToyID
        case playToyUsageOrder
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

    /// Moves legacy single-frame saves onto the new per-frame ids.
    mutating func migratePictureFrameLayoutIfNeeded() {
        let legacyID = PetShopCatalog.legacyPictureFrameID
        let defaultID = PetShopCatalog.defaultPictureFrameID

        if let legacyPosition = propPositions.removeValue(forKey: legacyID) {
            if propPositions[defaultID] == nil {
                propPositions[defaultID] = legacyPosition
            }
        }

        if ownedItemIDs.contains(legacyID) {
            ownedItemIDs.removeAll { $0 == legacyID }
            if !ownedItemIDs.contains(defaultID) {
                ownedItemIDs.append(defaultID)
            }
        }

        if stashedItemIDs.contains(legacyID) {
            stashedItemIDs.removeAll { $0 == legacyID }
            if !stashedItemIDs.contains(defaultID) {
                stashedItemIDs.append(defaultID)
            }
        }

        if flippedItemIDs.contains(legacyID) {
            flippedItemIDs.removeAll { $0 == legacyID }
            if !flippedItemIDs.contains(defaultID) {
                flippedItemIDs.append(defaultID)
            }
        }

        if let legacyMoment = pictureFrameMoments.removeValue(forKey: legacyID) {
            if pictureFrameMoments[defaultID] == nil {
                pictureFrameMoments[defaultID] = legacyMoment
            }
        }
    }

    func pictureFrameMoment(for itemID: String) -> UUID? {
        pictureFrameMoments[itemID]
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

    /// Among the given candidates (in priority order), the single item that is
    /// owned and currently placed (not stashed). Used to enforce "one piece per
    /// category" for floor décor so duplicates never stack in the room, even when
    /// several are owned. Returns nil when none are placed.
    func activeItem(among candidateIDs: [String]) -> String? {
        candidateIDs.first { owns($0) && !isStashed($0) }
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
    static let catBed = "furniture_cat_bed_1"
    static let yarnBall = "toy_yarn_ball"
}
