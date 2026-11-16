import Foundation

// Pet, pet room and trick training ↔ `/couple/pet`, `/couple/pet/room`,
// `/couple/pet/tricks` (BAB-69, server BAB-138..140).
//
// Decisions (2026-11-15): one shared pet per couple; the app owns need decay (the
// server stores each need as `{ value, as_of }` and never decays it); whole-document
// last write wins; on first pairing the cat already in the Cove stays.
//
// Shared: cats owned, the active cat, adoption date, cat names, needs, food servings,
// toilet paper mess, rooms per cat, tricks per cat.
// Kept on each phone: coins (synced through the ledger, see `CoinLedgerSync`), pet /
// play / plant cooldowns, last interaction time, tutorial seen, check-in date and
// streak, selected play toy and toy usage order.
//
// Each body is built by one encoder from a small value type, whether the source is the
// local `PetState` or the server DTO, so unchanged data always compares equal.

// MARK: - Pet

@MainActor
final class PetSyncResource: CoupleSyncDocument {
    let key = "pet"
    let path = "couple/pet"
    let writeMethod = "PUT"

    private let dpm: DataPersistenceManager

    init(dpm: DataPersistenceManager = .shared) {
        self.dpm = dpm
    }

    private struct Shared {
        var adoptedSkin: String?
        var adoptedDate: Date?
        var ownedSkins: [String]
        var customNames: [String: String]
        var foodServings: Int
        var needs: [String: (value: Double, asOf: Date)]
        var mess: [String: ToiletPaperMessState]
    }

    private static let needKeys = ["hunger", "thirst", "litter", "happiness"]

    private static func shared(from state: PetState) -> Shared {
        Shared(
            adoptedSkin: state.adoptedSkin?.rawValue,
            adoptedDate: state.adoptedDate,
            ownedSkins: state.ownedSkins.map(\.rawValue),
            customNames: state.customPetNames,
            foodServings: state.foodServings,
            needs: [
                "hunger": (state.hunger.value, state.hunger.asOf),
                "thirst": (state.thirst.value, state.thirst.asOf),
                "litter": (state.litter.value, state.litter.asOf),
                "happiness": (state.happiness.value, state.happiness.asOf),
            ],
            mess: state.toiletPaperMessByPet
        )
    }

    private static func shared(from dto: [String: Any]) -> Shared {
        var needs: [String: (value: Double, asOf: Date)] = [:]
        let rawNeeds = dto["needs"] as? [String: Any] ?? [:]
        for key in needKeys {
            guard let point = rawNeeds[key] as? [String: Any],
                  let value = SyncJSON.double(point["value"]),
                  let asOf = SyncJSON.date(from: point["as_of"]) else { continue }
            needs[key] = (value, asOf)
        }
        var mess: [String: ToiletPaperMessState] = [:]
        for (skin, raw) in dto["toilet_paper_mess_by_pet"] as? [String: Any] ?? [:] {
            guard let entry = raw as? [String: Any] else { continue }
            mess[skin] = ToiletPaperMessState(
                weekKey: entry["week_key"] as? String ?? "",
                scheduledEventTimes: (entry["scheduled_event_times"] as? [Any] ?? []).compactMap(SyncJSON.double),
                consumedEventIndices: (entry["consumed_event_indices"] as? [Any] ?? []).compactMap(SyncJSON.int),
                activeEventIndex: SyncJSON.int(entry["active_event_index"])
            )
        }
        return Shared(
            adoptedSkin: dto["adopted_skin"] as? String,
            adoptedDate: SyncJSON.date(from: dto["adopted_date"]),
            ownedSkins: (dto["owned_skins"] as? [String]) ?? [],
            customNames: (dto["custom_names"] as? [String: String]) ?? [:],
            foodServings: SyncJSON.int(dto["food_servings"]) ?? 0,
            needs: needs,
            mess: mess
        )
    }

    private static func body(_ shared: Shared) -> [String: Any] {
        var needs: [String: Any] = [:]
        for key in needKeys {
            guard let point = shared.needs[key] else { continue }
            needs[key] = ["value": point.value, "as_of": SyncJSON.string(from: point.asOf)]
        }
        var mess: [String: Any] = [:]
        for (skin, entry) in shared.mess {
            mess[skin] = SyncJSON.compacted([
                "week_key": entry.weekKey,
                "scheduled_event_times": entry.scheduledEventTimes,
                "consumed_event_indices": entry.consumedEventIndices,
                "active_event_index": entry.activeEventIndex,
            ])
        }
        return SyncJSON.compacted([
            "adopted_skin": shared.adoptedSkin,
            "adopted_date": shared.adoptedDate.map(SyncJSON.string(from:)),
            "owned_skins": shared.ownedSkins,
            "custom_names": shared.customNames,
            "food_servings": shared.foodServings,
            "needs": needs.isEmpty ? nil : needs,
            "toilet_paper_mess_by_pet": mess,
        ])
    }

