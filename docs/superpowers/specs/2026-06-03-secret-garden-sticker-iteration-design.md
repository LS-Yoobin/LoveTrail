# Secret Garden — Sticker & Layout Iteration

**Date:** 2026-06-03
**Branch:** secretgarden
**Status:** Design approved

## Goal

Iterate the Couples Profile Page ("Secret Garden") so the informational cards and
the profile sticker canvas swap emphasis, profile avatars become first-class
draggable/resizable stickers, stray stickers can be deleted, and the top/bottom
chrome stops colliding with the device safe areas.

## Background

`CoupleProfileView` renders a full-bleed living-garden background with a scrolling
column of glass content on top:

1. `avatarHeaderSection` — `CoupleProfileAvatarHeader`, a static centered pair (your
   cutout + partner "Invite partner" heart slot).
2. `profileCardsSection` — `OurHistoryCard`, `ImportantDatesPreviewCard`,
   `PinnedMemoriesPreviewCard`.

A separate `ProfileStickersLayer` overlay draws moment / special-date stickers, but
it **excludes** `.userAvatar` and `.partnerInvite` (`visibleStickers` filter) and the
whole layer has `.allowsHitTesting(false)`, so no sticker is currently draggable and
the profile avatars are never movable. The avatars are drawn statically in the header
instead.

Known problems visible in the current build (see `IMG_9536`):

- Two stray cutout stickers (a faint white blob, a dark blob clipped at the right
  edge) float in the band above "Our History". They are persisted `.moment` stickers
  with near-empty cutouts, and there is **no delete affordance**, so the user cannot
  remove them.
- `EditGardenHeaderView` (Back / Save) and both footer bars sit under the status bar
  clock/battery and near the bottom edge, because the entire view tree (chrome
  included) uses `.ignoresSafeArea()`.

## Requirements

### 1. Layout reorder

Inside the scroll, render the cards section **first**, then the sticker canvas.
(Today it is avatar header first, then cards.) The profile avatars no longer have a
dedicated static header — they live in the sticker layer (Requirement 2).

- **Browse mode:** opens scrolled to the top → cards (`Our History`, `Important
  Dates`, `Pinned Memories`) visible; stickers float over their saved positions.
- **Edit mode:** opens scrolled down so the **sticker canvas sits at the top of the
  viewport** (cards tucked above, out of the initial view — the "moved to top" focus
  feel). The cards are **not removed**; they stay in the scroll and remain reachable
  by scrolling up, but are **non-interactive** while editing so stickers can be
  dragged on top of them.

### 2. Profile avatars as first-class stickers

Promote the **user avatar** and the **partner** slot into `ProfileStickersLayer` so
each is independently draggable and pinch-resizable, exactly like photo stickers.

- Stop drawing them statically; remove/repurpose `CoupleProfileAvatarHeader`'s role
  as the top section.
- `ProfileStickersLayer.visibleStickers` must include `.userAvatar` and
  `.partnerInvite`; the layer must enable hit-testing in edit mode (it is currently
  fully disabled).
- `ProfileStickerSync` must stop deleting `.partnerInvite` stickers and must ensure a
  single persistent `.partnerInvite` sticker exists (it renders the heart
  placeholder / "Invite partner" or "Send invite" label via `partnerInviteBody`).
  The `.userAvatar` sticker already syncs.
- Tapping the partner sticker in **browse** mode still triggers the invite/paywall
  flow; tapping the user sticker still opens the profile editor. In **edit** mode,
  taps drive selection/drag instead.

### 3. Stable full-canvas coordinate space

Sticker positions are normalized (0…1) over the **full scroll content height**
(cards + canvas), and that content height must be **identical between browse and edit
mode**. Because edit mode keeps the cards in place (just scrolled away and
non-interactive), the coordinate space does not change, so stickers never drift
between modes. A sticker may be positioned anywhere from the very top (over the
cards) down to the bottom of the canvas.

### 4. Sticker delete affordance

In edit mode, tapping a sticker selects it and shows a **trash icon just above it**.
Tapping the trash removes that sticker: deletes its cutout image, removes it from
`CoupleProfile.stickers`, and persists. This is the durable fix for the stray
white/black blobs and any future unwanted sticker.

