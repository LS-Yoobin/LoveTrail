# Secret Garden Sticker & Layout Iteration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorder the Couples Profile Page so the info cards sit above an open sticker canvas, promote the user + partner avatars into freely draggable/resizable stickers with a delete affordance, and stop the top/bottom chrome from colliding with the device safe areas.

**Architecture:** `CoupleProfileView` hosts a full-bleed garden background plus a scroll column. We reorder the column (cards first, then an open canvas spacer), draw all stickers — including user avatar + partner — in a single `ProfileStickersLayer` overlay normalized over the full scroll content, enable edit-mode hit-testing with selection + per-sticker trash, anchor the scroll to the canvas when entering edit mode, and confine the chrome (header/footers) to the safe area while the background keeps bleeding full-screen.

**Tech Stack:** SwiftUI, SpriteKit (garden background, unchanged), local `GardenCore` Swift package (unchanged here). No app unit-test target exists; verification is `xcodebuild` compile + manual simulator routing (see memory: "Verifying UI in the simulator").

**Spec:** `docs/superpowers/specs/2026-06-03-secret-garden-sticker-iteration-design.md`

**Build/verify command used throughout:**
```bash
xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected on success: `** BUILD SUCCEEDED **`. Trust this over SourceKit/IDE diagnostics.

---

## Task 1: Safe-area chrome fix

Make Back/Save and both footer rows respect the safe area while the garden background stays full-bleed. Today the whole tree uses `.ignoresSafeArea()`, pushing chrome under the clock and onto the home indicator.

**Files:**
- Modify: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift:119-194`

- [ ] **Step 1: Scope the full-bleed to the background only**

In `CoupleProfileView.body`, the outer modifier currently reads (lines ~193-194):

```swift
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
```

Remove the blanket `.ignoresSafeArea()` so the chrome (`VStack` with header + scroll + footers) is laid out inside the safe area:

```swift
        .frame(maxWidth: .infinity, maxHeight: .infinity)
```

The two background layers keep their own full-bleed (no change): `Color(...).ignoresSafeArea()` at line ~123 and `GardenBackgroundView(...).ignoresSafeArea()` at line ~132. These still fill the whole screen behind the safe-area-confined chrome.

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/CoupleProfileView.swift
git commit -m "fix(garden): keep chrome inside safe area, background full-bleed"
```

---

## Task 2: Persistent partner sticker in sync

`ProfileStickerSync` currently deletes every `.partnerInvite` sticker. Change it to guarantee exactly one persistent `.partnerInvite` sticker (renders the heart placeholder; needs no stored image), so the partner slot can live in the draggable layer.

**Files:**
- Modify: `BabyTown/Services/ProfileStickerSync.swift:50` and `:96-106`
- Modify: `BabyTown/Models/ProfileSticker.swift` (add a partner default position constant)

- [ ] **Step 1: Add a partner default position constant**

In `ProfileSticker` (`BabyTown/Models/ProfileSticker.swift`), after `static let cutoutBaseSize: CGFloat = 84` (line ~27), add:

```swift
    /// Default normalized position for a freshly synced partner-invite sticker
    /// (lower-right of the open canvas, beside the user avatar).
    static let defaultPartnerPosition = NormalizedPoint(x: 0.70, y: 0.62)
    /// Default normalized position for a freshly synced user-avatar sticker.
    static let defaultUserAvatarPosition = NormalizedPoint(x: 0.30, y: 0.62)
```

- [ ] **Step 2: Replace partner removal with ensure-one logic**

In `ProfileStickerSync.sync(...)`, line ~50 currently calls:

```swift
        removePartnerInviteStickers(stickers: &stickers, bySource: &bySource, dpm: dpm)
```

Replace that call with:

```swift
        ensurePartnerInviteSticker(stickers: &stickers, bySource: &bySource, dpm: dpm)
