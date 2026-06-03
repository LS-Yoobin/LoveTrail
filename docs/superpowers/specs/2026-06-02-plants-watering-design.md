# Plants + Watering Mini-Game — Design

Date: 2026-06-02

## Goal

Add two potted-plant décor items to the shop and room, and a watering
interaction: tap a plant → inspect prompt with a **"Water"** CTA → a drawn
watering can appears → drag it over the plant for **5 seconds** to water it.
Watering awards **6 coins + a happiness boost** on a **3-hour cooldown** (the
animation always plays for delight; coins are gated). Mirrors the existing
litter-cleaning drag mini-game and laser-play reward model.

## Source art

`~/Downloads/prop_small_plant.png` (tulip pot, 2113×2535) and
`~/Downloads/prop_big_plant.png` (monstera pot, 3054×3698). Both are **already
fully transparent** (corner pixels RGBA 0,0,0,0) — no background removal needed.
The black seen in previews is just transparency compositing.

## 1. Assets

Create two imagesets in `BabyTown/Assets.xcassets/`:
- `prop_small_plant` ← prop_small_plant.png
- `prop_big_plant` ← prop_big_plant.png

Standard imageset `Contents.json` (full PNG at 1x, empty 2x/3x), matching the
existing prop imageset convention.

## 2. Shop catalog (`PetShopCatalog.swift`)

Add a new category so plants get their own market tab:
- `PetShopCategory.plants` — title "Plants", systemImage "leaf.fill".

Add two décor floor items (placed/movable like cat beds):

| ID | Name | Cost | imageName | category | defaultSize (w×h) |
|----|------|------|-----------|----------|-------------------|
| `furniture_small_plant` | Tulip Pot Plant | 45 | `prop_small_plant` | `.plants` | 150 × 180 |
| `furniture_big_plant` | Monstera Pot Plant | 80 | `prop_big_plant` | `.plants` | 215 × 260 |

Both `isFloorItem: true`, `isWallColor: false`, `isPictureFrame: false`, no
`equipSlot`. In-room scale is driven by `defaultSize.height` (the scene uses
`scaledToHeight`), so the heights above are intentionally large (bigger than the
art might otherwise render). Aspect ≈ 0.83 (w/h) preserved for the placeholder.

## 3. Make plants tappable (`PetRoomScene.swift`)

- Add `RoomProp.smallPlant` and `RoomProp.bigPlant` to the tappable enum.
- Add `PetRoomPropKey` constants (or reuse the item ids `furniture_small_plant` /
  `furniture_big_plant`) for the plant keys.
- In `placeOwnedFurniture()`, when the item is a plant, install it with the
  matching `roomProp` (`.smallPlant` / `.bigPlant`) instead of `nil`, so taps
  register. Give each a default floor position (e.g. small at x0.30/y0.20, big at
  x0.72/y0.20) — adjustable, away from the care props.
- Add `func plantFrameInScene(for prop: RoomProp) -> CGRect?` returning the
  plant node's `calculateAccumulatedFrame()`, used for drag overlap hit-testing
  (parallels `litterBoxFrameInScene()`).
- Optional delight: a brief sparkle/water-drop reaction on the plant when
  watering completes (small `SKEmitter`/drop nodes or a quick scale bounce).

## 4. Inspect prompt (`BowlInspectCard.swift`)

Extend the existing inspect card with plant configs (keeps the tap→card→action
pattern consistent with food/water/litter):
- For `.smallPlant` / `.bigPlant`: title = plant name, image = plant art,
  primaryButton = "Water", no secondary button.
- Plants have no fullness meter, so make the fullness bar **optional** (hide it
  when the config has no value). A short status line replaces it: "Give your
  plant a drink 💧" when off cooldown, or "Watered — come back in Xh Ym" when on
  cooldown (coins still gated, but the user may water for delight regardless).

## 5. Tap routing (`PetRoomView.swift`)