- The user-avatar and partner stickers should **not** be permanently deletable in a
  way that breaks the page; deleting the user avatar reverts it to the "add photo"
  affordance, and the partner sticker is re-synced (it always exists). Practically:
  the trash on `.moment` / `.specialDate` stickers removes them; the trash is hidden
  for `.userAvatar` / `.partnerInvite` (or, if shown, it only resets rather than
  destroys). Default: **hide trash for `.userAvatar` and `.partnerInvite`.**

### 5. Safe-area chrome fix

Keep the garden background full-bleed, but make the chrome respect the safe area:

- `EditGardenHeaderView` (Back / Save) clears the status-bar clock/battery.
- `CoupleProfileFooterBar` (Visit Pet Room / Edit Garden) and `EditGardenFooterBar`
  (Add Love Story / Create Stickers) lift off the bottom edge / home indicator.

Approach: the background layers keep their own `.ignoresSafeArea()`; remove the
blanket `.ignoresSafeArea()` from the chrome container so the header + footers sit
inside the safe area.

## Architecture & components

- **`CoupleProfileView`** — reorder sections (cards then canvas); drive a
  `ScrollViewReader` to anchor scroll position on `isCustomizing` toggle; pass
  selection + delete callbacks down; fix the safe-area handling on the chrome
  container while leaving background layers full-bleed.
- **`ProfileStickersLayer`** — include `.userAvatar` and `.partnerInvite` in
  `visibleStickers`; enable hit-testing in edit mode; thread through a `selectedID`
  binding and an `onDelete` callback.
- **`ProfileStickerView`** — add a selected state; render the trash button above the
  sticker when selected and editing (suppressed for `.userAvatar` /
  `.partnerInvite`); keep existing drag + pinch gestures; route browse-mode taps to
  the appropriate action (user → edit profile, partner → invite flow).
- **`ProfileStickerSync`** — keep a single persistent `.partnerInvite` sticker
  instead of deleting them; keep `.userAvatar` sync.
- **`CoupleProfileAvatarHeader` / `ProfileAvatarSlot`** — no longer the top section;
  remove or reduce to whatever (if anything) is still needed. The heart placeholder /
  name-pill visuals already exist in `ProfileStickerView.partnerInviteBody` and the
  sticker label.
- **`EditGardenHeaderView`, `EditGardenFooterBar`, `CoupleProfileFooterBar`** —
  safe-area-aware padding (handled at the container, not per-bar, where possible).

## Data flow

- `load()` / `refreshStickers()` continue to sync stickers via `ProfileStickerSync`.
  Now the synced set includes the partner sticker.
- Drag → `updateStickerPosition`; pinch → `updateStickerScale` (unchanged, now also
  applies to avatar + partner stickers).
- Delete → new `deleteSticker(id:)` on `CoupleProfileView`: removes from
  `profile.stickers`, calls `dpm.deleteStickerImage(id:)`, saves the profile, and
  clears `stickerImages[id]`.
- Selection state (`selectedStickerID`) lives in `CoupleProfileView`, cleared when
  leaving edit mode or tapping empty canvas.

## Edge cases / error handling

- Deleting the user-avatar source elsewhere already removes its sticker via sync;
  the page falls back to the "add photo" path. (Avatar/partner trash hidden per R4.)
- Tapping empty canvas in edit mode deselects (hides any visible trash).
- Stickers clamp to the existing drag bounds; positions over the card region are
  allowed (no special clamp needed beyond current 0.06…0.94 / 0.10…0.92).
- Partner sticker label switches between "Invite partner" and "Send invite" based on
  `store.isPartnerUnlocked`, as today.

## Testing

- Manual verification in the simulator (no tap tooling): temporarily route the app
  entry to `CoupleProfileView`, confirm:
  - Card order (History → Dates → Pinned), browse opens at top.
  - Entering edit mode anchors the canvas to the top; scrolling up reveals cards.
  - User + partner stickers drag and pinch-resize; positions persist across
    browse/edit and relaunch with no drift.
  - Tap sticker → trash above → delete removes it; the stray blobs can be removed.
  - Back/Save clear the clock; footers clear the home indicator.
- `GardenCore` Swift package tests still pass (`swift test`) — no GardenCore changes
  expected, but run to confirm.
- Trust `xcodebuild` over SourceKit diagnostics for build verification.

## Out of scope

- "Add Love Story" remains a Coming-Soon alert.
- No changes to the garden SpriteKit scene, pet roaming, or the subpage feeds
  (`ImportantDatesListView`, `PinnedMemoriesFeedView`).
- No redesign of the cards themselves.