```

Then replace the whole `removePartnerInviteStickers(...)` function (lines ~96-106) with:

```swift
    /// Guarantees exactly one persistent partner-invite sticker. It renders a heart
    /// placeholder (no stored image) and is draggable like any other sticker.
    private static func ensurePartnerInviteSticker(
        stickers: inout [ProfileSticker],
        bySource: inout [String: ProfileSticker],
        dpm: DataPersistenceManager
    ) {
        let existing = stickers.filter { $0.kind == .partnerInvite }
        // Collapse any duplicates down to the first; delete extras' images.
        if existing.count > 1 {
            for extra in existing.dropFirst() {
                dpm.deleteStickerImage(id: extra.id)
            }
            let keepID = existing.first!.id
            stickers.removeAll { $0.kind == .partnerInvite && $0.id != keepID }
        }
        if existing.isEmpty {
            let sticker = ProfileSticker(
                kind: .partnerInvite,
                sourceKey: "partnerInvite",
                position: ProfileSticker.defaultPartnerPosition,
                rotation: 0,
                scale: ProfileSticker.defaultScale
            )
            stickers.append(sticker)
            bySource[sticker.sourceKey] = sticker
        }
    }
```

- [ ] **Step 3: Point the user-avatar default at the canvas**

In `ProfileStickerSync`, the user-avatar `ensure(...)` (line ~47-48) passes `defaultPosition: Self.canonicalUserAvatarPosition`. Change that argument to the new model constant so new avatars land in the open canvas beside the partner:

```swift
        ensure(.userAvatar, sourceKey: "userAvatar", image: dpm.loadUserAvatar(),
               defaultPosition: ProfileSticker.defaultUserAvatarPosition)
```

Leave the legacy-migration block (lines ~52-55) and `canonicalUserAvatarPosition` / `isLegacyUserAvatarPosition` as-is — they only re-home stickers stored at the old `(0.28, 0.24)` legacy spot and do not affect already-customized positions.

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Services/ProfileStickerSync.swift BabyTown/Models/ProfileSticker.swift
git commit -m "feat(garden): keep a persistent draggable partner-invite sticker"
```

---

## Task 3: Sticker selection + trash + browse taps in `ProfileStickerView`

Add a selected state, a trash button that appears above a selected sticker in edit mode, and route browse-mode taps. Trash is suppressed for `.userAvatar` / `.partnerInvite` (passing `onDelete: nil`).

**Files:**
- Modify: `BabyTown/Views/CoupleProfile/ProfileStickerView.swift`

- [ ] **Step 1: Add selection + callback inputs**

In `ProfileStickerView`, extend the stored properties (after `var onTap: (() -> Void)?`, line ~10):

```swift
    var onTap: (() -> Void)?
    let isSelected: Bool
    var onSelect: (() -> Void)?
    var onDelete: (() -> Void)?
    let onPositionChanged: (NormalizedPoint) -> Void
    let onScaleChanged: (CGFloat) -> Void
```

- [ ] **Step 2: Render the trash button above a selected sticker**

Replace the `body` (lines ~27-64) with the version below. It keeps the existing layout/gestures and adds (a) a trash button overlay above the sticker when selected + editing + deletable, (b) `onSelect` on edit-mode tap:

```swift
    var body: some View {
        let side = ProfileSticker.renderedSize(scale: effectiveScale)
        let center = CGPoint(
            x: sticker.position.x * canvasSize.width,
            y: sticker.position.y * canvasSize.height
        )

        VStack(spacing: 8) {
            stickerBody(side: side)

            if let label {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black, in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .rotationEffect(.degrees(sticker.rotation))
        .overlay(alignment: .top) {
            if isCustomizing, isSelected, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.red, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .offset(y: -44)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .position(center)
        .allowsHitTesting(isCustomizing || onTap != nil)
        .onAppear { pinchBaseScale = sticker.scale }
        .onChange(of: sticker.scale) { _, newScale in
            pinchBaseScale = newScale
            pinchPreviewScale = nil
        }
        .gesture(
            isCustomizing
                ? SimultaneousGesture(dragGesture, pinchGesture)
                : nil
        )
        .onTapGesture {
            if isCustomizing {
                onSelect?()
            } else {
                onTap?()
            }
        }
    }
```

