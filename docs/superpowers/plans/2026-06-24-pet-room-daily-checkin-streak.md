# Pet Room Daily Check-in Streak — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Award coins each day the user opens the pet room, with a 100-coin bonus after 7 consecutive days, shown as a 7-dot strip below the coin pill in the HUD.

**Architecture:** Streak state (`lastCheckInDate`, `checkInStreak`) lives in `PetState` and is persisted via the existing `didSet → DataPersistenceManager` path. `PetViewModel.checkInForPetRoom()` handles idempotency (no-op if already checked in today), streak increment/reset, and coin award. `DailyCheckInStreakView` renders the 7-dot strip; it is embedded in `PetHUDView` and receives only pre-computed values (`streak`, `checkedInToday`) so it holds no business logic.

**Tech Stack:** SwiftUI, existing `BabyTownTheme` tokens, `DataPersistenceManager` (UserDefaults via `Codable`), Pacific-time `Calendar`.

## Global Constraints

- Never use ` - ` (space dash space) in any user-facing string
- Always use `BabyTownTheme.*` tokens — no hardcoded hex or RGB values
- Both Pink and Blue themes must be supported
- Streak is local/per-device — no network calls
- `decodeIfPresent` with fallbacks on all new `PetState` fields (backward-compatible saves)
- "Today" is always resolved with `pacificCalendar` (Pacific time), consistent with rest of app

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `BabyTown/Models/PetEconomy.swift` | Modify | Add two constants + `checkInReward(forDay:)` helper |
| `BabyTown/Models/Pet.swift` | Modify | Add `lastCheckInDate` and `checkInStreak` to `PetState` (CodingKeys, init, encode, decode) |
| `BabyTown/ViewModels/PetViewModel.swift` | Modify | Add `checkInForPetRoom()`, `checkInStreak`, `checkedInToday` |
| `BabyTown/Components/DailyCheckInStreakView.swift` | Create | 7-dot streak strip component |
| `BabyTown/Components/PetHUDView.swift` | Modify | Accept streak params; embed `DailyCheckInStreakView` below coin pill |
| `BabyTown/Views/PetRoomView.swift` | Modify | Call check-in on appear; pass streak data to `PetHUDView` |

---

## Task 1: Economy constants

**Files:**
- Modify: `BabyTown/Models/PetEconomy.swift`

**Interfaces:**
- Produces: `PetEconomy.checkIn7DayReward: Int`, `PetEconomy.checkInDailyReward: Int`, `PetEconomy.checkInReward(forDay: Int) -> Int`

- [ ] **Step 1: Add the MARK section and constants after `happinessFromWater`**

In `PetEconomy.swift`, after the line `static let happinessFromWater: Double = 10`, add:

```swift
    // MARK: Daily check-in streak

    static let checkIn7DayReward = 100
    static let checkInDailyReward = 14

    static func checkInReward(forDay day: Int) -> Int {
        day == 7 ? checkIn7DayReward : checkInDailyReward
    }
```

- [ ] **Step 2: Build to verify no errors**

In Xcode press ⌘B. Expected: build succeeds with no errors or warnings from `PetEconomy.swift`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/PetEconomy.swift
git commit -m "feat: add daily check-in economy constants"
```

---

## Task 2: Add streak fields to PetState

**Files:**
- Modify: `BabyTown/Models/Pet.swift`

**Interfaces:**
- Consumes: nothing new
- Produces: `PetState.lastCheckInDate: Date?`, `PetState.checkInStreak: Int`

- [ ] **Step 1: Add two cases to `CodingKeys`**

In `Pet.swift`, find the `CodingKeys` enum inside `PetState`. It currently ends with `hasSeenPetRoomTutorial`. Add after it:

```swift
        case lastCheckInDate, checkInStreak
```

Full enum after change:
```swift
    private enum CodingKeys: String, CodingKey {
        case adoptedSkin, adoptedDate, coins, foodServings
        case ownedSkins
        case hunger, thirst, litter, happiness
        case lastPetAt, lastPlayAt, lastPlantWaterAt, customPetNames, lastPetInteractionAt
        case roomLayout
        case roomLayoutsByPet
        case toiletPaperMessByPet
        case trickTrainingByPet
        case trickTraining
        case hasSeenPetRoomTutorial
        case lastCheckInDate, checkInStreak
    }
```

- [ ] **Step 2: Add stored properties**

After `var hasSeenPetRoomTutorial: Bool`, add:

```swift
    var lastCheckInDate: Date?
    var checkInStreak: Int
