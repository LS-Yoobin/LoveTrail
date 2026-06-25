# Daily Check-in Popup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ephemeral coin-burst text on pet room entry with a dedicated `DailyCheckInPopupView` card that lets the user tap a shining star to reveal their daily coin reward, and adds a tap-to-review path via the streak strip in the HUD.

**Architecture:** Three sequential changes — (1) create the new `DailyCheckInPopupView` component with its `CheckInPopupMode` enum, (2) add an `onTap` callback to `DailyCheckInStreakView` and thread it through `PetHUDView`, (3) wire the popup and strip-tap into `PetRoomView`, suppressing the legacy `coinBurst` for check-in awards.

**Tech Stack:** SwiftUI, existing `BabyTownTheme` tokens, `PetViewModel.checkedInToday` (already exists), `PetEconomy.checkInReward(forDay:)` (already exists).

## Global Constraints

- Never use ` - ` (space dash space) in any user-facing string.
- All colors via `BabyTownTheme.*` tokens — no hardcoded hex.
- Both Pink and Blue themes must work — no single-theme assumptions.
- Card shell must match `PetRoomWelcomeTutorialView` exactly (radius 28, gradient background, stroke border, dual shadow).
- No changes to economy constants, streak logic, or persistence — those are complete.
- `coinBurst` is preserved for all non-check-in coin awards; only the check-in burst is replaced.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `BabyTown/Components/DailyCheckInPopupView.swift` | **Create** | `CheckInPopupMode` enum + full popup component |
| `BabyTown/Components/DailyCheckInStreakView.swift` | **Modify** | Add optional `onTap: (() -> Void)?` prop; wrap strip in `Button` when set |
| `BabyTown/Components/PetHUDView.swift` | **Modify** | Add `onStreakTap: (() -> Void)?` prop; pass to `DailyCheckInStreakView` |
| `BabyTown/Views/PetRoomView.swift` | **Modify** | Add `checkInPopup` state; replace burst with popup; wire strip tap; update `syncSceneSheetPause` |

---

## Task 1: Create `DailyCheckInPopupView`

**Files:**
- Create: `BabyTown/Components/DailyCheckInPopupView.swift`

**Interfaces:**
- Produces: `CheckInPopupMode` (used by Task 3), `DailyCheckInPopupView(mode:streak:checkedInToday:onDismiss:)`

- [ ] **Step 1: Create the file with the full implementation**

```swift
import SwiftUI

enum CheckInPopupMode: Equatable {
    case claiming(coins: Int)
    case reviewing
}

struct DailyCheckInPopupView: View {
    let mode: CheckInPopupMode
    let streak: Int
    let checkedInToday: Bool
    let onDismiss: () -> Void

    @State private var revealed = false
    @State private var cardScale: CGFloat = 0.92
    @State private var cardOpacity: Double = 0
    @State private var shimmerPulsed = false

    private var todayIndex: Int {
        if checkedInToday && streak == 0 { return 7 }
        if checkedInToday { return streak }
        return min(streak + 1, 7)
    }

    private var claimCoins: Int {
        if case .claiming(let coins) = mode { return coins }
        return 0
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            card
                .padding(.horizontal, 24)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                cardScale = 1
                cardOpacity = 1
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: 20) {
            header
            starRow
            if case .claiming = mode {
                rewardSlot
            }
            buttonArea
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), BabyTownTheme.accent.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: BabyTownTheme.accent.opacity(0.18), radius: 28, y: 14)
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Daily Check-in")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary)

            Text("Come back each day to keep your streak")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var starRow: some View {
        HStack(spacing: 10) {
            ForEach(1...7, id: \.self) { index in
                starView(for: index)
            }
        }
    }

    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let size: CGFloat = index == 7 ? 34 : 28
        if index < todayIndex {
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(BabyTownTheme.accent)
        } else if index == todayIndex {
            todayStar(size: size)
        } else {
            Image(systemName: "star")
                .font(.system(size: size))
                .foregroundStyle(Color.secondary.opacity(0.3))
        }
    }

    @ViewBuilder
    private func todayStar(size: CGFloat) -> some View {
        switch mode {
        case .claiming:
            if revealed {
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .scaleEffect(shimmerPulsed ? 1.0 : 1.22)
                    .opacity(shimmerPulsed ? 1.0 : 0.72)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.75)
                            .repeatForever(autoreverses: true)
                        ) {
                            shimmerPulsed = true
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                            revealed = true
                        }
                    }
                    .accessibilityLabel("Tap to reveal your reward")
                    .accessibilityAddTraits(.isButton)
            }
        case .reviewing:
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(BabyTownTheme.accent)
        }
    }

    // Reserves vertical space so the card doesn't jump when the reward appears.
    private var rewardSlot: some View {
        ZStack {
            Color.clear.frame(height: 44)
            if revealed {
                HStack(spacing: 8) {
                    PetCoinIcon(size: 30)
                    Text("+\(claimCoins)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(BabyTownTheme.accentDeep)
                }
                .transition(
                    .opacity.combined(with: .scale(scale: 0.8))
                )
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: revealed)
    }

    @ViewBuilder
    private var buttonArea: some View {
        switch mode {
        case .claiming:
            if revealed {
                dismissButton("Collect")
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        case .reviewing:
            dismissButton("Close")
        }
    }

    private func dismissButton(_ title: String) -> some View {
        Button(action: onDismiss) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(BabyTownTheme.buttonGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: BabyTownTheme.buttonShadow, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [BabyTownTheme.cardTintLight, BabyTownTheme.cardTintDeep.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview("Claiming — Day 3, not yet tapped") {
    DailyCheckInPopupView(
        mode: .claiming(coins: 14),
        streak: 3,
        checkedInToday: true,
        onDismiss: {}
    )
}

#Preview("Claiming — Day 7 bonus") {
    DailyCheckInPopupView(
        mode: .claiming(coins: 100),
        streak: 0,
        checkedInToday: true,
        onDismiss: {}
    )
}

#Preview("Reviewing — Day 5 streak") {
    DailyCheckInPopupView(
        mode: .reviewing,
        streak: 5,
        checkedInToday: true,
        onDismiss: {}
    )
}

#Preview("Reviewing — not yet checked in today") {
    DailyCheckInPopupView(
        mode: .reviewing,
        streak: 2,
        checkedInToday: false,
        onDismiss: {}
    )
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manually verify in Xcode Previews**

Open `DailyCheckInPopupView.swift` in Xcode and check all four previews:
- Day 3 claiming: star 3 is large and pulsing, stars 1-2 filled, stars 4-7 outlined. No button visible. Tapping star 3 reveals `+14` coins and a "Collect" button.
- Day 7 bonus: all 7 stars shown. The big star (34pt) at position 7 is pulsing. Tapping reveals `+100` coins.
- Reviewing Day 5: star 5 is static (same color as past stars), no interaction.
- Reviewing not-yet: star 3 is today but static (reviewing mode, no interaction).

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Components/DailyCheckInPopupView.swift
git commit -m "feat: add DailyCheckInPopupView component"
```

