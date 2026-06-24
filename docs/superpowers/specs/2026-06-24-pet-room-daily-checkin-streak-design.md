# Pet Room Daily Check-in Streak — Design Spec

**Date:** 2026-06-24
**Status:** Approved

---

## Overview

Users earn a coin bonus each day they open the pet room. Visiting 7 days in a row pays out a large bonus on day 7. Each of the first six days awards a smaller fraction of that bonus. Missing a day resets the streak to day 1.

---

## Economy

All constants live in `PetEconomy` alongside existing reward values.

| Constant | Value | Notes |
|---|---|---|
| `checkIn7DayReward` | 100 | Paid out on day 7 |
| `checkInDailyReward` | 14 | ~1/7 of the 7-day reward, paid days 1–6 |

A single helper resolves which reward to use:

```swift
static func checkInReward(forDay day: Int) -> Int {
    day == 7 ? checkIn7DayReward : checkInDailyReward
}
```

---

## Data Model

Two fields added to `PetState`, decoded with `decodeIfPresent` so existing saves remain valid:

| Field | Type | Purpose |
|---|---|---|
| `lastCheckInDate` | `Date?` | Calendar day (Pacific time) of the most recent check-in |
| `checkInStreak` | `Int` | Current consecutive-day count, 0–7 |

Both are encoded in `PetState.encode(to:)` and decoded with fallbacks (nil / 0) in `init(from:)`.

`CodingKeys` gains two new cases: `lastCheckInDate`, `checkInStreak`.

---

## Logic

### `PetViewModel.checkInForPetRoom(now: Date = Date()) -> Int`

Returns coins awarded (0 if already checked in today). Called from `PetRoomView` on appear, alongside the existing `registerPetInteraction()` call.

**Steps:**

1. Resolve `today` using `pacificCalendar.startOfDay(for: now)` (consistent with rest of app).
2. If `lastCheckInDate` is already today → return 0 (idempotent).
3. Check whether `lastCheckInDate` was yesterday:
   - Yes → `checkInStreak = min(checkInStreak + 1, 7)`
   - No (missed day or first ever) → `checkInStreak = 1`
4. Set `lastCheckInDate = today`.
5. Resolve coins: `PetEconomy.checkInReward(forDay: checkInStreak)`.
6. `state.coins += coins`; set `lastAward = (coins, UUID())` for coin-burst feedback.
7. If `checkInStreak == 7` → reset `checkInStreak = 0` (streak complete; tomorrow begins a new run at day 1).
8. Return coins awarded.

All mutations go through `state` (persisted via `didSet → DataPersistenceManager`). No separate persistence call needed.

---

## UI

### `DailyCheckInStreakView`

A new SwiftUI component. Placed just below the coin pill in the pet room HUD. Only rendered when the user has an adopted pet.

**Layout:** Horizontal row of 7 small circles (~14pt diameter), evenly spaced, total height ~20pt.

**Circle states:**

| State | Visual |
|---|---|
| Completed day | Filled, `BabyTownTheme.accent` |
| Today — just checked in | Filled accent + subtle scale pulse (one-shot on appear) |
| Today — not yet checked in | Outlined dim, small coin SF Symbol inside |
| Future day | Empty circle, muted opacity |

"Today" is determined by comparing `checkInStreak` to the strip index and whether `lastCheckInDate` is today.

### Coin burst on check-in

`PetRoomView.onAppear` calls `checkInForPetRoom()`. If the returned value > 0, it assigns `coinBurst = (amount: coins, id: UUID())` — the same mechanism all other coin awards use. No new animation code needed.

---

## Scope

- No network calls — streak is local/per-device, consistent with the rest of `PetState`.
- No push notification changes — daily check-in motivation is handled visually by the streak strip.
- No per-pet tracking — one streak shared across all of the user's pets (opening any pet's room counts).

---

## Files Touched

| File | Change |
|---|---|
| `BabyTown/Models/PetEconomy.swift` | Add constants + `checkInReward(forDay:)` |
| `BabyTown/Models/Pet.swift` | Add `lastCheckInDate`, `checkInStreak` to `PetState` |
| `BabyTown/ViewModels/PetViewModel.swift` | Add `checkInForPetRoom(now:)` |
| `BabyTown/Views/PetRoomView.swift` | Call check-in on appear, feed result to `coinBurst` |
| `BabyTown/Components/DailyCheckInStreakView.swift` | New component (7-dot strip) |