- `handleProp(_:)`: add `.smallPlant` / `.bigPlant` → `inspect = prop` (show the
  card). Guard so this only happens outside customize mode (in customize mode the
  plant is a draggable décor item, handled by the scene's selection logic).
- Add plants to the early-return guard set alongside the other modals/mini-games.
- `performInspectAction(_:)`: plant cases → `beginWateringMiniGame(for: prop)`,
  then dismiss the card.

## 6. Watering mini-game (`PetRoomView.swift`)

Mirror the litter-cleaning mini-game structure:

State: `isWateringPlant`, `wateringPlantProp: RoomProp?`,
`wateringProgress: TimeInterval`, `wateringCanCenter: CGPoint`,
`wateringCanOpacity: Double`, plus drag-tracking timestamps/points.
Constant `wateringDurationRequired: TimeInterval = 5`.

- **Overlay**: a watering-can view drawn in code (SwiftUI `Canvas`/`Shape`: a
  rounded can body + angled spout + handle, with a few falling water droplets
  near the spout while active), following the drag like `scooperImage` does.
- **Drag gesture**: same shape as `litterScooperDragGesture` — move the can with
  the finger; accumulate progress while the can's spout is over the plant frame
  (`scene?.plantFrameInScene(for:)`). Unlike litter (which requires scrubbing
  motion), watering accumulates while the spout simply stays over the plant.
- **Progress bar**: reuse the litter progress-bar style (0/5s capsule).
- **Finish** at 5s → `viewModel.waterPlant(<plant key>)`; on
  `coinsAwarded > 0` show toast "Plant watered! +6 🪙" and a plant
  sparkle/`playReaction(.happy)`; on cooldown the animation still completed but
  shows the blocked reason. Fade the can out, reset progress.
- **Cancel** (tap outside / release without finishing): fade out, keep progress
  so the user can resume (parallels litter cancel).

## 7. Economy + model (`PetEconomy.swift`, `Pet.swift`, `PetViewModel.swift`)

- `PetEconomy`: add `CareTask.waterPlant` → `coinReward = 6`;
  `plantWaterCooldown: TimeInterval = 3 * 3600`;
  `happinessFromWater: Double = 10`; a `plantWaterCooldownMessage(remaining:)`
  helper (same format as the pet/play messages).
- `PetState` (`Pet.swift`): add `lastPlantWaterAt: [String: Date]` keyed by plant
  item id, Codable with `decodeIfPresent ?? [:]` migration (per-plant cooldown so
  watering one plant doesn't lock the other).
- `PetViewModel`:
  - `func waterPlant(_ key: String) -> CareResult`: bump happiness by
    `happinessFromWater`; if the key is off cooldown, set
    `state.lastPlantWaterAt[key] = now` and `award(.waterPlant)`; otherwise
    return a `CareResult` with the cooldown blocked-reason (no coins).
  - `func canEarnWaterCoins(key:now:) -> Bool` for the inspect-card status line.

## Backward compatibility / scope

- Adding a `PetShopCategory` case surfaces a new "Plants" tab automatically if
  the market iterates `allCases`; verify the tab strip renders it (it should).
- Per-plant cooldown lives in new state with a defaulted decode, so existing
  saves load cleanly.
- Out of scope: wilting/thirst visuals (only one art frame per plant), watering
  the cat, plant growth stages, offline notifications.

## Testing

- Buy each plant; confirm it appears in the new Plants market tab with correct
  price, and renders large and transparent in the room.
- Tap a placed plant → inspect card shows the plant with a "Water" CTA.
- Tap Water → can appears; drag over the plant → progress fills to 5s → coins
  awarded (first time), happiness rises, toast shows.
- Water again immediately → animation plays but blocked-reason cooldown message,
  no coins; status line shows remaining time.
- Owning both plants: watering one does not lock the other's reward.
- Customize mode: plants are draggable/selectable and do NOT open the water
  prompt.