```

- [ ] **Step 3: Initialize in memberwise `init`**

In `init(adoptedSkin:adoptedDate:)`, after `self.hasSeenPetRoomTutorial = false`, add:

```swift
        self.lastCheckInDate = nil
        self.checkInStreak = 0
```

- [ ] **Step 4: Encode the new fields**

In `encode(to:)`, after `try c.encode(hasSeenPetRoomTutorial, forKey: .hasSeenPetRoomTutorial)`, add:

```swift
        try c.encodeIfPresent(lastCheckInDate, forKey: .lastCheckInDate)
        try c.encode(checkInStreak, forKey: .checkInStreak)
```

- [ ] **Step 5: Decode with fallbacks**

In `init(from:)`, after the `hasSeenPetRoomTutorial` decode block, add:

```swift
        lastCheckInDate = try c.decodeIfPresent(Date.self, forKey: .lastCheckInDate)
        checkInStreak = try c.decodeIfPresent(Int.self, forKey: .checkInStreak) ?? 0
```

- [ ] **Step 6: Build to verify no errors**

Press ⌘B. Expected: succeeds. Confirm `PetState` compiles and the new fields appear in autocomplete.

- [ ] **Step 7: Commit**

```bash
git add BabyTown/Models/Pet.swift
git commit -m "feat: add lastCheckInDate and checkInStreak to PetState"
```

---

## Task 3: Check-in logic in PetViewModel

**Files:**
- Modify: `BabyTown/ViewModels/PetViewModel.swift`

**Interfaces:**
- Consumes: `PetState.lastCheckInDate`, `PetState.checkInStreak`, `PetEconomy.checkInReward(forDay:)`
- Produces:
  - `PetViewModel.checkInForPetRoom(now: Date = Date()) -> Int`
  - `PetViewModel.checkInStreak: Int`
  - `PetViewModel.checkedInToday: Bool`

- [ ] **Step 1: Add `checkInStreak` and `checkedInToday` computed properties**

In `PetViewModel.swift`, find the `// MARK: Adoption` section and add the two helpers just below `var coins: Int { state.coins }` (inside `// MARK: Live need values`):

```swift
    var checkInStreak: Int { state.checkInStreak }

    var checkedInToday: Bool {
        guard let last = state.lastCheckInDate else { return false }
        return pacificCalendar.isDate(last, inSameDayAs: Date())
    }
```

- [ ] **Step 2: Add `checkInForPetRoom(now:)`**

Add the following method in `PetViewModel.swift`, inside the `// MARK: Care actions` section, after `func registerPetInteraction()`:

```swift
    /// Awards coins for opening the pet room today. Idempotent — returns 0 if
    /// already checked in today (Pacific time). Resets streak to 0 after day 7.
    @discardableResult
    func checkInForPetRoom(now: Date = Date()) -> Int {
        let today = pacificCalendar.startOfDay(for: now)

        if let last = state.lastCheckInDate,
           pacificCalendar.startOfDay(for: last) == today {
            return 0
        }

        if let last = state.lastCheckInDate,
           let yesterday = pacificCalendar.date(byAdding: .day, value: -1, to: today),
           pacificCalendar.startOfDay(for: last) == yesterday {
            state.checkInStreak = min(state.checkInStreak + 1, 7)
        } else {
            state.checkInStreak = 1
        }

        state.lastCheckInDate = today
        let coins = PetEconomy.checkInReward(forDay: state.checkInStreak)
        state.coins += coins
        lastAward = (coins, UUID())

        if state.checkInStreak == 7 {
            state.checkInStreak = 0
        }

        return coins
    }
```

- [ ] **Step 3: Build to verify no errors**

Press ⌘B. Expected: succeeds.

- [ ] **Step 4: Manual logic smoke-test via Xcode console**