---

## Task 2: Add `onTap` to `DailyCheckInStreakView` and `onStreakTap` to `PetHUDView`

**Files:**
- Modify: `BabyTown/Components/DailyCheckInStreakView.swift:3-5`
- Modify: `BabyTown/Components/DailyCheckInStreakView.swift:15-22` (body)
- Modify: `BabyTown/Components/PetHUDView.swift:266-267` (props)
- Modify: `BabyTown/Components/PetHUDView.swift:295-300` (call site)

**Interfaces:**
- Consumes: nothing new
- Produces: `DailyCheckInStreakView(streak:checkedInToday:onTap:)`, `PetHUDView(...onStreakTap:...)` (used by Task 3)

- [ ] **Step 1: Add `onTap` to `DailyCheckInStreakView`**

In `BabyTown/Components/DailyCheckInStreakView.swift`, replace:

```swift
struct DailyCheckInStreakView: View {
    let streak: Int
    let checkedInToday: Bool

    @State private var pulsed = false
```

with:

```swift
struct DailyCheckInStreakView: View {
    let streak: Int
    let checkedInToday: Bool
    var onTap: (() -> Void)? = nil

    @State private var pulsed = false
```

- [ ] **Step 2: Wrap the strip in a `Button` when `onTap` is set**

Replace the `body` property:

```swift
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { index in
                dot(for: index)
            }
        }
        .frame(height: 20)
    }
```

with:

```swift
    var body: some View {
        let strip = HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { index in
                dot(for: index)
            }
        }
        .frame(height: 20)

        if let onTap {
            Button(action: onTap) { strip }
                .buttonStyle(.plain)
        } else {
            strip
        }
    }
```

- [ ] **Step 3: Add `onStreakTap` to `PetHUDView`**

In `BabyTown/Components/PetHUDView.swift`, after the existing `var checkedInToday: Bool = false` line, add:

```swift
    var onStreakTap: (() -> Void)? = nil
```

- [ ] **Step 4: Thread `onStreakTap` into the `DailyCheckInStreakView` call in `PetHUDView`**

Replace:

```swift
                if currentSkin != nil {
                    DailyCheckInStreakView(
                        streak: checkInStreak,
                        checkedInToday: checkedInToday
                    )
                }
```

with:

```swift
                if currentSkin != nil {
                    DailyCheckInStreakView(
                        streak: checkInStreak,
                        checkedInToday: checkedInToday,
                        onTap: onStreakTap
                    )
                }
```

- [ ] **Step 5: Verify it builds**

