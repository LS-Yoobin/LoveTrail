import SwiftUI
import Combine

/// The outcome of a care action: how many coins were awarded (0 if none), and a
/// friendly reason when the action didn't reward anything (e.g. "Not hungry yet").
struct CareResult {
    var coinsAwarded: Int
    var blockedReason: String?

    static let none = CareResult(coinsAwarded: 0, blockedReason: nil)
}

/// Owns the adopted-pet state + care economy, persisting on every change,
/// mirroring the app's `@Published` + `didSet` → `DataPersistenceManager`
/// pattern (see `HomeViewModel`).
@MainActor
final class PetViewModel: ObservableObject {

    @Published var state: PetState {
        didSet { DataPersistenceManager.shared.savePetState(state) }
    }

    /// Last coin award, surfaced to the UI for the "+N 🪙" feedback animation.
    @Published var lastAward: (amount: Int, id: UUID)?

    init() {
        var loaded = DataPersistenceManager.shared.loadPetState()
        let previousLayoutVersion = loaded.roomLayout.builtInLayoutVersion
        loaded.roomLayout.migrateBuiltInLayoutIfNeeded()
        self.state = loaded
        if loaded.roomLayout.builtInLayoutVersion != previousLayoutVersion {
            DataPersistenceManager.shared.savePetState(loaded)
        }
    }

    // MARK: Adoption

    var isAdopted: Bool { state.adoptedSkin != nil }
    var adoptedSkin: CatSkin? { state.adoptedSkin }

    func adopt(_ skin: CatSkin) {
        state = PetState(adoptedSkin: skin, adoptedDate: Date())
    }

    /// Returns to the selection screen (lets the user choose a different cat).
    func releasePet() {
        state = PetState()
    }

    // MARK: Live need values (decay applied at read), 0…100

    var coins: Int { state.coins }
    var foodServings: Int { state.foodServings }

    var hunger: Int { Int(state.hunger.current(decayPerHour: PetEconomy.hungerDecayPerHour).rounded()) }
    var thirst: Int { Int(state.thirst.current(decayPerHour: PetEconomy.thirstDecayPerHour).rounded()) }
    var litter: Int { Int(state.litter.current(decayPerHour: PetEconomy.litterDecayPerHour).rounded()) }
    var happiness: Int { Int(state.happiness.current(decayPerHour: PetEconomy.happinessDecayPerHour).rounded()) }

    // MARK: Care actions
    //
    // Each mutates `state` (persisted via didSet). The animation/laser is always
    // allowed for delight; coins are only awarded when the task is "needed" or
    // off cooldown.

    func pet() -> CareResult {
        bumpHappiness(by: PetEconomy.happinessFromPet)
        let now = Date()
        if let last = state.lastPetAt {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < PetEconomy.petCooldown {
                let remaining = PetEconomy.petCooldown - elapsed
                return CareResult(
                    coinsAwarded: 0,
                    blockedReason: PetEconomy.petCooldownMessage(remaining: remaining)
                )
            }
        }
        state.lastPetAt = now
        return award(.pet)
    }

    /// Whether petting the cat would award coins right now.
    func canEarnPetCoins(now: Date = Date()) -> Bool {
        guard let last = state.lastPetAt else { return true }
        return now.timeIntervalSince(last) >= PetEconomy.petCooldown
    }

    func fillWater() -> CareResult {
        let level = state.thirst.current(decayPerHour: PetEconomy.thirstDecayPerHour)
        guard level < PetEconomy.feedThirstGate else {
            return CareResult(coinsAwarded: 0, blockedReason: "The bowl's still full")
        }
        state.thirst = StoredNeed(value: 100)
        return award(.fillWater)
    }

    func feed() -> CareResult {
        let level = state.hunger.current(decayPerHour: PetEconomy.hungerDecayPerHour)
        guard state.foodServings > 0 else {
            return CareResult(coinsAwarded: 0, blockedReason: "Out of food — tap Refill and Buy Food")
        }
        guard level < PetEconomy.feedThirstGate else {
            return CareResult(coinsAwarded: 0, blockedReason: "The bowl's still full")
        }
        state.foodServings -= 1
        state.hunger = StoredNeed(value: 100)
        bumpHappiness(by: PetEconomy.happinessFromFeed)
        return award(.feed)
    }

    /// Refills the food bowl when needed; buys a food pack first if servings are empty.
    func refillAndBuyFood() -> CareResult {
        let level = state.hunger.current(decayPerHour: PetEconomy.hungerDecayPerHour)
        let needsRefill = level < PetEconomy.feedThirstGate

        if needsRefill {
            if state.foodServings == 0 {
                let buyResult = buyFood()
                if buyResult.blockedReason != nil { return buyResult }
            }
            return feed()
        }

        return buyFood()
    }

