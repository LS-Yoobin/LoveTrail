# Flower Achievement Sheet — Design Spec

Date: 2026-06-25
Status: Approved for implementation

## 1. Overview

When a user taps any flower (or tree) in the Love Garden, a large sheet opens that does two things: (1) highlights the specific bloom that was tapped with its name and significance, and (2) shows every bloom type in the game as a collectible achievement grid — earned blooms in full color, locked ones desaturated with their unlock condition. The feel is a game achievement/collection menu, not a memory card.

This replaces the existing `GardenMemoryCard` and `LegendBloomCard` sheets.

## 2. Sheet layout

Single `presentationDetent(.large)` sheet — `FlowerAchievementSheet`.

Top to bottom inside a `ScrollView`:

1. **Drag handle + title** — "Garden Blooms" centered header
2. **Hero card** — the tapped bloom:
   - Rendered bloom image, ~140×160pt, centered
   - Bloom name (e.g. "Horizon Bouquet")
   - Significance text (e.g. "40 memories planted together")
   - If moment-sourced: small "Earned · [place] · [date]" caption
   - If legend/shrine: sparkle badge overlay
   - Gold border to distinguish it as the active entry
3. **Section header** — "Your Collection"
4. **2-column achievement grid** — all 10 bloom types:
   - Earned: full-color rendered image + small checkmark badge
   - Not yet earned: greyscale rendered image + lock icon + unlock condition caption
   - The tapped bloom's grid card also shows the gold border ("you are here")

## 3. Bloom catalog

Ten fixed entries derived from the garden's current elements:

| Entry | Chapter | Shape | isLegend | Unlock condition | Earned when |
|---|---|---|---|---|---|
| First Bouquet | white | daisy12 | false | Reach 10 moments | basicMilestone threshold 10 exists |
| Sunbeam Bouquet | yellow | daisy12 | false | Reach 20 moments | threshold 20 |
| Ember Bouquet | red | daisy12 | false | Reach 30 moments | threshold 30 |
| Horizon Bouquet | blue | daisy12 | false | Reach 40 moments | threshold 40 |
| Twilight Bouquet | purple | daisy12 | false | Reach 50 moments | threshold 50 |
| Twilight Shrine | purple | tulip3 | true | 50 memories together | milestone50 element exists |
| Eclipse Shrine | black | lotus8 | true | 100 memories together | milestone100 element exists |
| Birthday Bloom | birthday | daisy12 | false | Add a birthday | any `.birthdayFlower` exists |
| Anniversary Bloom | anniversary | lotus8 | false | Add your anniversary | any `.anniversaryFlower` exists |
| Love Tree | — | — | false | Write a love letter | any `.tree` exists |

`BloomCatalogEntry` is a pure value type: `chapter`, `shape`, `isLegend`, `displayName`, `subtitle`, `unlockCondition: String`, `isEarned: Bool`.

`BloomCatalogBuilder` derives all 10 entries from `[GardenElement]` — no side effects, no persistence reads.

## 4. Bloom image rendering

`BloomImageRenderer` renders each bloom type as a `UIImage` using the same `SKView + texture` pattern as `GardenSnapshotRenderer`:

- For each catalog entry, creates a `BloomSnapshotScene: SKScene` — clear background, no ground/sky/hills
- Places one centered flower (or tree) node at 100×130pt scene size
- Calls `LoveGardenScene.makeFlower(...)` / `makeTree()` to build the node (both widened from `private` to `internal`)
- Renders via `SKView.texture(from:)` using the existing `waitForRenderPass` double-dispatch pattern
- Caches each result in `[String: UIImage]` keyed by `"\(chapter.rawValue)-\(shape.rawValue)-\(isLegend)"` for bloom types and `"tree"` for the Love Tree, so each type renders only once per session
- Grid cells show a `ProgressView` placeholder while async render runs, then crossfade in

The Love Tree entry renders via `LoveGardenScene.makeTree()` using the `"tree"` cache key (no chapter/shape needed).

## 5. Data flow

`LoveGardenView` already holds `gardenElements: [GardenElement]` and `moments: [Moment]`. On tap:

1. `handleBloomTap(id:)` resolves the tapped `GardenElement`
2. Optionally resolves `FlowerSourceContext` (place name + date) if the element maps to a `Moment`
3. Sets `tapPresentation` to the single new case: `.flower(tappedElement, gardenElements, sourceContext?)`

`GardenTapPresentation` collapses from two cases to one. `FlowerAchievementSheet` takes `tappedElement`, `gardenElements`, and optional `sourceContext` and handles all rendering internally.

```
FlowerSourceContext {
    placeName: String?
    date: Date
}
```

## 6. Files changed

| File | Change |
|---|---|
| `BabyTown/Game/Garden/LoveGardenScene.swift` | `makeFlower` and `makeTree` from `private` → `internal` |
| `BabyTown/Services/BloomImageRenderer.swift` | New — renders individual bloom UIImages, caches by key |
| `BabyTown/Game/Garden/BloomSnapshotScene.swift` | New — minimal SKScene for single-bloom rendering |
| `BabyTown/Models/BloomCatalogEntry.swift` | New — value type + `BloomCatalogBuilder` |
| `BabyTown/Views/FlowerAchievementSheet.swift` | New — the achievement sheet view |
| `BabyTown/Views/LoveGardenView.swift` | Replace two sheet cases with one `.flower(...)` case; update `handleBloomTap` |

## 7. Out of scope

- Persisting "first time unlocked" animations (e.g. pop-in on first earn). Deferred.
- Premium gating on specific bloom types. Deferred.
- Sharing the collection screen as an image. Deferred.