```bash
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add BabyTown/Components/DailyCheckInStreakView.swift BabyTown/Components/PetHUDView.swift
git commit -m "feat: add onTap to DailyCheckInStreakView and thread through PetHUDView"
```

---

## Task 3: Wire the popup into `PetRoomView`

**Files:**
- Modify: `BabyTown/Views/PetRoomView.swift`

**Interfaces:**
- Consumes: `CheckInPopupMode` (Task 1), `DailyCheckInPopupView` (Task 1), `onStreakTap` on `PetHUDView` (Task 2)
- Produces: completed feature

- [ ] **Step 1: Add the `checkInPopup` state variable**

In `BabyTown/Views/PetRoomView.swift`, after the `@State private var showWelcomeTutorial = false` line (around line 45), add:

```swift
    @State private var checkInPopup: CheckInPopupMode?
```

- [ ] **Step 2: Replace the coinBurst in `onAppear` with the popup**

In `sceneView(geo:)` → `.onAppear`, replace:

```swift
            let awarded = viewModel.checkInForPetRoom()
            if awarded > 0 {
                coinBurst = (amount: awarded, id: UUID())
            }
```

with:

```swift
            let awarded = viewModel.checkInForPetRoom()
            if awarded > 0 {
                checkInPopup = .claiming(coins: awarded)
            }
```

- [ ] **Step 3: Gate the `lastAward` onChange so it skips the burst while the popup is visible**

Find the `.onChange(of: viewModel.lastAward?.id)` modifier (around line 452) and replace:

```swift
        .onChange(of: viewModel.lastAward?.id) { _, _ in
            if let award = viewModel.lastAward { triggerCoinBurst(award.amount) }
        }
```

with:

```swift
        .onChange(of: viewModel.lastAward?.id) { _, _ in
            guard checkInPopup == nil else { return }
            if let award = viewModel.lastAward { triggerCoinBurst(award.amount) }
        }
```

- [ ] **Step 4: Update `syncSceneSheetPause` to include the popup**

Replace:

```swift
    private func syncSceneSheetPause() {
        scene?.setSheetCoverActive(showMarket || showOwnedItems || showWelcomeTutorial)
    }
```

with:

```swift
    private func syncSceneSheetPause() {
        scene?.setSheetCoverActive(showMarket || showOwnedItems || showWelcomeTutorial || checkInPopup != nil)
    }
```

- [ ] **Step 5: Add `onStreakTap` to the `PetHUDView` call site**

Find the `PetHUDView(...)` call inside the `TimelineView` in `.safeAreaInset` (around line 385). After `checkedInToday: viewModel.checkedInToday`, add:

```swift
                        onStreakTap: { checkInPopup = .reviewing }
```

The full updated call site:

```swift
                    PetHUDView(
                        coins: viewModel.coins,
                        hunger: viewModel.hunger,
                        thirst: viewModel.thirst,
                        litter: viewModel.litter,
                        happiness: viewModel.happiness,
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
                        onAdoptMore: onChangePet,
                        checkInStreak: viewModel.checkInStreak,
                        checkedInToday: viewModel.checkedInToday,
                        onStreakTap: { checkInPopup = .reviewing }
                    )
```

- [ ] **Step 6: Add the popup overlay and its animation/onChange**

Immediately before the welcome tutorial `.overlay` block (around line 480), insert:

```swift
        .overlay {
            if let mode = checkInPopup {
                DailyCheckInPopupView(
                    mode: mode,
                    streak: viewModel.checkInStreak,
                    checkedInToday: viewModel.checkedInToday,
                    onDismiss: { withAnimation { checkInPopup = nil } }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: checkInPopup != nil)
        .onChange(of: checkInPopup) { _, _ in syncSceneSheetPause() }
```

After this insertion the file continues with the existing welcome tutorial overlay:

```swift
        .overlay {
            if showWelcomeTutorial {
                PetRoomWelcomeTutorialView(...)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showWelcomeTutorial)
        .toolbar(showWelcomeTutorial ? .hidden : .visible, for: .navigationBar)
```

- [ ] **Step 7: Verify it builds**

```bash
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Manual smoke test on simulator**

Launch the app and open the pet room. Verify:

1. **First open of the day:** The `DailyCheckInPopupView` appears (not the old coin-burst text). The today star pulses. Tapping it reveals the coin amount and the "Collect" button. Tapping "Collect" dismisses the popup.
2. **Subsequent open same day:** No popup appears on entry.
3. **Tap the 7-dot streak strip in the HUD:** The popup appears in `.reviewing` mode — the today star is static, "Close" button is visible, no tapping interaction on the star.
4. **Care actions still burst:** After dismissing the popup, pet the cat or fill water. The `+N 🪙` coin burst still appears for non-check-in awards.

- [ ] **Step 9: Commit**

```bash
git add BabyTown/Views/PetRoomView.swift
git commit -m "feat: wire DailyCheckInPopupView into PetRoomView"
```
