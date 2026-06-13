# Partner Onboarding Flow — Design Spec

**Date:** 2026-06-12
**Status:** Approved

## Overview

When a Prelude user sends an invite, their partner receives a deep link. Tapping it opens the app into a dedicated partner onboarding flow that collects the partner's identity, then reveals the inviter's Prelude gift, and finally transitions both users into Official mode.

There is no backend yet. All data is stored locally. The email collected during onboarding is persisted for future account use when a backend lands.

---

## Screen Flow

```
deep link (babytown://invite/CODE?from=NAME)
    ↓
welcome(inviterName)
    ↓ "Open it" tapped
username
    ↓ Continue
email
    ↓ Continue
profilePhoto
    ↓ Continue (or Skip)
colorTheme
    ↓ Continue
giftReveal
    ↓ "Open our space" tapped
→ Official home
```

No back navigation after welcome — this is a one-way acceptance flow. All transitions use `.transition(.opacity)` crossfade to match the existing onboarding style.

---

## Screens

### Welcome
- Full bleed, centered layout
- `BookFlipView` animating at top (size 160pt, `frameInterval: 0.18`)
- Headline: `"[InviterName] wants to share something with you"` — serif, large
- Subtext: `"A private Prelude, just for you"`
- Primary CTA: `"Open it"`

### Username
- Reuses `NicknameView` visual style exactly (gradient bg, centered field, Continue button)
- Label: `"What should we call you?"`
- Saves via `DataPersistenceManager.shared.saveUserNickname(_:)`

### Email
- Same visual style as username screen
- Label: `"Where can we reach you?"`
- Subtext: `"For account recovery when we launch"`
- Keyboard type: `.emailAddress`, autocorrect off
- Saves via `DataPersistenceManager.shared.savePartnerEmail(_:)` (new)

### Profile Photo
- Centered avatar circle, 120pt, with `+` tap target opening `PhotosPicker`
- Label: `"Add a photo of yourself"`
- Subtext: `"Your partner will see this"`
- Skip link below Continue button — photo is optional
- Saves via `DataPersistenceManager.shared.savePartnerProfilePhoto(_:)` (new)

### Color Theme
- Drops in existing `ColorThemeView` unchanged
- Calls `ThemeManager.shared.setTheme(_:)` on continue

### Gift Reveal
- Warm/dark background
- `BookFlipView` animates for ~1.5s then settles on frame 1 (fully open)
- Headline: `"[InviterName] made this for you"` — serif
- Scrollable list of mock capture cards (1 note, 1 voice memo, 1 first) using `GiftCaptureRow` style
- Primary button: `"Open our space"` → calls `onComplete()`
- Mock data is hardcoded for now; wired to real backend captures when sync lands

---

## Architecture

### `PartnerOnboardingFlow`
New self-contained SwiftUI view at `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift`.

```swift
struct PartnerOnboardingFlow: View {
    let inviterName: String   // from deep link param, fallback "your partner"
    var onComplete: () -> Void
    // owns internal Step enum, advances linearly
}
```

Internal `Step` enum:
```swift
enum Step {
    case welcome, username, email, profilePhoto, colorTheme, giftReveal
}
```

### `ContentView` changes
- New case: `case partnerOnboarding(inviterName: String)`
- `.onOpenURL` parses `babytown://invite/CODE?from=NAME`
- `PartnerOnboardingFlow.onComplete`: sets `relationshipStage = .official`, `hasCompletedOnboarding = true`, transitions to `.home`
- URL scheme `babytown` added to `Info.plist`

### `PreludeSettingsSheet` changes
- New closure param: `onSimulatePartnerInvite: () -> Void`
- New row in existing "Testing" section: `"Preview Partner Onboarding"` (`person.crop.circle` icon)
- Footer: `"Launches the partner invite flow with a mock inviter name."`
- Dismiss + 0.35s delay before firing closure (matches existing button pattern)
- `ContentView` passes `{ screen = .partnerOnboarding(inviterName: "Justin") }` as the mock closure

### `DataPersistenceManager` additions
- `savePartnerEmail(_ email: String)` — UserDefaults key `"partnerEmail"`
- `savePartnerProfilePhoto(_ image: UIImage)` — JPEG in documents dir, same pattern as existing photo storage

---

## Assets

- `BookFlip1` – `BookFlip4` added to `Assets.xcassets` (450×348pt each, cropped from sprite sheet)
- `BookFlipView` component at `BabyTown/Components/BookFlipView.swift`

---

## Testing

`PreludeSettingsSheet` "Preview Partner Onboarding" button launches `PartnerOnboardingFlow` with `inviterName: "Justin"` (mock). No deep link required to test.

---

## Out of scope

- Actual invite code validation (no backend)
- Real gift data transfer between devices (no backend)
- Push notifications on invite acceptance
- Partner-side Prelude capture mode (partner goes directly to Official)