Add a temporary `print` in `checkInForPetRoom` after `let coins = ...`:
```swift
print("[checkIn] streak=\(state.checkInStreak) coins=\(coins)")
```
Run the app on simulator, open the pet room, confirm the log line appears once with `streak=1 coins=14`. Background and foreground the app; confirm it prints 0 the second time (idempotent). Remove the `print` line before committing.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/ViewModels/PetViewModel.swift
git commit -m "feat: add checkInForPetRoom logic to PetViewModel"
```

---

## Task 4: DailyCheckInStreakView component

**Files:**
- Create: `BabyTown/Components/DailyCheckInStreakView.swift`

**Interfaces:**
- Consumes: `BabyTownTheme.accent`, `PetCoinIcon` (already in `PetHUDView.swift`, same module)
- Produces: `struct DailyCheckInStreakView: View` with init `(streak: Int, checkedInToday: Bool)`

**Dot states:**

| State | When | Visual |
|---|---|---|
| `.completed` | `index < todayIndex` | Filled `BabyTownTheme.accent` |
| `.todayDone` | `index == todayIndex && checkedInToday` | Filled accent + one-shot spring pulse (scale 1.3 → 1.0 on appear) |
| `.todayPending` | `index == todayIndex && !checkedInToday` | Outlined dim accent (`opacity(0.4)`, `lineWidth: 1.5`) + `PetCoinIcon(size: 6)` centered at `opacity(0.5)` |
| `.future` | `index > todayIndex` | Outlined `Color.secondary.opacity(0.25)`, `lineWidth: 1` |

**`todayIndex` computation:**
- `checkedInToday && streak == 0` → 7 (just finished a full cycle; day 7 gets the pulse)
- `checkedInToday` → `streak` (streak was incremented, then possibly reset; before reset it was the day just visited)
- not checked in today → `streak + 1` (next un-checked day; capped at 7 via `min`)

- [ ] **Step 1: Create the file**

Create `BabyTown/Components/DailyCheckInStreakView.swift` with:

```swift
import SwiftUI

struct DailyCheckInStreakView: View {
    let streak: Int
    let checkedInToday: Bool

    @State private var pulsed = false

    private var todayIndex: Int {
        if checkedInToday && streak == 0 { return 7 }
        if checkedInToday { return streak }
        return min(streak + 1, 7)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { index in
                dot(for: index)
            }
        }
        .frame(height: 20)
    }

    @ViewBuilder
    private func dot(for index: Int) -> some View {
        switch dotState(for: index) {
        case .completed:
            Circle()
                .fill(BabyTownTheme.accent)
                .frame(width: 14, height: 14)
        case .todayDone:
            Circle()
                .fill(BabyTownTheme.accent)
                .frame(width: 14, height: 14)
                .scaleEffect(pulsed ? 1.0 : 1.3)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                        pulsed = true
                    }
                }
        case .todayPending:
            ZStack {
                Circle()
                    .stroke(BabyTownTheme.accent.opacity(0.4), lineWidth: 1.5)
                PetCoinIcon(size: 6)
                    .opacity(0.5)
            }
            .frame(width: 14, height: 14)
        case .future:
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                .frame(width: 14, height: 14)
        }
    }

    private enum DotState { case completed, todayDone, todayPending, future }

    private func dotState(for index: Int) -> DotState {
        if index < todayIndex { return .completed }
        if index == todayIndex { return checkedInToday ? .todayDone : .todayPending }
        return .future
    }
}

#Preview("Day 3, not yet checked in") {
    DailyCheckInStreakView(streak: 2, checkedInToday: false)
        .padding()
        .background(Color.black)
}

#Preview("Day 3, just checked in") {
    DailyCheckInStreakView(streak: 3, checkedInToday: true)
        .padding()
        .background(Color.black)
}

#Preview("Day 7 complete (streak reset)") {
    DailyCheckInStreakView(streak: 0, checkedInToday: true)
        .padding()
        .background(Color.black)
}

#Preview("No streak yet") {
    DailyCheckInStreakView(streak: 0, checkedInToday: false)
        .padding()
        .background(Color.black)
}
```

- [ ] **Step 2: Verify previews in Xcode Canvas**

Open the file in Xcode and switch to Canvas (⌘⌥↩). Check all four previews:
- "No streak yet": 7 dots — dot 1 outlined with coin, dots 2–7 empty/muted
- "Day 3, not yet checked in": dots 1–2 filled accent, dot 3 outlined with coin, dots 4–7 muted
- "Day 3, just checked in": dots 1–2 filled accent, dot 3 filled accent (with pulse animation), dots 4–7 muted
- "Day 7 complete": all 7 dots filled accent, dot 7 pulses

- [ ] **Step 3: Verify both themes**

In the Canvas, wrap the `#Preview` body in `ThemeManager.shared.theme = .blue` or toggle via settings. Confirm accent color switches between blue and pink correctly.

- [ ] **Step 4: Build to verify no errors**

Press ⌘B.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Components/DailyCheckInStreakView.swift
git commit -m "feat: add DailyCheckInStreakView 7-dot streak strip"
```

---

## Task 5: Wire HUD and room on-appear

**Files:**
- Modify: `BabyTown/Components/PetHUDView.swift`
- Modify: `BabyTown/Views/PetRoomView.swift`

**Interfaces:**
- Consumes: `DailyCheckInStreakView(streak:checkedInToday:)`, `PetViewModel.checkInForPetRoom()`, `PetViewModel.checkInStreak`, `PetViewModel.checkedInToday`

- [ ] **Step 1: Add streak params to `PetHUDView`**

In `PetHUDView.swift`, find the `PetHUDView` struct properties (after `var onAdoptMore`). Add two optional parameters with defaults so all existing call sites remain valid:

```swift
    var checkInStreak: Int = 0
    var checkedInToday: Bool = false