    func buyFood() -> CareResult {
        guard state.coins >= PetEconomy.foodPackCost else {
            return CareResult(coinsAwarded: 0, blockedReason: "Not enough coins for food")
        }
        state.coins -= PetEconomy.foodPackCost
        state.foodServings += PetEconomy.foodPackServings
        return CareResult(coinsAwarded: 0, blockedReason: nil)
    }

    /// Happiness boost when laser play starts; coins come from `completePlay()`.
    func beginPlaySession() {
        bumpHappiness(by: PetEconomy.happinessFromPlay)
    }

    /// Awards play coins after the laser bar fills; gated by a 2-hour cooldown.
    func completePlay() -> CareResult {
        let now = Date()
        if let last = state.lastPlayAt {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < PetEconomy.playCooldown {
                let remaining = PetEconomy.playCooldown - elapsed
                return CareResult(
                    coinsAwarded: 0,
                    blockedReason: PetEconomy.playCooldownMessage(remaining: remaining)
                )
            }
        }
        state.lastPlayAt = now
        return award(.play)
    }

    func canEarnPlayCoins(now: Date = Date()) -> Bool {
        guard let last = state.lastPlayAt else { return true }
        return now.timeIntervalSince(last) >= PetEconomy.playCooldown
    }

    func cleanLitter() -> CareResult {
        let level = state.litter.current(decayPerHour: PetEconomy.litterDecayPerHour)
        guard level < PetEconomy.litterCleanGate else {
            return CareResult(coinsAwarded: 0, blockedReason: "The litter's already clean")
        }
        state.litter = StoredNeed(value: 100)
        return award(.cleanLitter)
    }

    // MARK: Helpers

    private func award(_ task: PetEconomy.CareTask) -> CareResult {
        let amount = task.coinReward
        state.coins += amount
        lastAward = (amount, UUID())
        return CareResult(coinsAwarded: amount, blockedReason: nil)
    }

    /// Raises happiness from its current (decayed) value, re-snapshotting `asOf`.
    private func bumpHappiness(by amount: Double) {
        let current = state.happiness.current(decayPerHour: PetEconomy.happinessDecayPerHour)
        state.happiness = StoredNeed(value: min(100, current + amount))
    }

    // MARK: - Room shop & layout

    var roomLayout: PetRoomLayoutState { state.roomLayout }

    func ownsShopItem(_ itemID: String) -> Bool {
        state.roomLayout.owns(itemID)
    }

    func isShopItemSelected(_ itemID: String) -> Bool {
        guard let item = PetShopCatalog.item(id: itemID) else { return false }
        if item.isWallColor {
            let activeID = state.roomLayout.wallColorID ?? "wall_blush"
            return itemID == activeID
        }
        if item.isPictureFrame {
            return state.roomLayout.owns(itemID) && state.roomLayout.pictureFrameMomentID != nil
        }
        return state.roomLayout.owns(itemID)
    }

    func pictureFrameImage() -> UIImage? {
        guard let id = state.roomLayout.pictureFrameMomentID else { return nil }
        return PetGalleryPhotoLoader.image(for: id)
    }

    func updatePropPositions(_ positions: [String: NormalizedPoint]) {
        state.roomLayout.propPositions = positions
    }

    /// Purchases or selects a shop item. Returns whether the memory-frame picker should open next.
    func purchaseShopItem(_ itemID: String) -> (result: CareResult, openFramePicker: Bool) {
        guard let item = PetShopCatalog.item(id: itemID) else {
            return (.none, false)
        }

        if state.roomLayout.owns(itemID) {
            if item.isWallColor {
                state.roomLayout.wallColorID = itemID
            }
            let openPicker = item.isPictureFrame && state.roomLayout.pictureFrameMomentID == nil
            return (.none, openPicker)
        }

        guard state.coins >= item.cost else {
            return (CareResult(coinsAwarded: 0, blockedReason: "Not enough coins"), false)
        }

        state.coins -= item.cost
        state.roomLayout.ownedItemIDs.append(itemID)

        if item.isWallColor {
            state.roomLayout.wallColorID = itemID
        }

        let openPicker = item.isPictureFrame && state.roomLayout.pictureFrameMomentID == nil
        return (.none, openPicker)
    }

    func setPictureFrameMoment(_ momentID: UUID) {
        state.roomLayout.pictureFrameMomentID = momentID
        if !state.roomLayout.owns(PetShopCatalog.pictureFrameID) {
            state.roomLayout.ownedItemIDs.append(PetShopCatalog.pictureFrameID)
        }
    }
}
