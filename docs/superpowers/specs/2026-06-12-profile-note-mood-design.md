# Profile Note Mood Selector

**Date:** 2026-06-12  
**Status:** Approved

## Overview

Add an optional mood selector to the profile garden Notes modal (`ProfileNoteEditorSheet`). Users pick from 12 emotions that capture the full range of feelings when in love or starting to like someone — including complicated ones like sad, angry, confused, and jealous.

Selected mood applies two visual treatments on the note:
1. **Tint** — subtle color wash over the scrapbook note PNG
2. **Corner badge** — small circular stamp with the mood icon, bottom-right of the note

Mood is persisted on `CoupleProfile` alongside the note text.

## Decisions

| Decision | Choice |
|----------|--------|
| Layout | **A** — horizontal chip strip below the note |
| Visual treatment | **C** — tint + corner badge |
| Mood count | **12** (includes sad, angry, confused, jealous) |
| Chip overflow | Horizontal `ScrollView` (12 chips don't fit one row on small phones) |
| Mood required? | No — optional; tap selected chip again to deselect |

## Mood Palette

### Warm / bright

| Case | Label | Icon | Tint hex |
|------|-------|------|----------|
| `butterflies` | Butterflies | `sparkle` | `#E8D5F2` |
| `giddy` | Giddy | `face.smiling` | `#FFE566` |
| `smitten` | Smitten | `heart.fill` | `#F4A5B8` |
| `playful` | Playful | `bolt.heart.fill` | `#FF7B8A` |

### Soft / quiet

| Case | Label | Icon | Tint hex |
|------|-------|------|----------|
| `tender` | Tender | `heart.circle.fill` | `#FFD4C4` |
| `dreamy` | Dreamy | `moon.stars.fill` | `#C5CAF5` |
| `cozy` | Cozy | `flame.fill` | `#F5D6A8` |
| `longing` | Longing | `moon.fill` | `#9BB5E8` |

### Heavy / complicated

| Case | Label | Icon | Tint hex |
|------|-------|------|----------|
| `sad` | Sad | `cloud.rain.fill` | `#B8C5D9` |
| `angry` | Angry | `bolt.fill` | `#E07A6A` |
| `confused` | Confused | `questionmark.circle.fill` | `#D4CED8` |
| `jealous` | Jealous | `eye.fill` | `#C49BB5` |

`ProfileNoteMood` is `String`-backed, `Codable`, `CaseIterable`, with computed properties: `displayName`, `iconName`, `tintColor`.

Display order in the chip strip follows the table above (warm → soft → heavy).

## Data Model

### New file: `BabyTown/Models/ProfileNoteMood.swift`

```swift
enum ProfileNoteMood: String, CaseIterable, Codable, Equatable {
    case butterflies, giddy, smitten, playful
    case tender, dreamy, cozy, longing
    case sad, angry, confused, jealous
}
```

### `CoupleProfile` changes

Add field:

```swift
var profileNoteMood: ProfileNoteMood?
```

- Tolerant decode: `decodeIfPresent`, default `nil`
- Clearing note text also clears mood (in `saveProfileNote`)
- Existing notes without mood render as today (no tint, no badge)

## Editor UI — `ProfileNoteEditorSheet`

### Layout

```
┌─────────────────────────────┐
│  Cancel            [Save]   │
│                             │
│      ┌─────────────┐        │
│      │  note PNG   │ ♡      │  ← corner badge
│      │  + tint     │        │
│      │  "your text"│        │
│      └─────────────┘        │
│                             │
│  ◀ ✨ 😊 ❤️ ⚡ 💗 🌙 🔥 … ▶ │  ← scrollable chip strip
│                             │
└─────────────────────────────┘
```

### Chip strip (`ProfileNoteMoodPicker`)

- Horizontal `ScrollView`, `.scrollIndicators(.hidden)`
- 12 circular chips, ~40pt diameter, 10pt spacing
- Each chip: SF Symbol in mood tint on soft white circle (`Color.white.opacity(0.85)`)
- Selected chip: 2pt ring in mood tint, `scaleEffect(1.08)`, light haptic (`UIImpactFeedbackGenerator`)
- Tap selected chip again → deselect (`nil` mood)
- Accessibility: `accessibilityLabel` = mood display name; `.isSelected` trait when active
- On select: `ScrollViewReader` scrolls chip into center

### Note preview (live)

Extract shared chrome into a reusable component used by both editor and garden.

**Tint:** `mood.tintColor.opacity(0.22)` overlay on note PNG using `.overlay` with default blend (soft wash, not harsh multiply).

**Badge:** 22pt circle, offset bottom-right inside note bounds (8pt inset from corner):
- Fill: `mood.tintColor`
- Icon: mood SF Symbol, white, ~11pt
- Shadow: `black.opacity(0.12)`, radius 3, y 1

### Save callback

Change from `(String) -> Void` to:

```swift
(String, ProfileNoteMood?) -> Void
```

Init gains `initialMood: ProfileNoteMood?` parameter.

## Garden Canvas — `ProfileGardenNoteChrome`

Add optional `mood: ProfileNoteMood?` parameter. When non-nil, apply same tint + badge as editor preview. Text styling unchanged (warm brown ink `#614D3D`).

### Propagation

- `ProfileGardenNoteView` accepts `mood: ProfileNoteMood?`, passes to chrome
- `ProfileStickersLayer` passes `profileNoteMood` from profile
- `CoupleProfileView.saveProfileNote` persists both text and mood

## Files Affected

| File | Change |
|------|--------|
| `BabyTown/Models/ProfileNoteMood.swift` | **New** — enum + display properties |
| `BabyTown/Models/CoupleProfile.swift` | Add `profileNoteMood` field + decode |
| `BabyTown/Views/CoupleProfile/ProfileNoteEditorSheet.swift` | Chip strip, mood state, updated callback |
| `BabyTown/Views/CoupleProfile/ProfileGardenNoteView.swift` | Tint + badge on chrome; mood picker component |
| `BabyTown/Views/CoupleProfile/CoupleProfileView.swift` | Wire mood through editor + save |
| `BabyTown/Views/CoupleProfile/ProfileStickersLayer.swift` | Pass mood to note view |

## Out of Scope

- Mood on memory-page notes (`MemoryPageNote`) — profile garden only
- Custom / user-defined moods
- Partner mood sync or backend persistence beyond local `CoupleProfile`
- Mood-based garden animations or sound
- Bittersweet, anxious, guilty moods (future expansion)

## Testing Checklist

- [ ] Open note editor on profile with no existing note — chips render, no selection
- [ ] Select each of 12 moods — tint + badge update live in editor
- [ ] Tap selected mood again — deselects, note returns to plain
- [ ] Save note with mood — garden note shows tint + badge
- [ ] Re-open editor — mood pre-selected in chip strip
- [ ] Save empty note text — mood cleared
- [ ] Existing profile with note but no mood — renders unchanged (backward compat)
- [ ] Scroll chip strip on iPhone SE / small device — all 12 reachable
- [ ] VoiceOver reads mood names on chips