- [ ] **Step 3: Show a selection ring while editing**

In `stickerBody(side:)` (lines ~66-91), the `.overlay` currently draws a dashed border only when `isCustomizing`. Replace that overlay so the selected sticker reads as selected (solid ring) and unselected editing stickers keep the dashed hint:

```swift
        .overlay {
            if isCustomizing {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        Color.white,
                        style: StrokeStyle(
                            lineWidth: isSelected ? 3 : 2,
                            dash: isSelected ? [] : [6, 4]
                        )
                    )
            }
        }
```

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: build fails in `ProfileStickersLayer.swift` because the new `isSelected` / `onSelect` / `onDelete` arguments are not yet supplied. That is expected and fixed in Task 4. Confirm the error is only the missing-arguments error in `ProfileStickersLayer.swift` (not a syntax error inside `ProfileStickerView.swift`).

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Views/CoupleProfile/ProfileStickerView.swift
git commit -m "feat(garden): sticker selection + trash affordance + browse taps"
```

---

## Task 4: Include avatar/partner in the layer + wire selection/delete

Make `ProfileStickersLayer` draw the user-avatar and partner stickers, enable hit-testing, thread selection + delete + browse-tap callbacks, and add an empty-canvas tap target that deselects in edit mode.

**Files:**
- Modify: `BabyTown/Views/CoupleProfile/ProfileStickersLayer.swift`

- [ ] **Step 1: Replace the layer with selection/delete-aware version**

Replace the entire body of `ProfileStickersLayer.swift` (keep the `import SwiftUI`) with:

```swift
import SwiftUI

