# Litter Box Variants + Auto-Clean Box — Design

Date: 2026-06-02

## Goal

Integrate four new litter-box sprite sheets into the shop and the room. Each
sheet is a horizontal strip of **6 frames**. Add a premium "Auto-Clean" box that
passively cleans itself and collects the litter coins for the player.

## Sheet frame layout (per sheet, left → right)

| Index | Frame |
|-------|-------|
| 0 | clean |
| 1 | dirty |
| 2 | calico using — variant A |
| 3 | calico using — variant B |
| 4 | cow cat using — variant A |
| 5 | cow cat using — variant B |

The four sheets:
- `prop_litter_box_1_sheet` — blue plastic tray
- `prop_litter_box_2_sheet` — stainless-steel tray
- `prop_litter_box_3_sheet` — pink hooded box
- `prop_litter_box_4_sheet` — cream modern auto box

## 1. Assets

Create four imagesets in `BabyTown/Assets.xcassets/`, one per sheet, each holding
the full 6-frame PNG at 1x (matching the existing `prop_litter_box_sheet`
imageset convention with empty 2x/3x slots). Source files come from
`~/Downloads/prop_litter_box_{1..4}_sheet.png`.

## 2. Shop catalog (`PetShopCatalog.swift`)

Replace the three current litter items (`litter_classic` using the static
`prop_litter_box`, plus the art-less `litter_covered` and `litter_corner`) with
four items, each pointing `imageName` at its 6-frame sheet:

| ID | Name | Cost | Sheet | Flags |
|----|------|------|-------|-------|
| `litter_classic` | Classic Litter Box | 0 | `prop_litter_box_1_sheet` | starter |
| `litter_steel` | Stainless Steel Litter Box | 40 | `prop_litter_box_2_sheet` | — |
| `litter_hooded` | Hooded Litter Box | 70 | `prop_litter_box_3_sheet` | — |
| `litter_auto` | Auto-Clean Litter Box | 2500 | `prop_litter_box_4_sheet` | `isAutoLitter` |

Add `let isAutoLitter: Bool` to `PetShopItem` (default `false`). Add a helper
`PetShopCatalog.isAutoLitter(equippedItemID:)` returning whether the equipped
litter box is the auto box.

Backward-compat: removing `litter_covered` / `litter_corner` is safe — the scene
already falls back to the starter via `equippedImageName` / `starter(for:)` if an
unknown ID is equipped, and an unknown owned ID simply won't render.

## 3. Market thumbnail crop (`PetMarketSheet.swift`)

Litter `imageName`s are now 6-frame strips. In the preview image builder, when
`item.category == .litterBoxes`, render the **clean crop** (frame 0 = first 1/6
of the strip) instead of the full strip. Add a small helper that crops frame 0
of a sheet `UIImage` (using `cgImage.cropping(to:)` scaled by `image.scale`).
Non-litter items render unchanged.

## 4. Scene rendering (`PetRoomScene.swift`)

- `litterBoxFrameCount`: 4 → **6**.
- `LitterBoxFrame` enum: `clean=0, dirty=1, calicoUseA=2, calicoUseB=3,
  cowUseA=4, cowUseB=5`.
- Drop the single hardcoded `litterBoxSheetTexture` / `.cursor` absolute path.
  Resolve the sheet per equipped box: read
  `layoutState.equippedItemID(for: .litterBox)` → its `PetShopItem.imageName`
  (the sheet), default to `prop_litter_box_1_sheet`. Load that sheet's texture
  and slice frames from it. Cache the resolved sheet name so it rebuilds when the
  equipped box changes.
- `playLitterBoxUseAnimation(for skin:)`: pick the cat's two variant frames
  (calico → 2,3; cow → 4,5). Alternate A/B over a **total of 10 seconds**
  (e.g. ~0.5s per frame, ~10 cycles), then settle on the dirty frame and set
  `isLitterBoxDirty = true`. Replace the current single-frame + 1s wait.
- Auto box: when the equipped box `isAutoLitter`, the use animation must **not**
  leave it dirty — it should return to clean after the animation (the box cleans
  itself). The dirty/auto-collection accounting lives in the view model (below);
  the scene just renders clean for the auto box.

## 5. Auto-Clean mechanic (`PetViewModel.swift`)

Use-events are deterministic (8 AM & 8 PM Pacific), so events that occurred while
the app was closed can be reconstructed on next open via the existing
`litterUseEventsSinceLastClean(now:)`.

- `isLitterBoxDirty`: returns `false` when the equipped box is the auto box (it
  never appears dirty).
- New `@discardableResult func processAutoLitterCollection(now: Date = Date())
  -> Int`: if the auto box is equipped, count use-events since last clean, award
  `events * PetEconomy.CareTask.cleanLitter.coinReward` coins (reuse the `award`
  path / `state.coins`), reset `state.litter = StoredNeed(value: 100)` so the
  clean date advances, and return coins collected (0 if none / not auto). Drives
  the floating-coin toast via the existing `lastAward` hook.
- The view model reads the equipped litter id through `roomLayout` /
  `PetShopCatalog.isAutoLitter(equippedItemID:)`.

## 6. View wiring (`PetRoomView.swift`)

In `syncLitterBoxState()` (called on appear, scene-phase changes, and after
care actions): first call `viewModel.processAutoLitterCollection()`. If it
returns > 0, the existing coin-award feedback shows the collected coins. Then the
existing dirty/animation logic runs — which now sees `isLitterBoxDirty == false`
for the auto box, so it never plays the "dirty" path.

## Out of scope

- No offline push notifications for collected coins (collection happens on open).
- No new cleaning mini-game changes for the manual boxes.
- No "corner"-shaped box (no art for it).

## Testing

- Equip each of the four boxes; confirm the correct sheet renders clean/dirty.
- Trigger a use event; confirm the cat's two frames alternate for ~10s then the
  box shows dirty (manual boxes) / returns clean (auto box).
- With the auto box equipped, advance the clock past a use event and reopen;
  confirm coins are auto-collected and the box stays clean.
- Market: each litter item shows the clean box crop, not the full strip.
- Buy flow: `litter_auto` costs 2500 and is gated until affordable.
