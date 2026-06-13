# Gift Reveal Animation — Design Spec

**Date:** 2026-06-13
**Feature:** Animated gift reveal on partner onboarding welcome screen

---

## Overview

When the partner taps "Open it" on the welcome screen, the flipping book animation stops on the open-blank-pages frame (BookFlip4), then zooms and pans so its right page fills the entire screen. The right page becomes a warm parchment surface on which the inviter's captures appear one at a time, oldest to newest. The partner pages through them with Prev Page / Next Page buttons and exits via "Open our space" on the last capture, continuing into the standard onboarding steps (username, email, photo, color theme).

---

## Flow Change

**Before:** `.welcome` → `.username`

**After:** `.welcome` → `.giftReveal` → `.username`

The `Step` enum in `PartnerOnboardingFlow` gains a `.giftReveal` case between `.welcome` and `.username`. The `advance()` function is updated accordingly.

---

## Animation Sequence

1. **Welcome step** — `BookFlipView(animating: true, size: 160)` cycles frames as before. "Open it" calls `advance()`, crossfading to `.giftReveal`.

2. **GiftRevealStep appears** — `BookFlipView(animating: false, size: 160)` is shown, stopped at `frameIndex = 3` (BookFlip4 — open book, blank pages). This is achieved by using `Image("BookFlip4")` directly (not `BookFlipView`) so the frame is guaranteed.

3. **Zoom animation** — on `.onAppear`, after a 0.05s delay, a single `.easeInOut(duration: 0.85)` animation drives:
   - `scaleEffect`: 1.0 → 5.0
   - `offset.x`: 0 → `-(screenWidth * 0.255)` (shifts book left so its right page centers)
   - `offset.y`: 0 (no vertical shift)

   The scale and offset values are derived from screen geometry via `GeometryReader`. The right page of the book image occupies the right half, so at 5× scale it fills the full screen width. The horizontal offset centers the right page.

4. **Parchment content fades in** — once the zoom animation completes (via `withAnimation` completion on iOS 17+), `capturesVisible` is set to `true`. The parchment page content fades in with `.easeIn(duration: 0.4)`.

---

## GiftRevealStep Layout (parchment page)

**Background:** `LinearGradient(colors: [Color(hex: "#fdf6ec"), Color(hex: "#f8e8d0"), Color(hex: "#f3dfc0")], startPoint: .top, endPoint: .bottomTrailing)` fills the full screen (behind and on top of the zoomed book image via a ZStack).

**Decorative ruled lines:** Horizontal lines spanning the page, opacity 0.06, spaced ~28pt apart, warm brown. Pure decoration — evoke notebook paper.

**Page counter:** Top center, `"Page X of Y"`, `.system(size: 10, design: .serif)`, warm brown at 40% opacity, letter-spaced, uppercased.

**Capture content (centered, vertically):**
- Icon: `Image(systemName: capture.typeIcon)`, 36pt, `BabyTownTheme.accent`
- Type label: `capture.typeLabel` uppercased, 9pt semibold, `#c2642a`, 2pt letter spacing
- Title/text: `capture.displayTitle`, 17pt serif, `Color(hex: "#3d1800")`, line height 1.6
- Date: `capture.createdAt` formatted as date, 11pt serif, `#a07050`

No card background. Content sits directly on the parchment.

**Navigation row (bottom, above safe area):**
- Left: "← Prev Page" — pill button, `rgba(100,60,20,0.10)` fill, warm brown text, 12pt serif. Hidden (`opacity(0)`) when `currentIndex == 0`.
- Right: "Next Page →" — pill button, `#c2642a` fill, white text, 12pt semibold. On last capture, replaced by "Open our space" with `BabyTownTheme.accentGradient` fill → calls `onComplete()`.

---

## Capture Data

Loaded inside `GiftRevealStep.onAppear` from:

```swift
DataPersistenceManager.shared.loadPreludeCaptures()
    .filter { $0.isIncludedInGift && !$0.isPartnerRetroactive }
    .sorted { $0.createdAt < $1.createdAt }
```

If no captures are available (empty gift), the step shows a single parchment page with placeholder text: "Nothing here yet — check back soon." with only an "Open our space" button.

---

## Files Changed

| Action | File | Change |
|--------|------|--------|
| Modify | `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift` | Add `.giftReveal` to `Step` enum; update `advance()`; add `GiftRevealStep` struct |

No other files need changes. `DataPersistenceManager.loadPreludeCaptures()` already exists. `BookFlip4` asset already exists.

---

## Edge Cases

- **Empty gift:** Single page with placeholder, only "Open our space" button shown (no Prev/Next).
- **Single capture:** Page counter hidden. No Prev Page. "Open our space" instead of Next Page.
- **Voice memo captures:** Display same as other types (icon + label + title + date). No audio playback in the reveal — this is a visual gift unwrapping moment.
- **Long capture text:** `.lineLimit(4)` with `.minimumScaleFactor(0.8)` to prevent overflow on the page.
