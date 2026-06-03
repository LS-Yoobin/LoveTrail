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
    /// Hidden market easter egg state: true while "unlock all" override is active.
    @Published private(set) var marketUnlockAllActive = false
    /// Hidden adoption easter egg: bypasses the level gate for adopting a second pet.
    @Published private(set) var secondPetAdoptionBypassActive = false

    /// Exact state snapshot captured right before the unlock-all override is applied.
    /// A second long-press restores this snapshot and clears the override.
    private var marketUnlockAllSnapshot: PetState?

    private var pacificCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar
    }

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
    var ownedSkins: [CatSkin] { state.ownedSkins }
    var primaryOwnedSkin: CatSkin? { state.ownedSkins.first }
    var hasAnyOwnedPet: Bool { !state.ownedSkins.isEmpty }

    func adopt(_ skin: CatSkin) {
        state.adoptedSkin = skin
        if state.adoptedDate == nil {
            state.adoptedDate = Date()
        }
        if !state.ownedSkins.contains(skin) {
            state.ownedSkins.append(skin)
            awardExperience(.adopt)
        }
        if state.roomLayoutsByPet[skin.rawValue] == nil {
            state.roomLayoutsByPet[skin.rawValue] = PetRoomLayoutState()
        }
        if state.trickTrainingByPet[skin.rawValue] == nil {
            state.trickTrainingByPet[skin.rawValue] = PetTrickTrainingState()
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
        awardExperience(.rename)
        return .none
    }

    func canAdopt(_ skin: CatSkin) -> (allowed: Bool, reason: String?) {
        if state.ownedSkins.contains(skin) { return (true, nil) }
        guard let primarySkin = primaryOwnedSkin else { return (true, nil) }
        if primarySkin == skin { return (true, nil) }
        if secondPetAdoptionBypassActive { return (true, nil) }
        let primaryLevel = state.trickTraining(for: primarySkin).smartMeterLevel
        guard primaryLevel >= PetEconomy.secondPetUnlockLevel else {
            return (
                false,
                "Reach Lvl \(PetEconomy.secondPetUnlockLevel) with \(displayName(for: primarySkin)) first"
            )
        }
        return (true, nil)
    }

    func smartLevel(for skin: CatSkin) -> Int {
        state.trickTraining(for: skin).smartMeterLevel
    }

    func unlockedTricks(for skin: CatSkin) -> [PetTrick] {
        let training = state.trickTraining(for: skin)
        return PetTrick.unlockOrder.filter { training.isUnlocked($0) }
    }

    /// Returns to the selection screen so the user can visit another adopted cat.
    /// Per-pet room layouts, names, and care progress are preserved.
    func releasePet() {
        state.adoptedSkin = nil
    }

    func visit(_ skin: CatSkin) {
        guard state.ownedSkins.contains(skin) else { return }
        state.adoptedSkin = skin
    }

    // MARK: Live need values (decay applied at read), 0…100

    var coins: Int { state.coins }
    var foodServings: Int { state.foodServings }

    var hunger: Int { Int(state.hunger.current(decayPerHour: PetEconomy.hungerDecayPerHour).rounded()) }
    var thirst: Int { Int(state.thirst.current(decayPerHour: PetEconomy.thirstDecayPerHour).rounded()) }
    var litter: Int { Int(state.litter.current(decayPerHour: PetEconomy.litterDecayPerHour).rounded()) }
    var happiness: Int { Int(state.happiness.current(decayPerHour: PetEconomy.happinessDecayPerHour).rounded()) }
    /// True when at least one scheduled litter-use event happened since the
    /// last manual clean. Uses Pacific time at 8:00 AM and 8:00 PM. The
    /// self-cleaning auto box never appears dirty.
    var isLitterBoxDirty: Bool {
        if isAutoLitterEquipped { return false }
        return litterUseEventsSinceLastClean(now: Date()) > 0
    }

    /// The litter box item currently equipped in the active room.
    var equippedLitterItemID: String? {
        guard let skin = state.adoptedSkin else { return nil }
        return state.roomLayout(for: skin).equippedItemID(for: .litterBox)
    }

    /// Whether the equipped litter box is the self-cleaning auto box.
    private var isAutoLitterEquipped: Bool {
        PetShopCatalog.isAutoLitter(equippedItemID: equippedLitterItemID)
    }

    /// When the auto box is equipped, passively collects the coins for every
    /// scheduled litter-use event since the last clean, then resets the box to
    /// clean. Safe to call on every refresh — it no-ops once collected (the
    /// clean date advances to now). Returns coins collected (0 if none / not auto).
    @discardableResult
    func processAutoLitterCollection(now: Date = Date()) -> Int {
        guard isAutoLitterEquipped else { return 0 }
        let events = litterUseEventsSinceLastClean(now: now)
        guard events > 0 else { return 0 }
        let coins = events * PetEconomy.CareTask.cleanLitter.coinReward
        state.coins += coins
        state.litter = StoredNeed(value: 100, asOf: now)
        lastAward = (coins, UUID())
        return coins
    }

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
        state.thirst = StoredNeed(value: 100)
        return award(.fillWater)
    }

    func feed() -> CareResult {
        let level = state.hunger.current(decayPerHour: PetEconomy.hungerDecayPerHour)
        guard state.foodServings > 0 else {
            return CareResult(coinsAwarded: 0, blockedReason: "Out of food — buy some in the Market")
        }
        guard level < PetEconomy.feedThirstGate else {
            return CareResult(coinsAwarded: 0, blockedReason: "There's still food in the bowl")
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

    /// Waters a plant: always lifts happiness for delight; awards coins only when
    /// that plant is off its watering cooldown. Keyed per plant so watering one
    /// doesn't lock another.
    func waterPlant(_ key: String) -> CareResult {
        bumpHappiness(by: PetEconomy.happinessFromWater)
        let now = Date()
        if let last = state.lastPlantWaterAt[key] {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < PetEconomy.plantWaterCooldown {
                let remaining = PetEconomy.plantWaterCooldown - elapsed
                return CareResult(
                    coinsAwarded: 0,
                    blockedReason: PetEconomy.plantWaterCooldownMessage(remaining: remaining)
                )
            }
        }
        state.lastPlantWaterAt[key] = now
        return awardPlantWater(for: key)
    }

    /// Whether watering the given plant would award coins right now.
    func canEarnWaterCoins(key: String, now: Date = Date()) -> Bool {
        guard let last = state.lastPlantWaterAt[key] else { return true }
        return now.timeIntervalSince(last) >= PetEconomy.plantWaterCooldown
    }

    func cleanLitter() -> CareResult {
        // Litter-box interaction is driven by scheduled "use" events. If an event
        // made the box dirty, cleaning should always clear it even when the
        // litter meter itself hasn't decayed below the generic clean gate yet.
        if isLitterBoxDirty {
            state.litter = StoredNeed(value: 100)
            return award(.cleanLitter)
        }
        let level = state.litter.current(decayPerHour: PetEconomy.litterDecayPerHour)
        guard level < PetEconomy.litterCleanGate else {
            return CareResult(coinsAwarded: 0, blockedReason: "The litter's already clean")
        }
        state.litter = StoredNeed(value: 100)
        return award(.cleanLitter)
    }

    private func litterUseEventsSinceLastClean(now: Date) -> Int {
        let pacific = TimeZone(identifier: "America/Los_Angeles") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        let cleanDate = state.litter.asOf
        guard now > cleanDate else { return 0 }

        let useHours = [8, 20]
        let startDay = calendar.startOfDay(for: cleanDate)
        let endDay = calendar.startOfDay(for: now)

        var uses = 0
        var day = startDay
        while day <= endDay {
            for hour in useHours {
                guard let event = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
                if event > cleanDate, event <= now {
                    uses += 1
                }
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return uses
    }

    // MARK: Helpers

    private func award(_ task: PetEconomy.CareTask) -> CareResult {
        let amount = task.coinReward
        state.coins += amount
        lastAward = (amount, UUID())
        switch task {
        case .pet: awardExperience(.pet)
        case .fillWater: awardExperience(.fillWater)
        case .feed: awardExperience(.feed)
        case .play: awardExperience(.play)
        case .cleanLitter: awardExperience(.cleanLitter)
        case .waterPlant: awardExperience(.fillWater)
        }
        return CareResult(coinsAwarded: amount, blockedReason: nil)
    }

    private func awardPlantWater(for key: String) -> CareResult {
        let amount = PetEconomy.plantWaterCoinReward(for: key)
        state.coins += amount
        lastAward = (amount, UUID())
        // Keep Smart XP behavior aligned with other watering interactions.
        awardExperience(.fillWater)
        return CareResult(coinsAwarded: amount, blockedReason: nil)
    }

    private func awardExperience(_ source: PetEconomy.ExperienceSource) {
        guard let adopted = state.adoptedSkin else { return }
        state.updateTrickTraining(for: adopted) { training in
            training.addSmartMeterXP(source.smartXP)
        }
    }

    /// Raises happiness from its current (decayed) value, re-snapshotting `asOf`.
    private func bumpHappiness(by amount: Double) {
        let current = state.happiness.current(decayPerHour: PetEconomy.happinessDecayPerHour)
        state.happiness = StoredNeed(value: min(100, current + amount))
    }

    // MARK: - Hidden easter eggs

    /// Long-press the level pill to bypass the second-pet adoption level gate.
    @discardableResult
    func toggleSecondPetAdoptionBypass() -> Bool {
        secondPetAdoptionBypassActive.toggle()
        return secondPetAdoptionBypassActive
    }

    /// Long-press easter egg in Market:
    /// - first press: snapshots current state and unlocks all non-consumable shop items
    /// - second press: restores the exact snapshot (undo)
    @discardableResult
    func toggleMarketUnlockAllPurchases() -> Bool {
        if let snapshot = marketUnlockAllSnapshot {
            state = snapshot
            marketUnlockAllSnapshot = nil
            marketUnlockAllActive = false
            return false
        }

        marketUnlockAllSnapshot = state
        unlockAllShopItemsForAllPets()
        marketUnlockAllActive = true
        return true
    }

    private func unlockAllShopItemsForAllPets() {
        let unlockableIDs = PetShopCatalog.all
            .filter { !$0.isStarter && !$0.isCatFood }
            .map(\.id)

        for skin in CatSkin.allCases {
            state.updateRoomLayout(for: skin) { layout in
                for id in unlockableIDs where !layout.ownedItemIDs.contains(id) {
                    layout.ownedItemIDs.append(id)
                }
            }
        }
    }

    // MARK: - Room shop & layout

    var roomLayout: PetRoomLayoutState {
        guard let skin = state.adoptedSkin else { return PetRoomLayoutState() }
        var layout = state.roomLayout(for: skin)

        // The food and water bowls stay locked in the same fixed positions across
        // *all* pets so feeding/drinking animations don't drift per-room. The
        // litter box is movable, so each pet keeps its own litter position.
        let arabellaLayout = state.roomLayout(for: .cowCat)
        for key in [PetRoomPropKey.foodBowl, PetRoomPropKey.waterBowl] {
            if let fixed = arabellaLayout.propPositions[key] {
                layout.propPositions[key] = fixed
            } else {
                // If Arabella never moved them, fall back to the scene defaults.
                layout.propPositions.removeValue(forKey: key)
            }
        }

        return layout
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
        if item.isPlayToy {
            return selectedPlayToyID == itemID
        }
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
            return PetShopCatalog.activePictureFrameID(in: layout) == itemID
        }
        // Floor décor (beds/furniture/plants) is "one at a time": only the single
        // active piece in the category reads as "Selected", so duplicates owned via
        // the unlock-all cheat or legacy saves don't all show as placed.
        if item.isFloorItem {
            let categoryIDs = PetShopCatalog.floorItemIDs(in: item.category)
            return layout.activeItem(among: categoryIDs) == itemID
        }
        return false
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

    /// Owned toy items for the play hotbar, most-recently-used first.
    var ownedPlayToysNewestFirst: [PetShopItem] {
        let layout = roomLayout
        let ownedPlayToyIDs = layout.ownedItemIDs.filter { id in
            PetShopCatalog.item(id: id)?.isPlayToy == true
        }

        let recencyIDs = layout.playToyUsageOrder.filter { ownedPlayToyIDs.contains($0) }
        let fallbackNewestPurchaseIDs = ownedPlayToyIDs.reversed().filter { !recencyIDs.contains($0) }
        return (recencyIDs + fallbackNewestPurchaseIDs).compactMap(PetShopCatalog.item(id:))
    }

    /// Currently selected play toy item id; nil means laser pointer.
    var selectedPlayToyID: String? {
        let selected = roomLayout.selectedPlayToyID
        guard let selected,
              let toy = PetShopCatalog.item(id: selected),
              toy.isPlayToy,
              roomLayout.owns(selected) else {
            return nil
        }
        return selected
    }

    func selectPlayToy(_ itemID: String?) {
        mutateActiveRoomLayout { layout in
            guard let itemID else {
                layout.selectedPlayToyID = nil
                return
            }
            guard let item = PetShopCatalog.item(id: itemID),
                  item.isPlayToy,
                  layout.owns(itemID) else { return }
            layout.selectedPlayToyID = itemID
            var order = layout.playToyUsageOrder
            order.removeAll { $0 == itemID }
            order.insert(itemID, at: 0)
            order.removeAll { id in
                guard layout.owns(id) else { return true }
                return PetShopCatalog.item(id: id)?.isPlayToy != true
            }
            layout.playToyUsageOrder = order
        }
    }

    /// Hides an owned item from the room (still owned; restore from My Items).
    func stashItem(_ itemID: String) {
        mutateActiveRoomLayout { layout in
            guard !layout.stashedItemIDs.contains(itemID) else { return }
            layout.stashedItemIDs.append(itemID)
            layout.propPositions.removeValue(forKey: itemID)
            if PetShopCatalog.item(id: itemID)?.isPictureFrame == true {
                layout.pictureFrameMoments.removeValue(forKey: itemID)
            }
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

    func activePictureFrameID() -> String? {
        PetShopCatalog.activePictureFrameID(in: roomLayout)
    }

    func pictureFrameMoment(for frameID: String) -> UUID? {
        roomLayout.pictureFrameMoment(for: frameID)
    }

    func pictureFrameImage(for frameID: String? = nil) -> UIImage? {
        let resolvedFrameID = frameID ?? activePictureFrameID()
        guard let resolvedFrameID,
              let momentID = roomLayout.pictureFrameMoment(for: resolvedFrameID) else { return nil }
        return PetGalleryPhotoLoader.image(for: momentID)
    }

    func updatePropPositions(_ positions: [String: NormalizedPoint]) {
        mutateActiveRoomLayout { $0.propPositions = positions }
    }

    /// Purchases or selects a shop item. Returns whether the memory-frame picker should open next.
    func purchaseShopItem(_ itemID: String) -> (result: CareResult, openFramePicker: Bool) {
        guard let item = PetShopCatalog.item(id: itemID) else {
            return (.none, false)
        }

        if item.isAutoLitter, !roomLayout.owns(itemID), smartMeterLevel < 20 {
            return (CareResult(coinsAwarded: 0, blockedReason: "Your pet must be lvl 20."), false)
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
            activateShopItem(item, itemID: itemID)
            let openPicker = item.isPictureFrame
            return (.none, openPicker)
        }

        if item.cost > 0 {
            guard state.coins >= item.cost else {
                return (CareResult(coinsAwarded: 0, blockedReason: "Not enough coins"), false)
            }
            state.coins -= item.cost
        }

        mutateActiveRoomLayout { layout in
            if !layout.ownedItemIDs.contains(itemID) {
                layout.ownedItemIDs.append(itemID)
            }
        }

        activateShopItem(item, itemID: itemID)

        let openPicker = item.isPictureFrame
        return (.none, openPicker)
    }

    /// Equips or places the chosen shop item and stashes other visible pieces in
    /// the same category so they do not stack on top of each other in the room.
    private func activateShopItem(_ item: PetShopItem, itemID: String) {
        stashCategorySiblings(except: item)
        if let slot = item.equipSlot {
            equipShopItem(item)
        } else if item.isPlayToy {
            selectPlayToy(itemID)
        } else if item.isWallColor {
            mutateActiveRoomLayout { $0.wallColorID = itemID }
        } else if (item.isFloorItem || item.isPictureFrame), roomLayout.isStashed(itemID) {
            mutateActiveRoomLayout { layout in
                layout.stashedItemIDs.removeAll { $0 == itemID }
            }
        }
    }

    private func stashCategorySiblings(except selected: PetShopItem) {
        guard !selected.isCatFood else { return }
        mutateActiveRoomLayout { layout in
            for sibling in PetShopCatalog.items(in: selected.category) where sibling.id != selected.id {
                if let slot = selected.equipSlot {
                    guard sibling.equipSlot == slot else { continue }
                } else if selected.isPlayToy || selected.isWallColor {
                    continue
                } else if !(sibling.isFloorItem || sibling.isPictureFrame || sibling.equipSlot != nil) {
                    continue
                }
                guard layout.owns(sibling.id) else { continue }
                if !layout.stashedItemIDs.contains(sibling.id) {
                    layout.stashedItemIDs.append(sibling.id)
                }
                layout.propPositions.removeValue(forKey: sibling.id)
            }
        }
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

    func setPictureFrameMoment(_ momentID: UUID, for frameID: String? = nil) {
        let resolvedFrameID = frameID ?? activePictureFrameID() ?? PetShopCatalog.defaultPictureFrameID
        mutateActiveRoomLayout { layout in
            layout.pictureFrameMoments[resolvedFrameID] = momentID
            if !layout.owns(resolvedFrameID) {
                layout.ownedItemIDs.append(resolvedFrameID)
            }
            layout.stashedItemIDs.removeAll { $0 == resolvedFrameID }
        }
    }

    // MARK: - Toilet paper mess event

    /// True when a weekly random toilet-paper mess should be visible in the room.
    func hasActiveToiletPaperMess(now: Date = Date()) -> Bool {
        guard state.adoptedSkin != nil else { return false }
        refreshToiletPaperMessScheduleIfNeeded(now: now)
        return state.adoptedSkin.map { skin in
            state.toiletPaperMessState(for: skin).activeEventIndex != nil
        } ?? false
    }

    /// Marks the active mess as cleaned up so the next scheduled event can appear.
    func throwAwayActiveToiletPaperMess(now: Date = Date()) {
        guard let skin = state.adoptedSkin else { return }
        refreshToiletPaperMessScheduleIfNeeded(now: now)
        let current = state.toiletPaperMessState(for: skin)
        guard let active = current.activeEventIndex else { return }
        state.updateToiletPaperMessState(for: skin) { mess in
            if !mess.consumedEventIndices.contains(active) {
                mess.consumedEventIndices.append(active)
            }
            mess.activeEventIndex = nil
        }
        refreshToiletPaperMessScheduleIfNeeded(now: now)
    }

    func randomToiletPaperMessComment(for catName: String) -> String {
        let comments = [
            "\(catName) decided to eat your toilet paper.",
            "\(catName) got busy while you were gone.",
            "\(catName) unrolled the entire roll for \"interior design.\"",
            "Breaking news: \(catName) shredded the bathroom budget.",
            "\(catName) mistook your toilet paper for an all-you-can-scratch buffet.",
            "\(catName) left a fluffy crime scene all over the floor."
        ]
        return comments.randomElement() ?? "\(catName) got busy while you were gone."
    }

    private func refreshToiletPaperMessScheduleIfNeeded(now: Date) {
        guard let skin = state.adoptedSkin else { return }
        let weekKey = toiletPaperWeekKey(for: now)
        var mess = state.toiletPaperMessState(for: skin)

        // Keep an uncleaned mess visible until user throws it away, even across weeks.
        if mess.activeEventIndex != nil {
            if mess.weekKey.isEmpty {
                mess.weekKey = weekKey
                state.updateToiletPaperMessState(for: skin) { $0 = mess }
            }
            return
        }

        if mess.weekKey != weekKey {
            mess.weekKey = weekKey
            mess.scheduledEventTimes = generateWeeklyToiletPaperEvents(for: now)
            mess.consumedEventIndices = []
            mess.activeEventIndex = nil
        }

        let consumed = Set(mess.consumedEventIndices)
        if let nextIndex = mess.scheduledEventTimes.indices.first(where: { idx in
            mess.scheduledEventTimes[idx] <= now.timeIntervalSince1970 && !consumed.contains(idx)
        }) {
            mess.activeEventIndex = nextIndex
        }

        state.updateToiletPaperMessState(for: skin) { $0 = mess }
    }

    private func toiletPaperWeekKey(for date: Date) -> String {
        let calendar = pacificCalendar
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    private func generateWeeklyToiletPaperEvents(for date: Date) -> [TimeInterval] {
        let calendar = pacificCalendar
        let triggerCount = Int.random(in: 0...2) // some weeks none/once/twice
        guard triggerCount > 0 else { return [] }

        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        var candidateDays = Array(0...6)
        candidateDays.shuffle()
        let selectedDays = candidateDays.prefix(triggerCount).sorted()

        return selectedDays.compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { return nil }
            let hour = Int.random(in: 9...21)
            let minute = Int.random(in: 0...59)
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)?.timeIntervalSince1970
        }.sorted()
    }

    // MARK: - Trick training

    var trickTraining: PetTrickTrainingState {
        guard let skin = state.adoptedSkin else { return PetTrickTrainingState() }
        return state.trickTraining(for: skin)
    }

    private func mutateActiveTrickTraining(_ transform: (inout PetTrickTrainingState) -> Void) {
        guard let skin = state.adoptedSkin else { return }
        state.updateTrickTraining(for: skin, transform)
    }

    func trickProgress(for trick: PetTrick) -> PetTrickProgress {
        trickTraining.progress(for: trick)
    }

    func isTrickUnlocked(_ trick: PetTrick) -> Bool {
        trickTraining.isUnlocked(trick)
    }

    /// Outcome of a spoken trick command.
    enum TrickAttemptOutcome {
        case performed(level: Int, leveledUp: Bool, newlyUnlocked: [PetTrick], rewards: TrickTrainingRewards)
        case ignored(level: Int)
        case locked(trick: PetTrick)
    }

    var smartMeterLevel: Int { trickTraining.smartMeterLevel }
    var smartMeterXP: Int { trickTraining.smartMeterXP }

    func smartMeterProgressFraction() -> Double {
        PetSmartMeterRules.progressFraction(
            currentXP: trickTraining.smartMeterXP,
            currentLevel: trickTraining.smartMeterLevel
        )
    }

    /// Resolves a voice command: locked tricks are rejected; a correctly spoken command
    /// always counts as a completed rep (obedience only affects non-voice paths, if added later).
    func attemptTrick(_ trick: PetTrick, voiceRecognized: Bool = false) -> TrickAttemptOutcome {
        guard state.adoptedSkin != nil else {
            return .locked(trick: trick)
        }
        guard trickTraining.isUnlocked(trick) else {
            return .locked(trick: trick)
        }

        var progress = trickTraining.progress(for: trick)
        let level = progress.level
        if !voiceRecognized {
            let roll = Double.random(in: 0..<1)
            guard roll <= progress.obedienceRate else {
                return .ignored(level: level)
            }
        }

        let previousLevel = level
        let unlockedBefore = Set(PetTrick.allCases.filter { trickTraining.isUnlocked($0) })

        progress.successes += 1
        mutateActiveTrickTraining { training in
            training.setProgress(progress, for: trick)
            training.refreshUnlocks()
        }

        let newLevel = progress.level
        let leveledUp = newLevel > previousLevel
        let newlyUnlocked = PetTrick.allCases.filter {
            trickTraining.isUnlocked($0) && !unlockedBefore.contains($0)
        }

        var rewards = TrickTrainingRewards(smartMeterXP: PetSmartMeterRules.successXP(for: trick))
        if leveledUp {
            rewards.smartMeterXP += PetSmartMeterRules.levelUpXP
        }
        for unlocked in newlyUnlocked {
            rewards.smartMeterXP += PetSmartMeterRules.unlockXP
            rewards.coins += PetSmartMeterRules.unlockBonusCoins(for: unlocked)
        }

        mutateActiveTrickTraining { training in
            training.addSmartMeterXP(rewards.smartMeterXP)
        }
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
        guard state.adoptedSkin != nil else { return TrickTrainingRewards() }
        let training = trickTraining
        let now = Date()
        if let last = training.lastTreatTeaserAt {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < PetSmartMeterRules.treatTeaserCooldown {
                return TrickTrainingRewards()
            }
        }

        mutateActiveTrickTraining { training in
            training.lastTreatTeaserAt = now
        }
        let xp = PetSmartMeterRules.treatTeaserXP
        mutateActiveTrickTraining { training in
            training.addSmartMeterXP(xp)
        }
        bumpHappiness(by: 2)
        return TrickTrainingRewards(smartMeterXP: xp)
    }
}