    func localBody() -> [String: Any]? {
        let state = dpm.loadPetState()
        // Nothing to share until a cat is adopted.
        guard state.adoptedSkin != nil else { return nil }
        return Self.body(Self.shared(from: state))
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any] {
        Self.body(Self.shared(from: dto))
    }

    func serverHasContent(_ dto: [String: Any]) -> Bool {
        dto["adopted_skin"] is String
    }

    func applyRemote(_ dto: [String: Any]) {
        let shared = Self.shared(from: dto)
        var state = dpm.loadPetState()
        state.adoptedSkin = shared.adoptedSkin.flatMap(CatSkin.init(rawValue:))
        state.adoptedDate = shared.adoptedDate
        state.ownedSkins = shared.ownedSkins.compactMap(CatSkin.init(rawValue:))
        state.customPetNames = shared.customNames
        state.foodServings = shared.foodServings
        if let point = shared.needs["hunger"] { state.hunger = StoredNeed(value: point.value, asOf: point.asOf) }
        if let point = shared.needs["thirst"] { state.thirst = StoredNeed(value: point.value, asOf: point.asOf) }
        if let point = shared.needs["litter"] { state.litter = StoredNeed(value: point.value, asOf: point.asOf) }
        if let point = shared.needs["happiness"] { state.happiness = StoredNeed(value: point.value, asOf: point.asOf) }
        state.toiletPaperMessByPet = shared.mess
        dpm.savePetState(state)
    }
}

// MARK: - Room

@MainActor
final class PetRoomSyncResource: CoupleSyncDocument {
    let key = "pet-room"
    let path = "couple/pet/room"
    let writeMethod = "PUT"

    private let dpm: DataPersistenceManager

    init(dpm: DataPersistenceManager = .shared) {
        self.dpm = dpm
    }

    private static func layoutBody(_ layout: PetRoomLayoutState) -> [String: Any] {
        var positions: [String: Any] = [:]
        for (item, point) in layout.propPositions {
            positions[item] = ["x": Double(point.x), "y": Double(point.y)]
        }
        var frames: [String: Any] = [:]
        for (frame, momentId) in layout.pictureFrameMoments {
            frames[frame] = SyncIDCodec.objectId(for: momentId)
        }
        return SyncJSON.compacted([
            "built_in_layout_version": layout.builtInLayoutVersion,
            "owned_item_ids": layout.ownedItemIDs,
            "stashed_item_ids": layout.stashedItemIDs,
            "prop_positions": positions,
            "flipped_item_ids": layout.flippedItemIDs,
            "wall_color_id": layout.wallColorID,
            "picture_frame_moments": frames,
            "equipped_items": layout.equippedItems,
        ])
    }

    /// Rebuilds a layout from the server, keeping this phone's play-toy hotbar.
    private func layout(from raw: [String: Any], keeping local: PetRoomLayoutState?) -> PetRoomLayoutState {
        var positions: [String: NormalizedPoint] = [:]
        for (item, value) in raw["prop_positions"] as? [String: Any] ?? [:] {
            guard let point = value as? [String: Any],
                  let x = SyncJSON.double(point["x"]),
                  let y = SyncJSON.double(point["y"]) else { continue }
            positions[item] = NormalizedPoint(x: CGFloat(x), y: CGFloat(y))
        }
        let moments = dpm.loadMoments()
        var frames: [String: UUID] = [:]
        for (frame, value) in raw["picture_frame_moments"] as? [String: Any] ?? [:] {
            guard let objectId = value as? String else { continue }
            if let moment = moments.first(where: { SyncIDCodec.matches($0.id, objectId: objectId) }) {
                frames[frame] = moment.id
            } else if let uuid = SyncIDCodec.uuid(forObjectId: objectId) {
                frames[frame] = uuid
            }
        }
        return PetRoomLayoutState(
            builtInLayoutVersion: SyncJSON.int(raw["built_in_layout_version"]) ?? 1,
            ownedItemIDs: raw["owned_item_ids"] as? [String] ?? [],
            stashedItemIDs: raw["stashed_item_ids"] as? [String] ?? [],
            propPositions: positions,
            flippedItemIDs: raw["flipped_item_ids"] as? [String] ?? [],
            wallColorID: raw["wall_color_id"] as? String,
            pictureFrameMoments: frames,
            equippedItems: raw["equipped_items"] as? [String: String] ?? [:],
            selectedPlayToyID: local?.selectedPlayToyID,
            playToyUsageOrder: local?.playToyUsageOrder ?? []
        )
    }

