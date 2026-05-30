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
    var propPositions: [String: NormalizedPoint]
    var wallColorID: String?
    var pictureFrameMomentID: UUID?

    private static let currentBuiltInLayoutVersion = 2

    init(
        builtInLayoutVersion: Int = currentBuiltInLayoutVersion,
        ownedItemIDs: [String] = [],
        propPositions: [String: NormalizedPoint] = [:],
        wallColorID: String? = nil,
        pictureFrameMomentID: UUID? = nil
    ) {
        self.builtInLayoutVersion = builtInLayoutVersion
        self.ownedItemIDs = ownedItemIDs
        self.propPositions = propPositions
        self.wallColorID = wallColorID
        self.pictureFrameMomentID = pictureFrameMomentID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        builtInLayoutVersion = try c.decodeIfPresent(Int.self, forKey: .builtInLayoutVersion) ?? 1
        ownedItemIDs = try c.decodeIfPresent([String].self, forKey: .ownedItemIDs) ?? []
        propPositions = try c.decodeIfPresent([String: NormalizedPoint].self, forKey: .propPositions) ?? [:]
        wallColorID = try c.decodeIfPresent(String.self, forKey: .wallColorID)
        pictureFrameMomentID = try c.decodeIfPresent(UUID.self, forKey: .pictureFrameMomentID)
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
