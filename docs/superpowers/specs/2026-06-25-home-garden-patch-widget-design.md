---
name: home-garden-patch-widget
description: Design spec for the HomeGardenPatchView widget — grass patch with interactive pet house and mailbox placed between the Our Garden card and Pinned Memories on the Home feed.
status: approved
date: 2026-06-25
---

# Home Garden Patch Widget

## Overview

A decorative-but-interactive scene widget inserted into the Home feed scroll view, between the "Our Garden" (`CoupleSpaceCard`) and the "Pinned Memories" section. It renders a grass oval island with a tappable pet house (left) and a tappable mailbox (right), using four new image assets.

The mailbox shows two states: empty (no unread mail) and full (has unread mail). The pet house navigates to the pet room. The mailbox is visual-only for now, with backend wiring deferred to the inbox feature.

---

## Layout

The widget is a fixed-height (~160pt) container with no card border or background fill of its own. Three layers compose a `ZStack`:

1. **Grass oval** — `home_grass_patch` image, resizable, fills full width, centered. Non-interactive.
2. **Pet house** — `home_pet_house` image, positioned lower-left, partially overlapping the grass bottom edge. Tappable.
3. **Mailbox** — `home_mailbox_empty` or `home_mailbox_full` image, positioned lower-right, same vertical rhythm as the pet house. Tappable.

Placement matches the Figma mockup: grass behind both objects, no explicit border, floats naturally against the scroll background.

Inserted in `HomeView`'s scroll `VStack` immediately after `CoupleSpaceCard` and before `OnThisDaySection` / `pinnedSection`.

---

## Component

**File:** `BabyTown/Components/HomeGardenPatchView.swift`

```swift
struct HomeGardenPatchView: View {
    let hasUnreadMail: Bool
    let onPetHouseTap: () -> Void
    let onMailboxTap: () -> Void
}
```

- `hasUnreadMail` drives the mailbox image: `true` → `home_mailbox_full`, `false` → `home_mailbox_empty`
- Both objects are independently wrapped in `Button` with `.plain` style
- The grass image is non-interactive (`allowsHitTesting(false)`)
- No animation on the mail state change (static swap)

---

## State and Data

### HomeView side

```swift
@State private var hasUnreadMail = false
```

Read from `DataPersistenceManager` on `.onAppear`. No write path in this phase.

### DataPersistenceManager

New method:

```swift
func loadHasUnreadMail() -> Bool
```

Backed by a UserDefaults key `"hasUnreadMail"`, defaults to `false`. This is a placeholder — when the real inbox backend ships, this method is replaced with a real unread-count check and the call site in HomeView does not change.

---

## Navigation

| Tap target | Action |
|---|---|
| Pet house | `showVisitPet = true` → presents `AdoptAPetRootView` (already exists) |
| Mailbox | No-op for now |

---

## Assets

Four new imagesets added to `BabyTown/Assets.xcassets`. Each is a single universal scale image (1x only, as these are high-res illustrations).

| Imageset name | Contents |
|---|---|
| `home_grass_patch` | Oval grass island with stepping stones and flowers |
| `home_pet_house` | Pet house with red roof, paw detail, flower box |
| `home_mailbox_empty` | Mailbox closed, no letters, flag down |
| `home_mailbox_full` | Mailbox open with letters spilling out, flag up |

The implementation plan creates the `Contents.json` for each imageset. The actual PNG files must be dragged into each imageset folder in Xcode by the developer.

---

## Out of Scope

- Inbox view or mail detail screen
- Write path for `hasUnreadMail`
- Animation on mailbox state transition
- Partner-sent mail or system mail data model
- Night mode variant for the widget (assets render naturally against both backgrounds)