/// Cutout stickers over the profile scroll canvas. Draws photo stickers plus the
/// user-avatar and partner-invite stickers; all are draggable/resizable in edit mode.
struct ProfileStickersLayer: View {
    let stickers: [ProfileSticker]
    let images: [UUID: UIImage]
    let userName: String
    let partnerTitle: String
    let isCustomizing: Bool
    let selectedID: UUID?
    let onSelect: (UUID?) -> Void
    let onDelete: (UUID) -> Void
    let onTapUser: () -> Void
    let onTapPartner: () -> Void
    let onPositionChanged: (UUID, NormalizedPoint) -> Void
    let onScaleChanged: (UUID, CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Empty-canvas tap target: deselect when editing.
                if isCustomizing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(nil) }
                }

                ForEach(visibleStickers) { sticker in
                    ProfileStickerView(
                        sticker: sticker,
                        image: images[sticker.id],
                        label: label(for: sticker),
                        canvasSize: geo.size,
                        isCustomizing: isCustomizing,
                        onTap: browseTap(for: sticker),
                        isSelected: selectedID == sticker.id,
                        onSelect: { onSelect(sticker.id) },
                        onDelete: isDeletable(sticker) ? { onDelete(sticker.id) } : nil,
                        onPositionChanged: { onPositionChanged(sticker.id, $0) },
                        onScaleChanged: { onScaleChanged(sticker.id, $0) }
                    )
                }
            }
        }
        .allowsHitTesting(isCustomizing || hasBrowseTaps)
    }

    private var visibleStickers: [ProfileSticker] {
        stickers.filter { sticker in
            switch sticker.kind {
            case .moment, .specialDate, .userAvatar, .partnerInvite:
                return true
            case .pet:
                return false
            }
        }
    }

    /// Photo stickers can be deleted; avatar + partner are persistent (re-synced).
    private func isDeletable(_ sticker: ProfileSticker) -> Bool {
        switch sticker.kind {
        case .moment, .specialDate: return true
        case .userAvatar, .partnerInvite, .pet: return false
        }
    }

    private var hasBrowseTaps: Bool { true }

    private func browseTap(for sticker: ProfileSticker) -> (() -> Void)? {
        switch sticker.kind {
        case .userAvatar: return onTapUser
        case .partnerInvite: return onTapPartner
        case .moment, .specialDate, .pet: return nil
        }
    }

    private func label(for sticker: ProfileSticker) -> String? {
        switch sticker.kind {
        case .userAvatar:
            return userName.isEmpty ? "You" : userName
        case .partnerInvite:
            return partnerTitle
        case .moment, .specialDate, .pet:
            return nil
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: build fails in `CoupleProfileView.swift` at the `ProfileStickersLayer(...)` call site (missing `selectedID` / `onSelect` / `onDelete` / `onTapUser` / `onTapPartner`). Fixed in Task 5. Confirm the only errors are at that call site.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/ProfileStickersLayer.swift
git commit -m "feat(garden): draw avatar + partner stickers, wire selection/delete"
```

---

## Task 5: Reorder layout, anchor scroll, wire delete in `CoupleProfileView`

Put cards above an open canvas, drive the scroll anchor on edit toggle, add selection + delete state, drop the static avatar header section, and update the `ProfileStickersLayer` call site.

**Files:**
- Modify: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`

- [ ] **Step 1: Add selection state and a canvas-anchor id**

After `@State private var isCustomizing = false` (line ~22), add:

```swift
    @State private var selectedStickerID: UUID?
```

Add a private constant for the canvas height near the other private vars (after `private var dpm: DataPersistenceManager { .shared }`, line ~43):

```swift
    /// Open canvas height below the cards where stickers float (also the edit-mode
    /// scroll anchor target). Tall enough to arrange several stickers.
    private let stickerCanvasHeight: CGFloat = 420
```

- [ ] **Step 2: Reorder the scroll content and add the canvas region**

Replace the `ScrollView { ... }` block (lines ~151-173) with a `ScrollViewReader`-wrapped version. Cards come first, then a clear canvas spacer carrying the anchor id; the sticker overlay spans the whole VStack:

```swift
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                profileCardsSection
                                    .id("contentTop")

                                Color.clear
                                    .frame(height: stickerCanvasHeight)
                                    .id("stickerCanvasTop")
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .overlay {
                                GeometryReader { geo in
                                    ProfileStickersLayer(
                                        stickers: profile.stickers,
                                        images: stickerImages,
                                        userName: displayName,
                                        partnerTitle: partnerSlotTitle,
                                        isCustomizing: isCustomizing,
                                        selectedID: selectedStickerID,
                                        onSelect: { selectedStickerID = $0 },
                                        onDelete: deleteSticker,
                                        onTapUser: { showEditProfile = true },
                                        onTapPartner: handlePartnerSlotTap,
                                        onPositionChanged: updateStickerPosition,
                                        onScaleChanged: updateStickerScale
                                    )
                                    .frame(width: geo.size.width, height: geo.size.height)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: isCustomizing) { _, editing in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if editing {
                                    proxy.scrollTo("stickerCanvasTop", anchor: .top)
                                } else {
                                    proxy.scrollTo("contentTop", anchor: .top)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if isCustomizing {
                            EditGardenFooterBar(
                                onAddLoveStory: { showAddLoveStoryComingSoon = true },
                                onCreateStickers: { showStickerPicker = true }
                            )
                        } else {
                            CoupleProfileFooterBar(
                                onVisitPet: { showVisitPet = true },
                                onEditGarden: beginCustomize
                            )
                        }
                    }
```

(Note: the old `avatarHeaderSection` is removed from the scroll content here. The `.safeAreaInset` footer block is unchanged from the original — re-attached to the outer wrapper.)

- [ ] **Step 3: Delete the now-unused `avatarHeaderSection`**

Remove the `avatarHeaderSection` computed property entirely (lines ~352-367). It is no longer referenced. `CoupleProfileAvatarHeader.swift`, `ProfileAvatarSlot.swift` become unused by this view but leave the files in place (no other references to remove in this task; do not delete files).

- [ ] **Step 4: Add the delete handler and deselect-on-mode-change**

Add a `deleteSticker(_:)` method next to `updateStickerScale` (after line ~629):

```swift
    private func deleteSticker(_ id: UUID) {
        guard let idx = profile.stickers.firstIndex(where: { $0.id == id }) else { return }
        let removed = profile.stickers.remove(at: idx)
        dpm.deleteStickerImage(id: removed.id)
        stickerImages[removed.id] = nil
        if selectedStickerID == id { selectedStickerID = nil }
        dpm.saveCoupleProfile(profile)
    }
```

In `cancelCustomize()` and `finishCustomize()` (lines ~587-595), clear the selection. Update both:

```swift
    private func cancelCustomize() {
        isCustomizing = false
        selectedStickerID = nil
        load()
    }

    private func finishCustomize() {
        isCustomizing = false
        selectedStickerID = nil
        dpm.saveCoupleProfile(profile)
    }
```

- [ ] **Step 5: Build**

Run: `xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add BabyTown/Views/CoupleProfile/CoupleProfileView.swift
git commit -m "feat(garden): cards-over-canvas layout, scroll anchor, sticker delete"
```

---

## Task 6: Manual verification in the simulator

No automated UI tests exist; verify behavior by running the app. If `CoupleProfileView` is not directly reachable, temporarily route the app entry to it (see memory: "Verifying UI in the simulator"), then revert.

**Files:**
- (Verification only; possibly a temporary, reverted edit to the app entry route.)

- [ ] **Step 1: Build & run on a booted simulator**

```bash
xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`. Launch via Xcode or the simulator and open the Secret Garden / Couples Profile page.

- [ ] **Step 2: Walk the checklist**

Confirm each:
- Card order top-to-bottom: Our History → Important Dates → Pinned Memories; browse opens scrolled to the top.
- Tapping **Edit Garden** anchors the open canvas to the top of the viewport; scrolling up still reveals the (non-interactive) cards.
- User avatar and partner stickers can be **dragged** and **pinch-resized**; tapping the user sticker in browse opens the profile editor and the partner sticker opens the invite/paywall flow.
- In edit mode, tapping a **photo** sticker shows a **trash** icon above it; tapping the trash removes it. The stray white/black blob stickers can now be removed this way.
- The user-avatar and partner stickers show **no** trash (not deletable).
- Tapping empty canvas in edit mode deselects (trash disappears).
- Sticker positions persist across browse↔edit toggles and an app relaunch with **no drift**.
- **Back/Save** clear the status-bar clock/battery; **Add Love Story / Create Stickers** and **Visit Pet Room / Edit Garden** sit above the home indicator.

- [ ] **Step 3: Revert any temporary entry route**

If the app entry point was temporarily routed to `CoupleProfileView`, revert that change now so `main`/normal navigation is restored. Confirm `git status` shows no stray entry-route edits.

- [ ] **Step 4: Final build**

```bash
xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit (only if a revert or fixup was needed)**

```bash
git add -A
git commit -m "chore(garden): revert temp entry route after verification"
```

---

## Self-review notes

- **Spec coverage:** R1 layout reorder → Task 5; R2 avatars as stickers → Tasks 2/3/4; R3 stable full-canvas coords → Task 5 (cards always present + fixed canvas height); R4 delete affordance → Tasks 3/4/5 (trash hidden for avatar/partner); R5 safe-area chrome → Task 1.
- **Type consistency:** `ProfileStickerView` new params (`isSelected`, `onSelect`, `onDelete`) match the `ProfileStickersLayer` call site, which match `CoupleProfileView`'s `selectedStickerID` / `deleteSticker` / `onSelect: { selectedStickerID = $0 }`. `deleteSticker(_:)` takes a `UUID`, matching `onDelete: (UUID) -> Void`.
- **Build-fails-then-fixed:** Tasks 3 and 4 intentionally leave the build red until their downstream call site is updated; each step states the exact expected error so the executor isn't surprised.
