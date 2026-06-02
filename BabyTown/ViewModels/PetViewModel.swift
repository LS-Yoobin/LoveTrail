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
        let layoutsChanged = loaded.migrateAllRoomLayoutsIfNeeded()
        self.state = loaded
        if layoutsChanged {
            DataPersistenceManager.shared.savePetState(loaded)
        }
    }

    // MARK: Adoption

    var isAdopted: Bool { state.adoptedSkin != nil }
    var adoptedSkin: CatSkin? { state.adoptedSkin }

    func adopt(_ skin: CatSkin) {
        state.adoptedSkin = skin
        if state.adoptedDate == nil {
            state.adoptedDate = Date()
        }
        if state.roomLayoutsByPet[skin.rawValue] == nil {
            state.roomLayoutsByPet[skin.rawValue] = PetRoomLayoutState()
        }
    }

    func displayName(for skin: CatSkin) -> String {
        if let custom = state.customPetNames[skin.rawValue]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return skin.petName
    }

    func renamePet(for skin: CatSkin, to rawName: String) -> CareResult {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CareResult(coinsAwarded: 0, blockedReason: "Enter a name")
        }
        guard trimmed.count <= 24 else {
            return CareResult(coinsAwarded: 0, blockedReason: "Keep it under 24 characters")
        }
        guard trimmed != displayName(for: skin) else {
            return CareResult(coinsAwarded: 0, blockedReason: "That's already their name")
        }
        guard state.coins >= PetEconomy.renameCost else {
            return CareResult(coinsAwarded: 0, blockedReason: "Not enough coins")
        }

        state.coins -= PetEconomy.renameCost
        state.customPetNames[skin.rawValue] = trimmed
        return .none
    }

    /// Returns to the selection screen so the user can visit another adopted cat.
    /// Per-pet room layouts, names, and care progress are preserved.
    func releasePet() {
        state.adoptedSkin = nil
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
            return CareResult(coinsAwarded: 0, blockedReason: "Out of food — buy some in the Market")
        }
        guard level < PetEconomy.feedThirstGate else {
            return CareResult(coinsAwarded: 0, blockedReason: "The bowl's still full")
        }
        state.foodServings -= 1
        state.hunger = StoredNeed(value: 100)
        bumpHappiness(by: PetEconomy.happinessFromFeed)
        return award(.feed)
    }

    /// Puts a serving from the pantry into the food bowl.
    func refillFood() -> CareResult {
        feed()
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

    var roomLayout: PetRoomLayoutState {
        guard let skin = state.adoptedSkin else { return PetRoomLayoutState() }
        return state.roomLayout(for: skin)
    }

    private func mutateActiveRoomLayout(_ transform: (inout PetRoomLayoutState) -> Void) {
        state.updateActiveRoomLayout(transform)
    }

    func ownsShopItem(_ itemID: String) -> Bool {
        if let item = PetShopCatalog.item(id: itemID), item.isStarter {
            return true
        }
        return roomLayout.owns(itemID)
    }

    func isShopItemSelected(_ itemID: String) -> Bool {
        guard let item = PetShopCatalog.item(id: itemID) else { return false }
        let layout = roomLayout
        if let slot = item.equipSlot {
            let equipped = layout.equippedItemID(for: slot)
            if item.isStarter { return equipped == nil }
            return equipped == itemID
        }
        if item.isWallColor {
            let activeID = layout.wallColorID ?? "wall_blush"
            return itemID == activeID
        }
        if item.isPictureFrame {
            return layout.owns(itemID)
                && layout.pictureFrameMomentID != nil
                && !layout.isStashed(itemID)
        }
        // A placed (owned, not stashed) floor item reads as "selected".
        return layout.owns(itemID) && !layout.isStashed(itemID)
    }

    func isShopItemStashed(_ itemID: String) -> Bool {
        roomLayout.isStashed(itemID)
    }

    /// Room décor the user owns (starters, purchases, and grants) — excludes consumables.
    func ownedInventoryItems(in category: PetShopCategory) -> [PetShopItem] {
        PetShopCatalog.items(in: category).filter { item in
            guard !item.isCatFood else { return false }
            return ownsShopItem(item.id)
        }
    }

    /// Categories that have at least one owned inventory item.
    var ownedItemCategories: [PetShopCategory] {
        PetShopCategory.allCases.filter { !ownedInventoryItems(in: $0).isEmpty }
    }

    var hasOwnedShopItems: Bool {
        !ownedItemCategories.isEmpty
    }

    /// Hides an owned item from the room (still owned; restore from My Items).
    func stashItem(_ itemID: String) {
        mutateActiveRoomLayout { layout in
            guard !layout.stashedItemIDs.contains(itemID) else { return }
            layout.stashedItemIDs.append(itemID)
            layout.propPositions.removeValue(forKey: itemID)
        }
    }

    /// Toggles a prop's horizontal flip (mirror).
    func toggleFlip(_ itemID: String) {
        mutateActiveRoomLayout { layout in
            if let idx = layout.flippedItemIDs.firstIndex(of: itemID) {
                layout.flippedItemIDs.remove(at: idx)
            } else {
                layout.flippedItemIDs.append(itemID)
            }
        }
    }

    func pictureFrameImage() -> UIImage? {
        guard let id = roomLayout.pictureFrameMomentID else { return nil }
        return PetGalleryPhotoLoader.image(for: id)
    }

    func updatePropPositions(_ positions: [String: NormalizedPoint]) {
        mutateActiveRoomLayout { $0.propPositions = positions }
    }

    /// Purchases or selects a shop item. Returns whether the memory-frame picker should open next.
    func purchaseShopItem(_ itemID: String) -> (result: CareResult, openFramePicker: Bool) {
        guard let item = PetShopCatalog.item(id: itemID) else {
            return (.none, false)
        }

        if let servings = item.servingsGranted {
            guard state.coins >= item.cost else {
                return (CareResult(coinsAwarded: 0, blockedReason: "Not enough coins"), false)
            }
            state.coins -= item.cost
            state.foodServings += servings
            return (.none, false)
        }

        if item.isStarter || roomLayout.owns(itemID) {
            if let slot = item.equipSlot {
                equipShopItem(item)
                return (.none, false)
            }
            if item.isWallColor {
                mutateActiveRoomLayout { $0.wallColorID = itemID }
            }
            if (item.isFloorItem || item.isPictureFrame), roomLayout.isStashed(itemID) {
                mutateActiveRoomLayout { layout in
                    layout.stashedItemIDs.removeAll { $0 == itemID }
                }
            }
            let openPicker = item.isPictureFrame && roomLayout.pictureFrameMomentID == nil
            return (.none, openPicker)
        }

        if item.cost == 0 {
            if let slot = item.equipSlot {
                equipShopItem(item)
            }
            return (.none, false)
        }

        guard state.coins >= item.cost else {
            return (CareResult(coinsAwarded: 0, blockedReason: "Not enough coins"), false)
        }

        state.coins -= item.cost
        mutateActiveRoomLayout { $0.ownedItemIDs.append(itemID) }

        if let slot = item.equipSlot {
            equipShopItem(item)
        } else if item.isWallColor {
            mutateActiveRoomLayout { $0.wallColorID = itemID }
        }

        let openPicker = item.isPictureFrame && roomLayout.pictureFrameMomentID == nil
        return (.none, openPicker)
    }

    private func equipShopItem(_ item: PetShopItem) {
        guard let slot = item.equipSlot else { return }
        mutateActiveRoomLayout { layout in
            if item.isStarter {
                layout.setEquippedItem(nil, for: slot)
            } else {
                layout.setEquippedItem(item.id, for: slot)
            }
        }
    }

    func setPictureFrameMoment(_ momentID: UUID) {
        mutateActiveRoomLayout { layout in
            layout.pictureFrameMomentID = momentID
            if !layout.owns(PetShopCatalog.pictureFrameID) {
                layout.ownedItemIDs.append(PetShopCatalog.pictureFrameID)
            }
        }
    }

    // MARK: - Trick training

    var trickTraining: PetTrickTrainingState { state.trickTraining }

    func trickProgress(for trick: PetTrick) -> PetTrickProgress {
        state.trickTraining.progress(for: trick)
    }

    func isTrickUnlocked(_ trick: PetTrick) -> Bool {
        state.trickTraining.isUnlocked(trick)
    }

    /// Outcome of a spoken trick command.
    enum TrickAttemptOutcome {
        case performed(level: Int, leveledUp: Bool, newlyUnlocked: [PetTrick], rewards: TrickTrainingRewards)
        case ignored(level: Int)
        case locked(trick: PetTrick)
    }

    var smartMeterLevel: Int { state.trickTraining.smartMeterLevel }
    var smartMeterXP: Int { state.trickTraining.smartMeterXP }

    func smartMeterProgressFraction() -> Double {
        PetSmartMeterRules.progressFraction(
            currentXP: state.trickTraining.smartMeterXP,
            currentLevel: state.trickTraining.smartMeterLevel
        )
    }

    /// Resolves a voice command: locked tricks are rejected; a correctly spoken command
    /// always counts as a completed rep (obedience only affects non-voice paths, if added later).
    func attemptTrick(_ trick: PetTrick, voiceRecognized: Bool = false) -> TrickAttemptOutcome {
        guard state.trickTraining.isUnlocked(trick) else {
            return .locked(trick: trick)
        }

        var progress = state.trickTraining.progress(for: trick)
        let level = progress.level
        if !voiceRecognized {
            let roll = Double.random(in: 0..<1)
            guard roll <= progress.obedienceRate else {
                return .ignored(level: level)
            }
        }

        let previousLevel = level
        let unlockedBefore = Set(PetTrick.allCases.filter { state.trickTraining.isUnlocked($0) })

        progress.successes += 1
        state.trickTraining.setProgress(progress, for: trick)
        state.trickTraining.refreshUnlocks()

        let newLevel = progress.level
        let leveledUp = newLevel > previousLevel
        let newlyUnlocked = PetTrick.allCases.filter {
            state.trickTraining.isUnlocked($0) && !unlockedBefore.contains($0)
        }

        var rewards = TrickTrainingRewards(smartMeterXP: PetSmartMeterRules.successXP(for: trick))
        if leveledUp {
            rewards.smartMeterXP += PetSmartMeterRules.levelUpXP
        }
        for unlocked in newlyUnlocked {
            rewards.smartMeterXP += PetSmartMeterRules.unlockXP
            rewards.coins += PetSmartMeterRules.unlockBonusCoins(for: unlocked)
        }

        state.trickTraining.addSmartMeterXP(rewards.smartMeterXP)
        if rewards.coins > 0 {
            state.coins += rewards.coins
            lastAward = (rewards.coins, UUID())
        }

        bumpHappiness(by: 3)
        return .performed(
            level: newLevel,
            leveledUp: leveledUp,
            newlyUnlocked: newlyUnlocked,
            rewards: rewards
        )
    }

    /// Treat teaser during trick training — small Smart Meter XP, gated by cooldown.
    func rewardTreatTeaser() -> TrickTrainingRewards {
        let now = Date()
        if let last = state.trickTraining.lastTreatTeaserAt {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < PetSmartMeterRules.treatTeaserCooldown {
                return TrickTrainingRewards()
            }
        }
        state.trickTraining.lastTreatTeaserAt = now
        let xp = PetSmartMeterRules.treatTeaserXP
        state.trickTraining.addSmartMeterXP(xp)
        bumpHappiness(by: 2)
        return TrickTrainingRewards(smartMeterXP: xp)
    }
}
