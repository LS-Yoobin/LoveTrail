import SwiftUI

/// The adoptable cat skins. Both share identical behavior/personality for now
/// (tuned later); only their art (`atlasName` / portrait) differs.
enum CatSkin: String, Codable, CaseIterable, Identifiable {
    case calico   // Artemis
    case cowCat   // Arabella
    case bombay   // Spunky

    var id: String { rawValue }

    /// Premium pets require Covela Forever before adoption.
    var requiresForeverUnlock: Bool {
        switch self {
        case .bombay: return true
        case .calico, .cowCat: return false
        }
    }

    /// The cat's given name, shown in the UI.
    var petName: String {
        switch self {
        case .calico: return "Artemis"
        case .cowCat: return "Arabella"
        case .bombay: return "Spunky"
        }
    }

    /// Short descriptor shown on the adoption card and profile.
    var breedName: String {
        switch self {
        case .calico: return "Calico"
        case .cowCat: return "Cow Cat"
        case .bombay: return "Bombay"
        }
    }

    /// Shelter backstory for the Visit Pet profile card.
    var originStory: String {
        switch self {
        case .calico:
            return """
            At the shelter, Artemis was only six months old, already a mama to a whole litter of kittens. One by one, her babies found loving homes, until the room grew quiet and she was the only one left. It was a lonely chapter, but every kitten's happy ending led to hers: you brought her home to your town. She is Baby Town's gentlest soul, so sweet she would never hurt a fly.
            """
        case .cowCat:
            return """
            Arabella was still a tiny kitten when she first stepped into the world of people, all goofy ears, a silly little face, and far more confidence than one cat should have. You saw her and knew she belonged in your town right away. She has not slowed down since. Baby Town's resident troublemaker, happy to devour anything and everything in her path.
            """
        case .bombay:
            return """
            Spunky was found on the side of the highway, tied inside a trash bag and left behind like her life did not matter. A passerby spotted the bag moving, cut her free, and rushed her to foster care that same night. Four months later, she has healed, she is playful again, and she is ready to meet a loving owner who will never let her go.
            """
        }
    }

    /// Name of the SpriteKit texture atlas folder holding this skin's animation
    /// frames (e.g. `calico.atlas`). Drop real frames in later — see plan spec.
    var atlasName: String {
        switch self {
        case .calico: return "calico"
        case .cowCat: return "cowcat"
        case .bombay: return "bombay"
        }
    }

    /// Asset-catalog name for the adoption-card portrait.
    var portraitAsset: String {
        switch self {
        case .calico: return "portrait_calico"
        case .cowCat: return "portrait_cowcat"
        case .bombay: return "portrait_bombay"
        }
    }

    /// Sitting pose used on the Visit Pet profile card.
    var profileSitAsset: String {
        switch self {
        case .calico: return "profile_calico_sit"
        case .cowCat: return "profile_cowcat_sit"
        case .bombay: return "profile_bombay_sit"
        }
    }

