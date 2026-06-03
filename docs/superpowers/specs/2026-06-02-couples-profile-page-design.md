# Couples Profile Page — Design Spec (v1)

Date: 2026-06-02
Status: Slice 1 approved for implementation (design only — no implementation yet)

## 1. Vision

The garden screen evolves into the **Couples Profile Page ("Us")** — a living,
personal home for the relationship. The garden built in the Love Garden Slice 1
becomes the **full-screen living backdrop**; the couple's identities, foundational
milestones, special dates, and a path to the shared pet float on top of it. It is
the emotional centerpiece the Love Garden spec envisioned (the "Us" page), now
given a concrete layout.

This document covers the whole feature at a high level (§3 decomposition) and
specifies **Slice 1** (the page shell + Important Dates) in build detail (§5+).
Later slices (stickers, customize, garden polish, partner backend) are scoped but
not detailed here.

## 2. Relationship to existing specs

- Supersedes the layout sketch in the Love Garden spec §6 ("Us page anatomy").
- Inherits the Love Garden spec's hard constraints: **no partner sync backend
  exists** (`PartnerInvite` is an invite code only), and the kindness model of the
  garden is unchanged.
- The garden itself (scene, blooms, persistence) is reused as-is as the page
  background; this feature does not alter `LoveGardenScene` behavior.

## 3. Feature decomposition (5 subsystems)

The original request is five independent subsystems. They are built and shipped
as separate slices, each its own spec→plan→implementation cycle:

1. **Couples Profile Page shell + Important Dates** — THIS SLICE (§5). Back
   button, header with two profile avatars, foundational + special dates, Visit
   Pet button. The skeleton everything else hangs on.
2. **Sticker system** — subject-lifted photo cutouts
   (`VNGenerateForegroundInstanceMaskRequest`), draggable repositioning, Customize
   mode, position persistence, pet-as-sticker. Highest-risk / most novel; isolated
   deliberately. Needs a graceful fallback (circular crop) when subject-lift fails.
3. **Garden visual polish** — SpriteKit pass (lighting, shaders, parallax depth,
   richer procedural blooms, sky gradient/day-night). Independent eye-candy.
4. **Partner identity (real)** — the partner's self-authored profile, which
   **requires the partner-sync backend** and is therefore Phase-2 gated.
5. (Glue) Visit Pet flow + cat-skin integration, refined across slices.

## 4. Build decisions (made during brainstorming)

- **First slice:** the Profile Page shell + Important Dates (skeleton first).
- **Page structure:** the garden is a **full-screen live background**; all profile
  UI floats over it in translucent cards. Technically realized as a `ZStack` with
  a non-scrolling `SpriteView` background layer and a `ScrollView` of glass cards
  on top — only the cards scroll, so we avoid the SpriteKit-inside-ScrollView perf
  trap.
- **Profile ownership:** a user edits **only their own** profile. The partner
  authors their own on their own device — which needs the sync backend. So in
  Slice 1 the partner slot is an **invite / pending placeholder**, replaced by the
  partner's real profile when the backend lands.
- **Avatars in Slice 1:** simple circular-cropped photos. Subject-lift sticker
  cutouts are Slice 2.
- **Customize button:** deferred to the sticker slice (nothing is draggable in
  Slice 1), so it is omitted from the Slice 1 header rather than shipped dead.

## 5. Slice 1 — scope

### 5.1 The page (`CoupleProfileView`)
The current garden screen (`LoveGardenView`) becomes `CoupleProfileView`. Layout:

```
 [< back]                                  (no customize btn in Slice 1)
 +--------------------------------------------------+
 |  ( you )            ( + invite )                  |   header, floats over garden
 |   editable          pending/locked               |
 |                                                  |
 |   ~~~ live garden background everywhere ~~~       |
 |  .----------------------------------------.      |
 |  | IMPORTANT DATES                        |      |   glass cards
 |  |  First met   Feb 14 2024   [photo]     |      |   scroll over the garden
 |  |  Official    Jun 01 2024   [photo]     |      |
 |  |  ------------------------------------- |      |
 |  |  Anniversary Jun 01 2025   [photo]  ⋯  |      |
 |  |  [ + Add special date ]                |      |
 |  '----------------------------------------'      |
 |  .----------------------------------------.      |
 |  |  [ Visit Pet   (cat portrait) ]        |      |
 |  '----------------------------------------'      |
 +--------------------------------------------------+
```

- `ZStack`: garden `SpriteView` background (reuses the Slice-1 garden compose/scene
  logic, currently in `LoveGardenView.buildGarden`); foreground header + scrolling
  glass cards.
- The garden background must not rebuild on every scroll; it is built once on
  appear (as today).