    func localBody() -> [String: Any]? {
        let state = dpm.loadPetState()
        guard !state.roomLayoutsByPet.isEmpty else { return nil }
        return ["layouts_by_pet": state.roomLayoutsByPet.mapValues(Self.layoutBody)]
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any] {
        var layouts: [String: Any] = [:]
        for (skin, raw) in dto["layouts_by_pet"] as? [String: Any] ?? [:] {
            guard let entry = raw as? [String: Any] else { continue }
            layouts[skin] = Self.layoutBody(layout(from: entry, keeping: nil))
        }
        return ["layouts_by_pet": layouts]
    }

    func serverHasContent(_ dto: [String: Any]) -> Bool {
        !((dto["layouts_by_pet"] as? [String: Any]) ?? [:]).isEmpty
    }

    func applyRemote(_ dto: [String: Any]) {
        var state = dpm.loadPetState()
        var layouts: [String: PetRoomLayoutState] = [:]
        for (skin, raw) in dto["layouts_by_pet"] as? [String: Any] ?? [:] {
            guard let entry = raw as? [String: Any] else { continue }
            layouts[skin] = layout(from: entry, keeping: state.roomLayoutsByPet[skin])
        }
        state.roomLayoutsByPet = layouts
        dpm.savePetState(state)
    }
}

// MARK: - Tricks

@MainActor
final class PetTricksSyncResource: CoupleSyncDocument {
    let key = "pet-tricks"
    let path = "couple/pet/tricks"
    let writeMethod = "PUT"

    private let dpm: DataPersistenceManager

    init(dpm: DataPersistenceManager = .shared) {
        self.dpm = dpm
    }

    private static func trainingBody(_ training: PetTrickTrainingState) -> [String: Any] {
        var progress: [String: Any] = [:]
        for (trick, entry) in training.progress {
            progress[trick] = [
                "is_unlocked": entry.isUnlocked,
                "successes": entry.successes,
                "snack_reinforcements": entry.snackReinforcements,
            ]
        }
        return ["progress": progress, "smart_meter_xp": training.smartMeterXP]
    }

    private static func training(from raw: [String: Any]) -> PetTrickTrainingState {
        var training = PetTrickTrainingState()
        var progress: [String: PetTrickProgress] = [:]
        for (trick, value) in raw["progress"] as? [String: Any] ?? [:] {
            guard let entry = value as? [String: Any] else { continue }
            progress[trick] = PetTrickProgress(
                isUnlocked: SyncJSON.bool(entry["is_unlocked"]) ?? false,
                successes: SyncJSON.int(entry["successes"]) ?? 0,
                snackReinforcements: SyncJSON.int(entry["snack_reinforcements"]) ?? 0
            )
        }
        if !progress.isEmpty { training.progress = progress }
        training.smartMeterXP = SyncJSON.int(raw["smart_meter_xp"]) ?? 0
        return training
    }

    func localBody() -> [String: Any]? {
        let state = dpm.loadPetState()
        guard !state.trickTrainingByPet.isEmpty else { return nil }
        return ["training_by_pet": state.trickTrainingByPet.mapValues(Self.trainingBody)]
    }

    func comparableBody(fromServer dto: [String: Any]) -> [String: Any] {
        var training: [String: Any] = [:]
        for (skin, raw) in dto["training_by_pet"] as? [String: Any] ?? [:] {
            guard let entry = raw as? [String: Any] else { continue }
            training[skin] = Self.trainingBody(Self.training(from: entry))
        }
        return ["training_by_pet": training]
    }

    func serverHasContent(_ dto: [String: Any]) -> Bool {
        !((dto["training_by_pet"] as? [String: Any]) ?? [:]).isEmpty
    }

    func applyRemote(_ dto: [String: Any]) {
        var state = dpm.loadPetState()
        var training: [String: PetTrickTrainingState] = [:]
        for (skin, raw) in dto["training_by_pet"] as? [String: Any] ?? [:] {
            guard let entry = raw as? [String: Any] else { continue }
            training[skin] = Self.training(from: entry)
        }
        state.trickTrainingByPet = training
        dpm.savePetState(state)
    }
}