    /// Placeholder tint used until real sprite art is wired in.
    var placeholderColor: Color {
        switch self {
        case .calico: return Color(red: 0.95, green: 0.65, blue: 0.45) // warm calico orange
        case .cowCat: return Color(red: 0.30, green: 0.30, blue: 0.34) // cow-cat charcoal
        case .bombay: return Color(red: 0.12, green: 0.10, blue: 0.14) // Bombay black
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
    private enum CodingKeys: String, CodingKey {
        case adoptedSkin, adoptedDate, coins, foodServings
        case ownedSkins
        case hunger, thirst, litter, happiness
        case lastPetAt, lastPlayAt, lastPlantWaterAt, customPetNames, lastPetInteractionAt
        case roomLayout
        case roomLayoutsByPet
        case toiletPaperMessByPet
        case trickTrainingByPet
        case trickTraining
        case hasSeenPetRoomTutorial
        case lastCheckInDate, checkInStreak
    }

    var adoptedSkin: CatSkin?
    var adoptedDate: Date?
    var ownedSkins: [CatSkin]

    var coins: Int
    var foodServings: Int

    var hunger: StoredNeed
    var thirst: StoredNeed
    var litter: StoredNeed
    var happiness: StoredNeed

    var lastPetAt: Date?
    var lastPlayAt: Date?
    /// Most recent time the user touched the pet/pet-room (room opened or any
    /// care action). Drives the 7-day "pet misses you" notification timer.
    var lastPetInteractionAt: Date?
    /// Last time each plant was watered for coins, keyed by plant item id.
    var lastPlantWaterAt: [String: Date]

    /// Custom display names keyed by `CatSkin.rawValue`.
    var customPetNames: [String: String]

    /// Per-pet room décor + prop layout, keyed by `CatSkin.rawValue`.
    var roomLayoutsByPet: [String: PetRoomLayoutState]

    /// Per-pet voice-command trick training progress, keyed by `CatSkin.rawValue`.
    var trickTrainingByPet: [String: PetTrickTrainingState]
    /// Per-pet toilet-paper mess scheduler + active state.
    var toiletPaperMessByPet: [String: ToiletPaperMessState]

    /// One-time pet room walkthrough shown after the user's first adoption.
    var hasSeenPetRoomTutorial: Bool

    var lastCheckInDate: Date?
    var checkInStreak: Int

    init(adoptedSkin: CatSkin? = nil, adoptedDate: Date? = nil) {
        self.adoptedSkin = adoptedSkin
        self.adoptedDate = adoptedDate
        self.ownedSkins = adoptedSkin.map { [$0] } ?? []
        self.coins = PetEconomy.startingCoins
        self.foodServings = PetEconomy.startingFoodServings
        let now = Date()
        self.hunger = StoredNeed(value: 100, asOf: now)
        self.thirst = StoredNeed(value: 100, asOf: now)
        self.litter = StoredNeed(value: 100, asOf: now)
        self.happiness = StoredNeed(value: 100, asOf: now)
        self.lastPetAt = nil
        self.lastPlayAt = nil
        self.lastPetInteractionAt = nil
        self.lastPlantWaterAt = [:]
        self.customPetNames = [:]
        self.roomLayoutsByPet = [:]
        self.trickTrainingByPet = [:]
        self.toiletPaperMessByPet = [:]
        self.hasSeenPetRoomTutorial = false
        self.lastCheckInDate = nil
        self.checkInStreak = 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(adoptedSkin, forKey: .adoptedSkin)
        try c.encodeIfPresent(adoptedDate, forKey: .adoptedDate)
        try c.encode(ownedSkins, forKey: .ownedSkins)
        try c.encode(coins, forKey: .coins)
        try c.encode(foodServings, forKey: .foodServings)
        try c.encode(hunger, forKey: .hunger)
        try c.encode(thirst, forKey: .thirst)
        try c.encode(litter, forKey: .litter)
        try c.encode(happiness, forKey: .happiness)
        try c.encodeIfPresent(lastPetAt, forKey: .lastPetAt)
        try c.encodeIfPresent(lastPlayAt, forKey: .lastPlayAt)
        try c.encodeIfPresent(lastPetInteractionAt, forKey: .lastPetInteractionAt)
        try c.encode(lastPlantWaterAt, forKey: .lastPlantWaterAt)
        try c.encode(customPetNames, forKey: .customPetNames)
        try c.encode(roomLayoutsByPet, forKey: .roomLayoutsByPet)
        try c.encode(trickTrainingByPet, forKey: .trickTrainingByPet)
        try c.encode(toiletPaperMessByPet, forKey: .toiletPaperMessByPet)
        try c.encode(hasSeenPetRoomTutorial, forKey: .hasSeenPetRoomTutorial)
        try c.encodeIfPresent(lastCheckInDate, forKey: .lastCheckInDate)
        try c.encode(checkInStreak, forKey: .checkInStreak)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        adoptedSkin = try c.decodeIfPresent(CatSkin.self, forKey: .adoptedSkin)
        adoptedDate = try c.decodeIfPresent(Date.self, forKey: .adoptedDate)
        ownedSkins = try c.decodeIfPresent([CatSkin].self, forKey: .ownedSkins) ?? []
        if ownedSkins.isEmpty, let adoptedSkin {
            ownedSkins = [adoptedSkin]
        }
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? PetEconomy.startingCoins
        foodServings = try c.decodeIfPresent(Int.self, forKey: .foodServings) ?? PetEconomy.startingFoodServings
        hunger = try c.decodeIfPresent(StoredNeed.self, forKey: .hunger) ?? StoredNeed(value: 100, asOf: now)
        thirst = try c.decodeIfPresent(StoredNeed.self, forKey: .thirst) ?? StoredNeed(value: 100, asOf: now)
        litter = try c.decodeIfPresent(StoredNeed.self, forKey: .litter) ?? StoredNeed(value: 100, asOf: now)
        happiness = try c.decodeIfPresent(StoredNeed.self, forKey: .happiness) ?? StoredNeed(value: 100, asOf: now)
        lastPetAt = try c.decodeIfPresent(Date.self, forKey: .lastPetAt)
        lastPlayAt = try c.decodeIfPresent(Date.self, forKey: .lastPlayAt)
        lastPetInteractionAt = try c.decodeIfPresent(Date.self, forKey: .lastPetInteractionAt)
        lastPlantWaterAt = try c.decodeIfPresent([String: Date].self, forKey: .lastPlantWaterAt) ?? [:]
        customPetNames = try c.decodeIfPresent([String: String].self, forKey: .customPetNames) ?? [:]
        roomLayoutsByPet = try c.decodeIfPresent([String: PetRoomLayoutState].self, forKey: .roomLayoutsByPet) ?? [:]
        if roomLayoutsByPet.isEmpty,
           let legacy = try c.decodeIfPresent(PetRoomLayoutState.self, forKey: .roomLayout) {
            if let skin = adoptedSkin {
                roomLayoutsByPet[skin.rawValue] = legacy
            } else {
                for skin in CatSkin.allCases {
                    roomLayoutsByPet[skin.rawValue] = legacy
                }
            }
        }

        trickTrainingByPet = try c.decodeIfPresent([String: PetTrickTrainingState].self, forKey: .trickTrainingByPet) ?? [:]
        toiletPaperMessByPet = try c.decodeIfPresent([String: ToiletPaperMessState].self, forKey: .toiletPaperMessByPet) ?? [:]
        if let seen = try c.decodeIfPresent(Bool.self, forKey: .hasSeenPetRoomTutorial) {
            hasSeenPetRoomTutorial = seen
        } else {
            // Existing adopters before this walkthrough shipped should not see it.
            hasSeenPetRoomTutorial = !ownedSkins.isEmpty
        }
        lastCheckInDate = try c.decodeIfPresent(Date.self, forKey: .lastCheckInDate)
        checkInStreak = try c.decodeIfPresent(Int.self, forKey: .checkInStreak) ?? 0
        if trickTrainingByPet.isEmpty {
            let legacyTraining = try c.decodeIfPresent(PetTrickTrainingState.self, forKey: .trickTraining)
            if let adoptedSkin {
                trickTrainingByPet[adoptedSkin.rawValue] = legacyTraining ?? PetTrickTrainingState()
            } else if let legacyTraining {
                for skin in CatSkin.allCases {
                    trickTrainingByPet[skin.rawValue] = legacyTraining
                }
            }
        }
    }

    func toiletPaperMessState(for skin: CatSkin) -> ToiletPaperMessState {
        toiletPaperMessByPet[skin.rawValue] ?? ToiletPaperMessState()
    }

    mutating func updateToiletPaperMessState(for skin: CatSkin, _ body: (inout ToiletPaperMessState) -> Void) {
        var mess = toiletPaperMessState(for: skin)
        body(&mess)
        toiletPaperMessByPet[skin.rawValue] = mess
    }

    func roomLayout(for skin: CatSkin) -> PetRoomLayoutState {
        roomLayoutsByPet[skin.rawValue] ?? PetRoomLayoutState()
    }

    mutating func updateRoomLayout(for skin: CatSkin, _ body: (inout PetRoomLayoutState) -> Void) {
        var layout = roomLayout(for: skin)
        body(&layout)
        roomLayoutsByPet[skin.rawValue] = layout
    }

    mutating func updateActiveRoomLayout(_ body: (inout PetRoomLayoutState) -> Void) {
        guard let skin = adoptedSkin else { return }
        updateRoomLayout(for: skin, body)
    }

    func trickTraining(for skin: CatSkin) -> PetTrickTrainingState {
        trickTrainingByPet[skin.rawValue] ?? PetTrickTrainingState()
    }

    mutating func updateTrickTraining(for skin: CatSkin, _ body: (inout PetTrickTrainingState) -> Void) {
        var training = trickTraining(for: skin)
        body(&training)
        trickTrainingByPet[skin.rawValue] = training
    }

    mutating func migrateAllRoomLayoutsIfNeeded() -> Bool {
        var changed = false
        for key in roomLayoutsByPet.keys {
            let previous = roomLayoutsByPet[key]?.builtInLayoutVersion
            roomLayoutsByPet[key]?.migrateBuiltInLayoutIfNeeded()
            if roomLayoutsByPet[key]?.builtInLayoutVersion != previous {
                changed = true
            }
        }
        return changed
    }
}

/// Weekly schedule + active-state tracker for the random toilet-paper mess.
struct ToiletPaperMessState: Codable, Equatable {
    /// Year/week key in Pacific time (e.g. "2026-W23").
    var weekKey: String
    /// Randomly generated mess times (seconds since 1970) for the active week.
    var scheduledEventTimes: [TimeInterval]
    /// Event indices already cleaned up by the user.
    var consumedEventIndices: [Int]
    /// Current visible mess event index, nil when no mess is on the floor.
    var activeEventIndex: Int?

    init(
        weekKey: String = "",
        scheduledEventTimes: [TimeInterval] = [],
        consumedEventIndices: [Int] = [],
        activeEventIndex: Int? = nil
    ) {
        self.weekKey = weekKey
        self.scheduledEventTimes = scheduledEventTimes
        self.consumedEventIndices = consumedEventIndices
        self.activeEventIndex = activeEventIndex
    }
}