```

- [ ] **Step 2: Embed `DailyCheckInStreakView` in the left VStack**

In `PetHUDView.body`, find the `VStack(alignment: .leading, spacing: 16)` block. After the closing `}` of the coin pill `Button`, and before the `if showsPetSwitcher` block, insert:

```swift
                if currentSkin != nil {
                    DailyCheckInStreakView(
                        streak: checkInStreak,
                        checkedInToday: checkedInToday
                    )
                }
```

The left VStack after the change:
```swift
            VStack(alignment: .leading, spacing: 16) {
                Button(action: onInventoryTap) {
                    HStack(spacing: 6) {
                        PetCoinIcon(size: 22)
                        Text("\(coins)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("My items")
                .accessibilityValue("\(coins) coins")
                .accessibilityHint("Opens décor you own for this room")

                if currentSkin != nil {
                    DailyCheckInStreakView(
                        streak: checkInStreak,
                        checkedInToday: checkedInToday
                    )
                }

                if showsPetSwitcher,
                   let currentSkin,
                   let onSelectPet,
                   let onAdoptMore {
                    PetRoomPetSwitcher(
                        currentSkin: currentSkin,
                        ownedSkins: ownedSkins,
                        onSelectPet: onSelectPet,
                        onAdoptMore: onAdoptMore
                    )
                }
            }
```

- [ ] **Step 3: Call `checkInForPetRoom()` in `PetRoomView.onAppear`**

In `PetRoomView.swift`, find the `.onAppear` block on the SpriteView group (contains `viewModel.registerPetInteraction()` and `presentWelcomeTutorialIfNeeded()`). Add the check-in call immediately after `registerPetInteraction()`:

```swift
        .onAppear {
            viewModel.registerPetInteraction()
            let awarded = viewModel.checkInForPetRoom()
            if awarded > 0 {
                coinBurst = (amount: awarded, id: UUID())
            }
            if scene == nil {
                installScene(
                    makeConfiguredScene(skin: activeSkin, size: geo.size),
                    for: activeSkin,
                    geo: geo
                )
            }
            presentWelcomeTutorialIfNeeded()
        }
```

- [ ] **Step 4: Pass streak data to `PetHUDView` in `PetRoomView`**

Find the `PetHUDView(...)` call inside the `TimelineView` block (within the `} else if !isInspectingPictureFrame && !isRefillingFood {` branch). Add two parameters:

```swift
                    PetHUDView(
                        coins: viewModel.coins,
                        hunger: viewModel.hunger,
                        thirst: viewModel.thirst,
                        litter: viewModel.litter,
                        happiness: viewModel.happiness,
                        checkInStreak: viewModel.checkInStreak,
                        checkedInToday: viewModel.checkedInToday,
                        currentSkin: activeSkin,
                        ownedSkins: viewModel.ownedSkins,
                        onInventoryTap: { openOwnedItems() },
                        onStatsTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showStatsDetail = true
                            }
                        },
                        onSelectPet: { newSkin in
                            guard newSkin != viewModel.adoptedSkin else { return }
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.visit(newSkin)
                            }
                        },
                        onAdoptMore: onChangePet
                    )
```

- [ ] **Step 5: Build to verify no errors**

Press ⌘B. Expected: succeeds with zero errors.

- [ ] **Step 6: Manual end-to-end verification on simulator**

1. Run the app on a simulator. Open the pet room (requires an adopted pet).
2. **First open:** Confirm the 7-dot strip appears below the coin pill. Dot 1 should be accent-filled with a pulse animation. Dots 2–7 should be muted/empty. A coin burst (`+14`) should appear.
3. **Second open (same day):** Background and foreground the app. Re-enter the pet room. No coin burst. Dot 1 remains filled. No double-award.
4. **Visual check both themes:** In simulator Settings → app theme (or long-press if there's an in-app toggle), confirm the filled dots switch between pink and blue with the theme.
5. **Day 7 preview:** Use the `DailyCheckInStreakView` Xcode Preview for `"Day 7 complete"` to verify all 7 dots show filled with the pulse on dot 7, since simulating 7 real days on device is impractical.

- [ ] **Step 7: Commit**

```bash
git add BabyTown/Components/PetHUDView.swift BabyTown/Views/PetRoomView.swift
git commit -m "feat: wire daily check-in streak into pet room HUD"
```
