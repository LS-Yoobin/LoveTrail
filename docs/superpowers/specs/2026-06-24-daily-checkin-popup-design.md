# Daily Check-in Popup — Design Spec

**Date:** 2026-06-24
**Status:** Approved

---

## Overview

Replace the ephemeral coin-burst text that fires when the user opens the pet room with a dedicated interactive popup. The popup shows 7 stars representing the weekly streak, lets the user tap the shining star for today to reveal their coin reward, and dismisses via a "Collect" button. The popup is also accessible by tapping the existing 7-dot HUD strip on subsequent visits (review mode, no claim interaction).

---

## Mode Enum

```swift
enum CheckInPopupMode {
    case claiming(coins: Int)  // auto-shown on first open of the day
    case reviewing             // opened by tapping the streak strip
}
```

---

## Component: `DailyCheckInPopupView`

### Props

| Prop | Type | Purpose |
|---|---|---|
| `mode` | `CheckInPopupMode` | Drives claiming vs reviewing state |
| `streak` | `Int` | Current streak count (0–7) from `PetViewModel` |
| `checkedInToday` | `Bool` | Whether today's check-in has already been recorded |
| `onDismiss` | `() -> Void` | Called when the user taps Collect or Close |

### Internal State

| State | Type | Purpose |
|---|---|---|
| `revealed` | `Bool` | False until user taps the shining star; only active in `.claiming` mode |
| `cardScale` | `CGFloat` | Spring entrance animation (0.92 → 1.0) |
| `cardOpacity` | `Double` | Fade-in on appear (0 → 1) |

### Layout (top to bottom)

1. **Header**
   - Title: "Daily Check-in" — `.system(size: 22, weight: .bold, design: .rounded)`, `BabyTownTheme.textPrimary`
   - Subtitle: "Come back each day to keep your streak" — `.system(size: 14, weight: .medium)`, secondary color

2. **Star row**
   - 7 stars, `HStack(spacing: 10)`, centered
   - Default star size: 28pt; day 7 star: 34pt (signals the bigger reward)
   - SF Symbol base: `star.fill` (filled) / `star` (outlined future)

3. **Star states**

   | State | Visual |
   |---|---|
   | Past day (completed) | `star.fill`, `BabyTownTheme.accent`, full opacity |
   | Today — claiming, not yet tapped | `star.fill`, `BabyTownTheme.accentDeep`, repeating shimmer pulse animation, tappable |
   | Today — claiming, already tapped (revealed) | `star.fill`, `BabyTownTheme.accentDeep`, static (pulse stops) |
   | Today — reviewing (already claimed) | `star.fill`, `BabyTownTheme.accent`, static, no interaction |
   | Future day | `star`, `Color.secondary.opacity(0.3)`, outlined |

4. **Reward area** (only in `.claiming` mode, animates in after star tap)
   - Coin icon (`PetCoinIcon`) + coin amount label: `"+\(coins)"` — `.system(size: 28, weight: .bold, design: .rounded)`, `BabyTownTheme.accentDeep`
   - Appears with `.opacity` + `.scale(scale: 0.8)` transition, spring animation

5. **Button**
   - `.claiming` before tap: no button visible (star tap is the CTA)
   - `.claiming` after tap (revealed): "Collect" button — full-width, `BabyTownTheme.buttonGradient`, calls `onDismiss`
   - `.reviewing`: "Close" button — same style, calls `onDismiss`

### Card Shell

Matches `PetRoomWelcomeTutorialView`:
- Background: `LinearGradient(BabyTownTheme.cardTintLight → BabyTownTheme.cardTintDeep)`
- Corner radius: 28, `.continuous`
- Stroke border: white 0.85 → accent 0.28 gradient, 1.2pt
- Shadow: accent 0.18 at 28 radius + black 0.14 at 18 radius
- Horizontal padding: 24pt from screen edges
- Spring entrance: `response: 0.52, dampingFraction: 0.82`
- Dark scrim behind: `Color.black.opacity(0.52)`, `.ignoresSafeArea()`

---

## Wiring in `PetRoomView`

### New state variable

```swift
@State private var checkInPopup: CheckInPopupMode?
```

### On appear (replace check-in coinBurst)

```swift
let awarded = viewModel.checkInForPetRoom()
if awarded > 0 {
    checkInPopup = .claiming(coins: awarded)
}
// coinBurst removed for check-in; coinBurst stays for all other awards (care tasks etc.)
```

### Overlay

```swift
.overlay {
    if let mode = checkInPopup {
        DailyCheckInPopupView(
            mode: mode,
            streak: viewModel.petState.checkInStreak,
            checkedInToday: viewModel.checkedInToday,
            onDismiss: { withAnimation { checkInPopup = nil } }
        )
    }
}
```

### `DailyCheckInStreakView` — add tap callback

```swift
// existing call site in PetRoomView HUD
DailyCheckInStreakView(
    streak: viewModel.petState.checkInStreak,
    checkedInToday: viewModel.checkedInToday,
    onTap: { checkInPopup = .reviewing }
)
```

`DailyCheckInStreakView` gains an `onTap: () -> Void` prop and wraps its `HStack` in a `Button`.

---

## `PetViewModel` helper

`checkedInToday: Bool` — computed property returning `true` if `state.lastCheckInDate` is the same calendar day as today. Used by both `DailyCheckInStreakView` and `DailyCheckInPopupView`.

If this property already exists or can be derived inline, no new code needed. Otherwise add it to `PetViewModel`.

---

## Files Touched

| File | Change |
|---|---|
| `BabyTown/Components/DailyCheckInPopupView.swift` | New component |
| `BabyTown/Components/DailyCheckInStreakView.swift` | Add `onTap: () -> Void` prop |
| `BabyTown/Views/PetRoomView.swift` | Add `checkInPopup` state, swap check-in coinBurst for popup, wire strip tap |
| `BabyTown/ViewModels/PetViewModel.swift` | Add `checkedInToday` computed property if not already present |

---

## Scope

- No changes to economy constants or streak logic — those are already implemented.
- `coinBurst` is preserved for all non-check-in coin awards.
- No network calls; all state is local.
