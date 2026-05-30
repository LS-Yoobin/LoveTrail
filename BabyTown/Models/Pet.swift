import SwiftUI

/// The adoptable cat skins. Both share identical behavior/personality for now
/// (tuned later); only their art (`atlasName` / portrait) differs.
enum CatSkin: String, Codable, CaseIterable, Identifiable {
    case calico   // Artemis
    case cowCat   // Arabella

    var id: String { rawValue }

    /// The cat's given name, shown in the UI.
    var petName: String {
        switch self {
        case .calico: return "Artemis"
        case .cowCat: return "Arabella"
        }
    }

    /// Short descriptor shown on the adoption card.
    var breedName: String {
        switch self {
        case .calico: return "Calico"
        case .cowCat: return "Cow Cat"
        }
    }

    /// Name of the SpriteKit texture atlas folder holding this skin's animation
    /// frames (e.g. `calico.atlas`). Drop real frames in later — see plan spec.
    var atlasName: String {
        switch self {
        case .calico: return "calico"
        case .cowCat: return "cowcat"
        }
    }

    /// Asset-catalog name for the adoption-card portrait.
    var portraitAsset: String {
        switch self {
        case .calico: return "portrait_calico"
        case .cowCat: return "portrait_cowcat"
        }
    }

    /// Placeholder tint used until real sprite art is wired in.
    var placeholderColor: Color {
        switch self {
        case .calico: return Color(red: 0.95, green: 0.65, blue: 0.45) // warm calico orange
        case .cowCat: return Color(red: 0.30, green: 0.30, blue: 0.34) // cow-cat charcoal
        }
    }
}

/// A single care need (hunger, thirst, litter cleanliness, happiness), stored as
/// a value snapshot at a moment in time. The *current* value is derived by
/// applying real-time decay since `asOf` — so needs deplete even while the app
/// is closed. 100 = full/satisfied, 0 = empty (never punishing — just decays).
struct StoredNeed: Codable {
    var value: Double
    var asOf: Date

    init(value: Double = 100, asOf: Date = Date()) {
        self.value = value
        self.asOf = asOf
    }

    /// Current level after applying decay since the snapshot, clamped 0…100.
    func current(decayPerHour: Double, now: Date = Date()) -> Double {
        let hours = max(0, now.timeIntervalSince(asOf) / 3600)
        return min(100, max(0, value - hours * decayPerHour))
    }
}

/// Persisted pet state. Decoding tolerates missing keys (older save files) by
/// falling back to defaults, so the format can keep growing safely.
struct PetState: Codable {
    var adoptedSkin: CatSkin?
    var adoptedDate: Date?

    var coins: Int
    var foodServings: Int

    var hunger: StoredNeed
    var thirst: StoredNeed
    var litter: StoredNeed
    var happiness: StoredNeed

    var lastPetAt: Date?
    var lastPlayAt: Date?

    var roomLayout: PetRoomLayoutState

    init(adoptedSkin: CatSkin? = nil, adoptedDate: Date? = nil) {
        self.adoptedSkin = adoptedSkin
        self.adoptedDate = adoptedDate
        self.coins = PetEconomy.startingCoins
        self.foodServings = PetEconomy.startingFoodServings
        let now = Date()
        self.hunger = StoredNeed(value: 100, asOf: now)
        self.thirst = StoredNeed(value: 100, asOf: now)
        self.litter = StoredNeed(value: 100, asOf: now)
        self.happiness = StoredNeed(value: 100, asOf: now)
        self.lastPetAt = nil
        self.lastPlayAt = nil
        self.roomLayout = PetRoomLayoutState()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        adoptedSkin = try c.decodeIfPresent(CatSkin.self, forKey: .adoptedSkin)
        adoptedDate = try c.decodeIfPresent(Date.self, forKey: .adoptedDate)
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? PetEconomy.startingCoins
        foodServings = try c.decodeIfPresent(Int.self, forKey: .foodServings) ?? PetEconomy.startingFoodServings
        hunger = try c.decodeIfPresent(StoredNeed.self, forKey: .hunger) ?? StoredNeed(value: 100, asOf: now)
        thirst = try c.decodeIfPresent(StoredNeed.self, forKey: .thirst) ?? StoredNeed(value: 100, asOf: now)
        litter = try c.decodeIfPresent(StoredNeed.self, forKey: .litter) ?? StoredNeed(value: 100, asOf: now)
        happiness = try c.decodeIfPresent(StoredNeed.self, forKey: .happiness) ?? StoredNeed(value: 100, asOf: now)
        lastPetAt = try c.decodeIfPresent(Date.self, forKey: .lastPetAt)
        lastPlayAt = try c.decodeIfPresent(Date.self, forKey: .lastPlayAt)
        roomLayout = try c.decodeIfPresent(PetRoomLayoutState.self, forKey: .roomLayout) ?? PetRoomLayoutState()
    }
}