### 5.2 Header (floats over the garden)
- **Back button (top-left):** returns to Home for now. (Temp entry route from the
  Love Garden Slice 1 remains until the cat-room door slice replaces it.)
- **Two avatar slots:** circular photos.
  - **Your slot:** tappable → pick a photo from the library (circular crop) + a
    display name (pre-filled from the existing saved nickname,
    `loadUserNickname()`). Persisted locally. Editable only by you.
  - **Partner slot:** locked "Invite your partner to create their profile" state
    with a Share-invite CTA built from `PartnerInvite.current()`. No local editing
    of the partner's identity.
- **No Customize button** in Slice 1.

### 5.3 Important Dates card
- **Foundational dates (read-only here):** "When we first met" and "When we became
  official", each showing title + date + photo, read from existing storage
  (`loadFoundingPhotoDate(promptText:)`, `loadPinnedFirstMet()`,
  `loadPinnedOfficial()`). Tapping a foundational date views its photo. Editing the
  foundational dates stays where it already lives in the app (single source of
  truth — not duplicated here).
- **Special dates (full CRUD here):** add (title + date + optional photo), edit,
  delete. Persisted locally.
- **Ordering:** foundational + special dates are merged and **sorted
  chronologically** into one list. This merge+sort is a pure, unit-tested helper.

### 5.4 Visit Pet card
- A button showing the current cat's portrait (`CatSkin.portraitAsset`, Calico or
  Cow-cat) that opens the existing Visit Pet flow (the `AdoptAPetRootView` overlay
  pattern already used by `HomeView`).
- The pet-as-draggable-sticker is Slice 2.

## 6. Data model & persistence (Slice 1)

Conceptual (implementation shapes finalized in the plan):

- **`SpecialDate`** — `Codable`, `Identifiable`: `id: UUID`, `title: String`,
  `date: Date`, optional photo reference. User-authored special dates only.
- **`CoupleProfile`** — `Codable`: the local user's `displayName`, optional avatar
  reference, and `[SpecialDate]`. Partner identity is **not** stored here (it is
  backend-authored later). Tolerant decode (default-on-missing), mirroring
  `PetState`/`GardenState`, so the format can grow.
- **Foundational dates & couple photos:** read from existing
  `DataPersistenceManager` APIs — not duplicated.
- **Persistence:** new `DataPersistenceManager` methods (save/load `CoupleProfile`;
  save/load user avatar image to the pinned-photos directory; save special-date
  photos), following existing file/JSON patterns. Avatar and special-date images
  are stored as files (like the existing pinned photos), referenced by path/name
  in the Codable model — images are not embedded in JSON.

## 7. Pure, testable logic

To preserve the established `swift test` discipline (the app has no XCTest
target), the **date merge + chronological sort** is a pure function over UI-free
value types, unit-tested in a local Swift package (reusing the package pattern
established by `GardenCore`). Inputs: the (date, title) of the two foundational
entries plus the list of special dates; output: one chronologically ordered list
of lightweight date items the view renders. Image loading and persistence stay in
the app target and are verified via build + simulator.

## 8. Architecture / decomposition

`CoupleProfileView` is split into focused subviews so no file does too much:
- `CoupleProfileView` — the `ZStack` page (garden background + scroll content),
  owns load/save and navigation callbacks (back, open Visit Pet).
- `CoupleHeaderView` — back button + the two avatar slots.
- `ProfileAvatarSlot` — one circular avatar (editable "you" variant + locked
  "invite" variant).
- `ImportantDatesCard` — foundational + special list, add/edit/delete entry points.
- `SpecialDateEditorSheet` — add/edit a special date (title, date, optional photo).
- `VisitPetCard` — the cat-portrait button.

Each communicates through explicit inputs/closures; persistence is funneled through
`DataPersistenceManager`.

## 9. Validation / testing considerations

- Date merge/sort: pure unit tests (foundational + special merge, chronological
  order, empty/edge cases).
- Your profile: pick photo + name persists across app restart (tolerant decode).
- Partner slot: shows the invite/pending state and the share CTA; never allows
  editing a partner identity.
- Important Dates: foundational read from existing data and render with photo;
  special dates add/edit/delete and survive restart; combined list is sorted.
- Visit Pet: opens the existing pet flow with the correct cat skin.
- Garden background renders once and is not disturbed by scrolling the cards.
- Verify in the simulator via the existing temporary entry route (per project
  memory: route the entry point; trust `xcodebuild` over SourceKit).

## 10. Out of Slice 1 scope (later slices)

- Subject-lift sticker cutouts + circular-crop fallback.
- Draggable stickers + Customize mode + position persistence + pet-as-sticker.
- Garden visual polish (SpriteKit lighting/shaders/parallax).
- Real self-authored partner profile (partner-sync backend, Phase 2).
- Cat-room door entry replacing the temporary route.
