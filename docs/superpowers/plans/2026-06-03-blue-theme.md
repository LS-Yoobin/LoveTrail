# Blue Color Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user-selectable Blue color theme (chosen during onboarding) that recolors the entire app's pink/red accents to blue, while Pink stays pixel-identical to today.

**Architecture:** A `ThemeManager` singleton holds the chosen `ColorTheme`, persisted via `DataPersistenceManager`. `BabyTownTheme`'s color tokens become theme-aware computed properties (Pink branch = current literals, Blue branch = blue counterparts). Inline pink/red literals scattered across views and SpriteKit scenes are routed through new theme tokens so they flip too. Semantic reds (REC dots, badges, confetti) are explicitly preserved.

**Tech Stack:** SwiftUI, SpriteKit (SKColor), UIKit (UIColor), Xcode project `BabyTown.xcodeproj` (scheme `BabyTown`). No app-target unit-test harness exists; verification is `xcodebuild build` + visual simulator routing (per project memory: temporarily route the app entry point to a screen, observe, then revert).

---

## Conventions used throughout

**Build command** (substitute a booted simulator UDID; `iPhone 17 Pro` = `843D648C-3CED-4715-AB0F-B4AB9FE6F9D3`):

```bash
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'platform=iOS Simulator,id=843D648C-3CED-4715-AB0F-B4AB9FE6F9D3' \
  build 2>&1 | tail -20
```
Expected on success: `** BUILD SUCCEEDED **`.

**Standard blue anchor:** `Color(red: 0.22, green: 0.48, blue: 0.96)` (matches existing `savePillFill`).
**Deep blue anchor:** `Color(red: 0.14, green: 0.34, blue: 0.78)`.
**Baby-blue card:** `Color(red: 0.80, green: 0.88, blue: 0.96)`.

**Semantic colors that must NEVER be themed (leave as-is):**
- `PolaroidCameraView.swift` lines ~362/371/524 — `Color.red` shutter/REC affordance.
- `PetRoomScene.swift` ~2942/2943/2973/2974 — `SKColor(red:1.0,…)` REC indicator dot.
- `ProfileGardenNoteView.swift:292`, `ProfileStickerView.swift:77` — `Color.red` notification badge dots.
- `Scene1ConcertView.swift` — rainbow confetti palettes (`.pink`/`.red`/multicolor arrays).
- `Pet.swift:69` calico orange; `PetHUDView` yellow XP bar `(1.0,0.93,0.42)`/`(0.96,0.78,0.14)`; `PetShopCatalog` yellow `(0.98,0.78,0.20)`; `LoveGardenScene` yellow centers `(0.98,0.85,0.45)`/`(1.0,0.95,0.7)`.
- Any `systemGray*`, neutral paper `(0.97,0.96,0.93)`/`(0.96,0.95,0.93)`, white, black.
- Night-background blues in `HomeBackgroundView`.

---

# PHASE A — Theme infrastructure + token-driven bulk flip

*Outcome: Pink renders identically to today; Blue flips every surface that already reads a `BabyTownTheme` token (the majority of the app). Independently shippable.*

### Task A1: `ColorTheme` enum

**Files:**
- Create: `BabyTown/Theme/ColorTheme.swift`

- [ ] **Step 1: Create the enum**

```swift
import Foundation

/// The two selectable app color themes. Default is `.pink` (the original look).
enum ColorTheme: String, CaseIterable, Codable {
    case pink
    case blue
}
```

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Theme/ColorTheme.swift
git commit -m "feat(theme): add ColorTheme enum"
```

---

### Task A2: Persistence in `DataPersistenceManager`

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

- [ ] **Step 1: Find an existing simple save/load pair to mirror**

Run: `grep -n "func saveUserNickname\|UserDefaults\|private let defaults\|standard" BabyTown/Services/DataPersistenceManager.swift | head`
Expected: shows the UserDefaults accessor pattern (e.g. `UserDefaults.standard`) and existing `save…`/`load…` methods to copy style from.

- [ ] **Step 2: Add the key + methods**

Add near the other UserDefaults-backed methods (match the file's existing accessor — replace `UserDefaults.standard` below if the file uses a stored `defaults` property):

```swift
// MARK: - Color Theme

private static let colorThemeKey = "colorTheme"

func saveColorTheme(_ theme: ColorTheme) {
    UserDefaults.standard.set(theme.rawValue, forKey: Self.colorThemeKey)
}

/// Returns the persisted theme, defaulting to `.pink` when unset or invalid.
func loadColorTheme() -> ColorTheme {
    guard let raw = UserDefaults.standard.string(forKey: Self.colorThemeKey),
          let theme = ColorTheme(rawValue: raw) else {
        return .pink
    }
    return theme
}
```

> If `DataPersistenceManager` is not an `enum` with `static let colorThemeKey` support (e.g. it's a `class`/`final class`), use an instance `private let colorThemeKey = "colorTheme"` and reference `colorThemeKey` instead of `Self.colorThemeKey`. Verify in Step 1.

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Services/DataPersistenceManager.swift
git commit -m "feat(theme): persist ColorTheme in DataPersistenceManager"
```

---

### Task A3: `ThemeManager`

**Files:**
- Create: `BabyTown/Services/ThemeManager.swift`

- [ ] **Step 1: Create the manager**

```swift
import SwiftUI
import Combine

/// Holds the app's current color theme. Loaded from persistence at launch and
/// updated during onboarding. `BabyTownTheme` tokens read `ThemeManager.shared.theme`.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var theme: ColorTheme

    private init() {
        self.theme = DataPersistenceManager.shared.loadColorTheme()
    }

    /// Sets and persists the theme. Call from the onboarding picker.
    func setTheme(_ theme: ColorTheme) {
        self.theme = theme
        DataPersistenceManager.shared.saveColorTheme(theme)
    }
}
```

> If `DataPersistenceManager.shared` is not the access pattern (Step A2.1 revealed the real one), use that instead.

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Services/ThemeManager.swift
git commit -m "feat(theme): add ThemeManager singleton"
```

---

### Task A4: Make `BabyTownTheme` tokens theme-aware

**Files:**
- Modify: `BabyTown/Theme/BabyTownTheme.swift`

This converts stored `let` color tokens into computed `static var`s that branch on the theme. Pink branch returns the **exact current literals**; Blue returns counterparts.

- [ ] **Step 1: Replace the token block**

Replace lines 5–68 (the `// MARK: - Backgrounds` through the end of `accentIconBackdropGradient`) with the following. Keep `cardShadow`, `cardRadius`, `textPrimary/Secondary/Tertiary`, `daySearchBar*`, and `savePillFill*` exactly as they are today (those are not pink and stay shared).

```swift
    // MARK: - Theme

    static var theme: ColorTheme { ThemeManager.shared.theme }
    private static var isBlue: Bool { theme == .blue }

    // MARK: - Backgrounds

    static let background = Color.white
    static var blush: Color { isBlue ? Color.blue.opacity(0.15) : Color.pink.opacity(0.15) }
    static var backgroundGradient: LinearGradient {
        // Pink: white→white (current). Blue: white→soft light blue.
        isBlue
            ? LinearGradient(colors: [background, Color(red: 0.88, green: 0.94, blue: 0.99)],
                             startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [background, background], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Accents

    static var accent: Color { isBlue ? Color(red: 0.22, green: 0.48, blue: 0.96) : Color.pink }
    static var accentDeep: Color {
        isBlue ? Color(red: 0.14, green: 0.34, blue: 0.78) : Color(red: 0.88, green: 0.22, blue: 0.38)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .leading, endPoint: .trailing)
    }
    static var accentSoft: Color { accent.opacity(0.08) }

    // MARK: - Cards

    static var cardBackground: Color {
        isBlue ? Color(red: 0.80, green: 0.88, blue: 0.96) : Color(red: 0.96, green: 0.82, blue: 0.86)
    }
    static let cardShadow = Color.black.opacity(0.05)
    static let cardRadius: CGFloat = 18

    // MARK: - Buttons

    static var buttonGradient: LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.82)], startPoint: .leading, endPoint: .trailing)
    }
    static var buttonShadow: Color { accent.opacity(0.3) }

    /// Pink → red (or blue → deep blue) icon tint used on onboarding access cards and the home camera control.
    static var accentIconGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentIconBackdropGradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(0.15), accentDeep.opacity(0.08)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
```

Keep the `// MARK: - Text`, `daySearchBar*`, and `savePillFill`/`savePillShadow` declarations from the original file unchanged (move them to sit after the blocks above if needed). Do not delete them.

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`. (All 250+ `BabyTownTheme.*` call sites continue to compile; tokens are now `var` not `let`.)

- [ ] **Step 3: Visual check — Pink unchanged**

Confirm `ThemeManager` defaults to `.pink` (fresh install / no persisted key). Launch the app in the booted simulator and confirm the home screen looks identical to before.

```bash
xcrun simctl launch booted <BUNDLE_ID>   # find via: grep PRODUCT_BUNDLE_IDENTIFIER BabyTown.xcodeproj/project.pbxproj | head -1
```
Expected: home screen renders pink exactly as today.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Theme/BabyTownTheme.swift
git commit -m "feat(theme): make BabyTownTheme tokens theme-aware (pink/blue)"
```

---

### Task A5: Add SKColor / UIColor theme accessors

SpriteKit (`PetRoomScene`, `LoveGardenScene`) and UIKit (map markers, `PetShopCatalog`) need non-SwiftUI color types. Provide bridged accessors so scenes can flip too.

**Files:**
- Modify: `BabyTown/Theme/BabyTownTheme.swift`

- [ ] **Step 1: Append bridged accessors**

Add at the end of the `BabyTownTheme` enum:

```swift
    // MARK: - Bridged colors (SpriteKit / UIKit)

    static var accentUIColor: UIColor { UIColor(accent) }
    static var accentDeepUIColor: UIColor { UIColor(accentDeep) }

    /// Pet-room ambient surfaces. Pink: warm peach. Blue: cool light blue.
    static var roomWallTop: Color {
        isBlue ? Color(red: 0.93, green: 0.96, blue: 1.0) : Color(red: 1.0, green: 0.93, blue: 0.95)
    }
    static var roomWallBottom: Color {
        isBlue ? Color(red: 0.83, green: 0.90, blue: 0.98) : Color(red: 0.99, green: 0.86, blue: 0.83)
    }
    static var roomFloor: Color {
        isBlue ? Color(red: 0.74, green: 0.84, blue: 0.95) : Color(red: 0.97, green: 0.80, blue: 0.74)
    }
    static var roomWallTopSK: SKColor { SKColor(roomWallTop) }
    static var roomWallBottomSK: SKColor { SKColor(roomWallBottom) }
    static var roomFloorSK: SKColor { SKColor(roomFloor) }
    static var accentSK: SKColor { SKColor(accent) }
    static var accentDeepSK: SKColor { SKColor(accentDeep) }
```

Add `import SpriteKit` at the top of `BabyTownTheme.swift` (alongside `import SwiftUI`).

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Theme/BabyTownTheme.swift
git commit -m "feat(theme): add SKColor/UIColor theme accessors"
```

---

# PHASE B — Onboarding theme picker

*Outcome: the user is asked Pink/Blue right after their nickname; the choice persists and routes forward.*

### Task B1: `ColorThemeView`

**Files:**
- Create: `BabyTown/Views/ColorThemeView.swift`

- [ ] **Step 1: Create the picker view** (mirrors `NicknameView`'s layout/idiom — light gradient background, serif prompt, capsule continue is replaced by two tappable swatches)

```swift
import SwiftUI

struct ColorThemeView: View {

    /// Called with the chosen theme once the user confirms.
    var onContinue: (ColorTheme) -> Void

    @State private var selected: ColorTheme = .pink
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, (selected == .blue ? Color.blue : Color.pink).opacity(0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: selected)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Text("What color theme do you prefer?")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .multilineTextAlignment(.center)
                    Text("You can enjoy the app in pink or blue")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                HStack(spacing: 20) {
                    swatch(.pink, label: "Pink", color: .pink)
                    swatch(.blue, label: "Blue", color: Color(red: 0.22, green: 0.48, blue: 0.96))
                }
                .padding(.horizontal, 32)

                Spacer()

                continueButton
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { contentOpacity = 1.0 }
        }
    }

    private func swatch(_ theme: ColorTheme, label: String, color: Color) -> some View {
        let isSelected = selected == theme
        return Button {
            selected = theme
        } label: {
            VStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [color, color.opacity(0.8)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: color.opacity(0.35), radius: 10, y: 4)
                Text(label)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color(.systemGray4),
                            lineWidth: isSelected ? 3 : 1)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var continueButton: some View {
        Button {
            onContinue(selected)
        } label: {
            Text("Continue")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: selected == .blue
                                ? [Color(red: 0.22, green: 0.48, blue: 0.96), Color(red: 0.14, green: 0.34, blue: 0.78)]
                                : [.pink, .pink.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
        }
    }
}

#Preview {
    ColorThemeView { print("theme: \($0)") }
}
```

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/ColorThemeView.swift
git commit -m "feat(onboarding): add ColorThemeView picker"
```

---

### Task B2: Wire `ColorThemeView` into the onboarding flow

**Files:**
- Modify: `BabyTown/ContentView.swift`

- [ ] **Step 1: Add the screen case**

In `enum Screen` (line 12-15), add `colorTheme`:

```swift
    enum Screen {
        case launch, welcome, storyOnboarding, nickname, colorTheme, firstMemories, howItWorks, photoAccess, home, selectPhotos
        case loveGarden   // TEMP (Slice 1): direct route to verify the garden; remove when the cat-room door lands.
    }
```

- [ ] **Step 2: Route nickname → colorTheme**

In the `.nickname` case (lines 90-97), change the destination from `.firstMemories` to `.colorTheme`:

```swift
            case .nickname:
                NicknameView { nickname in
                    DataPersistenceManager.shared.saveUserNickname(nickname)
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .colorTheme
                    }
                }
                .transition(.opacity)
```

- [ ] **Step 3: Add the colorTheme case** (insert immediately after the `.nickname` case)

```swift
            case .colorTheme:
                ColorThemeView { theme in
                    ThemeManager.shared.setTheme(theme)
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .firstMemories
                    }
                }
                .transition(.opacity)
```

- [ ] **Step 4: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Visual check — full onboarding routing**

Temporarily set the initial `targetScreen` to `.nickname` (or reset onboarding via the in-app reset), launch, and walk Nickname → ColorTheme → FirstMemories. Pick Blue; confirm it advances. Relaunch and confirm the home background is light-blue (theme persisted). Revert any temporary routing change.

- [ ] **Step 6: Commit**

```bash
git add BabyTown/ContentView.swift
git commit -m "feat(onboarding): insert color-theme step after nickname"
```

---

# PHASE C — Inline literal sweep: onboarding & welcome surfaces

*These views use hard-coded `.pink`/`.red`. Route them through `BabyTownTheme` tokens so Blue flips them. Pink output is unchanged because the tokens' pink branch equals the literals.*

### Task C1: NicknameView, WelcomeView, FirstMemoriesView, HowItWorksView, PhotoAccessView

**Files:**
- Modify: `BabyTown/Views/NicknameView.swift`
- Modify: `BabyTown/Views/WelcomeView.swift`
- Modify: `BabyTown/Views/FirstMemoriesView.swift`
- Modify: `BabyTown/Views/HowItWorksView.swift`
- Modify: `BabyTown/Views/PhotoAccessView.swift`

> Note: `NicknameView` runs *before* the theme is chosen, so it will always render Pink in practice. Still route it through tokens for consistency (harmless — token resolves to pink there).

- [ ] **Step 1: Replace literals with tokens**

Apply these substitutions (each `colors: [.pink, .pink.opacity(0.8)]` continue-button gradient → `BabyTownTheme.buttonGradient`; background tints → `BabyTownTheme.accentSoft`-style; pink→red CTA gradients → `BabyTownTheme.accentIconGradient` colors). Concretely:

- `NicknameView.swift:80` `colors: [.white, Color.pink.opacity(0.06)]` → `colors: [.white, BabyTownTheme.accent.opacity(0.06)]`
- `NicknameView.swift:99` `colors: [.pink, .pink.opacity(0.8)]` → replace the whole `.fill(...)` gradient for the enabled state with `BabyTownTheme.buttonGradient`
- `NicknameView.swift:113` `.pink.opacity(0.3)` → `BabyTownTheme.accent.opacity(0.3)`
- `WelcomeView.swift:18` `Color.pink.opacity(0.06)` → `BabyTownTheme.accent.opacity(0.06)`
- `WelcomeView.swift:49,85` `.pink.opacity(0.3)` → `BabyTownTheme.accent.opacity(0.3)`
- `WelcomeView.swift:77-78` `Color.pink, Color.pink.opacity(0.8)` → `BabyTownTheme.accent, BabyTownTheme.accent.opacity(0.8)`
- `FirstMemoriesView.swift:37` `Color.pink.opacity(0.06)` → `BabyTownTheme.accent.opacity(0.06)`
- `FirstMemoriesView.swift:119` `colors: [.pink, .pink.opacity(0.8)]` → `BabyTownTheme.buttonGradient` (replace gradient)
- `FirstMemoriesView.swift:134` `.pink.opacity(0.3)` → `BabyTownTheme.accent.opacity(0.3)`
- `HowItWorksView.swift:50` `Color.pink.opacity(0.05)` → `BabyTownTheme.accent.opacity(0.05)`
- `HowItWorksView.swift:67` `.foregroundStyle(.pink)` → `.foregroundStyle(BabyTownTheme.accent)`
- `HowItWorksView.swift:119` `colors: [.pink, .red.opacity(0.75)]` → `colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep.opacity(0.85)]`
- `HowItWorksView.swift:124` `.pink.opacity(0.35)` → `BabyTownTheme.accent.opacity(0.35)`
- `PhotoAccessView.swift:51` `Color.pink.opacity(0.06)` → `BabyTownTheme.accent.opacity(0.06)`
- `PhotoAccessView.swift:65,196` `[Color.pink.opacity(0.15), Color.red.opacity(0.08)]` → `[BabyTownTheme.accent.opacity(0.15), BabyTownTheme.accentDeep.opacity(0.08)]`
- `PhotoAccessView.swift:76,146,223` `[.pink, .red.opacity(0.8|0.75)]` → `[BabyTownTheme.accent, BabyTownTheme.accentDeep.opacity(0.8)]`
- `PhotoAccessView.swift:151` `.pink.opacity(0.35)` → `BabyTownTheme.accent.opacity(0.35)`

Use `Read` on each file to confirm exact surrounding text before each `Edit`.

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Visual check**

With theme = Blue, route through onboarding (or reset) and confirm Welcome / HowItWorks / PhotoAccess / FirstMemories show blue CTAs and tints. Switch to Pink (reset, pick Pink) and confirm identical to today.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/NicknameView.swift BabyTown/Views/WelcomeView.swift \
        BabyTown/Views/FirstMemoriesView.swift BabyTown/Views/HowItWorksView.swift \
        BabyTown/Views/PhotoAccessView.swift
git commit -m "feat(theme): route onboarding pink literals through theme tokens"
```

---

# PHASE D — Inline literal sweep: shared components

### Task D1: Heart / memory / misc components

**Files (each modify):**
- `BabyTown/Components/Scene5HeartTrailView.swift` (lines 32-33)
- `BabyTown/Components/PetHUDView.swift` (line 211 — `Color.pink.opacity(0.2)`; NOT the yellow XP bar)
- `BabyTown/Components/MemorySelectionCard.swift` (45,50,56,72,77,91 — keep `.green` at 91)
- `BabyTown/Components/HeartTrailHeader.swift` (32,37,50)
- `BabyTown/Components/BenefitRow.swift` (13,17)
- `BabyTown/Components/BowlInspectCard.swift` (84,94 — `tint: .pink`)
- `BabyTown/Components/FloatingHeartsView.swift` (32)
- `BabyTown/Components/PulsingDotsLoader.swift` (8)
- `BabyTown/Components/HeroPhotoPreview.swift` (29,40)
- `BabyTown/Components/MemoryMapMarkerAnnotationView.swift` (7 — `UIColor(red:1.0,0.4,0.5)`)
- `BabyTown/Components/ProcessingMemoryCard.swift` (72 — `(0.95,0.3,0.35)`)
- `BabyTown/Components/MemoryStickerEditFooterBar.swift` (7 — `(0.93,0.55,0.52)`)
- `BabyTown/Views/ValentineCardDetailView.swift` (10 — `accentColor = Color.pink`)
- `BabyTown/Views/SelectPhotosView.swift` (522 — `(0.95,0.3,0.35)`)
- `BabyTown/Components/PhotoGridCell.swift` (83 — `(0.95,0.25,0.3)`)

- [ ] **Step 1: Apply substitutions**

Rules (Read each file to confirm context first):
- `.pink` / `Color.pink` (any opacity) → `BabyTownTheme.accent` (preserve `.opacity(x)`).
- `.red.opacity(x)` paired in a pink→red gradient → `BabyTownTheme.accentDeep.opacity(x)`.
- Rosy mid literals `Color(red:0.95,green:0.3,blue:0.35)` / `(0.93,0.55,0.52)` → `BabyTownTheme.accentDeep`.
- `UIColor(red:1.0,green:0.4,blue:0.5,…)` (map marker) → `BabyTownTheme.accentUIColor`.
- `Color(red:0.95,green:0.25,blue:0.3)` → `BabyTownTheme.accentDeep`.
- Leave `.green` (MemorySelectionCard:91) untouched.

- [ ] **Step 2: Build** → Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Visual check (Blue)** — open the pet HUD, memory selection, map (markers), Valentine card; confirm blue, no stray pink. Verify Pink unchanged.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Components/Scene5HeartTrailView.swift BabyTown/Components/PetHUDView.swift \
  BabyTown/Components/MemorySelectionCard.swift BabyTown/Components/HeartTrailHeader.swift \
  BabyTown/Components/BenefitRow.swift BabyTown/Components/BowlInspectCard.swift \
  BabyTown/Components/FloatingHeartsView.swift BabyTown/Components/PulsingDotsLoader.swift \
  BabyTown/Components/HeroPhotoPreview.swift BabyTown/Components/MemoryMapMarkerAnnotationView.swift \
  BabyTown/Components/ProcessingMemoryCard.swift BabyTown/Components/MemoryStickerEditFooterBar.swift \
  BabyTown/Views/ValentineCardDetailView.swift BabyTown/Views/SelectPhotosView.swift \
  BabyTown/Components/PhotoGridCell.swift
git commit -m "feat(theme): route component pink literals through theme tokens"
```

---

# PHASE E — Inline literal sweep: branded gradients (logo, story theme, pet cards)

### Task E1: BabyTownLogoView

**Files:**
- Modify: `BabyTown/Components/BabyTownLogoView.swift` (lines 14-15, 30, 50-51, 57, 112-113, 125, 140-141, 147)

- [ ] **Step 1:** Replace the rosy literals:
- Light blush pair `(1.0,0.95,0.95)`/`(1.0,0.9,0.9)` and `(1.0,0.95,0.95)`/`(1.0,0.88,0.88)` → `[BabyTownTheme.accent.opacity(0.10), BabyTownTheme.accent.opacity(0.18)]` (keeps a soft tint that flips).
- Mid red `(0.95,0.3,0.35)` → `BabyTownTheme.accentDeep`.
- Deep red `(0.98,0.35,0.4)`/`(0.9,0.25,0.35)` gradient → `[BabyTownTheme.accent, BabyTownTheme.accentDeep]`.
- Shadow `(0.9,0.25,0.35)` → `BabyTownTheme.accentDeep`.

- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Visual check** — launch screen / any logo placement shows blue logo under Blue, original red under Pink.
- [ ] **Step 4: Commit**

```bash
git add BabyTown/Components/BabyTownLogoView.swift
git commit -m "feat(theme): theme the BabyTown logo gradients"
```

### Task E2: StoryOnboardingTheme

**Files:**
- Modify: `BabyTown/Components/StoryOnboardingTheme.swift` (lines 4-6)

- [ ] **Step 1:** Convert the stored `static let`s to theme-aware `static var`s:

```swift
    static var backgroundBlush: Color {
        BabyTownTheme.theme == .blue ? Color(red: 0.95, green: 0.97, blue: 1.0) : Color(red: 1.0, green: 0.95, blue: 0.95)
    }
    static var primaryRed: Color { BabyTownTheme.accentDeep }
    static var accentPink: Color {
        BabyTownTheme.theme == .blue ? Color(red: 0.62, green: 0.78, blue: 1.0) : Color(red: 1.0, green: 0.7, blue: 0.75)
    }
```

- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Visual check** — Replay story from home; confirm blue under Blue.
- [ ] **Step 4: Commit**

```bash
git add BabyTown/Components/StoryOnboardingTheme.swift
git commit -m "feat(theme): theme the story onboarding palette"
```

### Task E3: PetProfileCard & pet sheet rose gradients

**Files:**
- Modify: `BabyTown/Components/PetProfileCard.swift` (lines 33-34, 120, 133-135)
- Modify: `BabyTown/Components/PetRenameSheet.swift` (lines 41,43)
- Modify: `BabyTown/Views/PetOwnedItemsSheet.swift` (lines 34-35)
- Modify: `BabyTown/Components/PetTrickBookSheet.swift` (line 30)

- [ ] **Step 1: Add two card-tint tokens to `BabyTownTheme`** (append in the Cards section):

```swift
    /// Light card gradient endpoints used by pet cards/sheets. Pink: warm rose. Blue: cool blue.
    static var cardTintLight: Color {
        isBlue ? Color(red: 0.96, green: 0.98, blue: 1.0) : Color(red: 1.0, green: 0.97, blue: 0.94)
    }
    static var cardTintDeep: Color {
        isBlue ? Color(red: 0.86, green: 0.92, blue: 0.99) : Color(red: 0.99, green: 0.90, blue: 0.93)
    }
```

- [ ] **Step 2: Replace the rose literals** with `BabyTownTheme.cardTintLight` / `BabyTownTheme.cardTintDeep` (use the lighter token for the high-value endpoint, deeper token for the rosier endpoint). For `PetTrickBookSheet:30` single `(0.99,0.96,0.94)` background → `BabyTownTheme.cardTintLight`. Keep the neutral `panelFill (0.98,0.96,0.97)` at PetProfileCard:72 as-is (near-neutral).

- [ ] **Step 3: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 4: Visual check** — Visit Pet → name tag + profile popover; pet rename sheet; owned items; trick book — all blue-tinted under Blue.
- [ ] **Step 5: Commit**

```bash
git add BabyTown/Theme/BabyTownTheme.swift BabyTown/Components/PetProfileCard.swift \
  BabyTown/Components/PetRenameSheet.swift BabyTown/Views/PetOwnedItemsSheet.swift \
  BabyTown/Components/PetTrickBookSheet.swift
git commit -m "feat(theme): theme pet card/sheet rose gradients"
```

---

# PHASE F — SpriteKit scenes

### Task F1: PetRoomScene ambient surfaces

**Files:**
- Modify: `BabyTown/Game/PetRoomScene.swift` (lines 486-487 walls, 493 floor, 973 rect `(0.90,0.62,0.66,0.55)`, 3622 heart `(0.92,0.30,0.45)`)

- [ ] **Step 1: Replace** (leave REC-dot lines 2942/2943/2973/2974 untouched):
- 486 wall top → `BabyTownTheme.roomWallTopSK`
- 487 wall bottom → `BabyTownTheme.roomWallBottomSK`
- 493 floor → `BabyTownTheme.roomFloorSK`
- 973 `SKColor(red:0.90,green:0.62,blue:0.66,alpha:0.55)` → `BabyTownTheme.accentSK.withAlphaComponent(0.55)`
- 3622 `SKColor(red:0.92,green:0.30,blue:0.45,alpha:1)` → `BabyTownTheme.accentDeepSK`

- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Visual check** — open the pet room; under Blue the walls/floor read cool blue, REC dot still red. Pink unchanged.
- [ ] **Step 4: Commit**

```bash
git add BabyTown/Game/PetRoomScene.swift
git commit -m "feat(theme): theme pet room ambient surfaces"
```

### Task F2: LoveGardenScene accents

**Files:**
- Modify: `BabyTown/Game/Garden/LoveGardenScene.swift` (line 299 `.blooming` `(0.93,0.45,0.62)`)

- [ ] **Step 1: Replace** line 299 → `BabyTownTheme.accentSK` (leave yellow flower centers 261/356 untouched — they are not pink).
- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Visual check** — open the love garden; blooming accents blue under Blue.
- [ ] **Step 4: Commit**

```bash
git add BabyTown/Game/Garden/LoveGardenScene.swift
git commit -m "feat(theme): theme love-garden blooming accent"
```

### Task F3: PetShopCatalog pink swatch

**Files:**
- Modify: `BabyTown/Models/PetShopCatalog.swift` (lines 1019/1021 `(1.0,0.93,0.95)`, 1028 `(0.92,0.30,0.45)`)

- [ ] **Step 1: Inspect** lines 1010-1035 to confirm these are accent UI tints (not a named product color like a specifically "pink bow" item the user buys). Run: `sed -n '1005,1035p' BabyTown/Models/PetShopCatalog.swift` equivalent via `Read`.
  - If they are **named product colors** (e.g. a literally-pink cosmetic item), LEAVE them — a pink bow should stay pink regardless of theme. Note the decision in the commit.
  - If they are **generic accent UI tints**, replace `(1.0,0.93,0.95)` → `UIColor(BabyTownTheme.cardTintLight)`, `(0.92,0.30,0.45)` → `BabyTownTheme.accentDeepUIColor`.
- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/PetShopCatalog.swift
git commit -m "feat(theme): theme pet shop accent tints (preserve named product colors)"
```

---

# PHASE G — Camera icon (both themes) + final verification

### Task G1: Force camera glyph white

**Files:**
- Modify: `BabyTown/Views/HomeView.swift:1816`

- [ ] **Step 1:** Change the camera icon foreground from the accent gradient to white:

```swift
                    Image(systemName: "camera.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
```
(The surrounding backdrop `Circle().fill(BabyTownTheme.accentIconBackdropGradient)`, stroke `BabyTownTheme.accent.opacity(0.25)`, and shadow `BabyTownTheme.buttonShadow` already flip via tokens from Phase A — no change needed there.)

- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Visual check** — camera button glyph is white in BOTH Pink and Blue.
- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/HomeView.swift
git commit -m "feat(theme): camera icon glyph always white"
```

### Task G2: Full visual sweep

- [ ] **Step 1: Pink fidelity pass** — fresh install (or reset, pick Pink). Walk: home (day + night via time or debug toggle), ToC, pet room, Visit Pet profile, love garden, compose letter, profile/editor sheets, paywall, map. Confirm every screen matches today. The only intended Pink change is the white camera glyph.

- [ ] **Step 2: Blue completeness pass** — reset, pick Blue. Walk the same screens. Confirm no residual pink/rose anywhere except the explicitly-preserved semantic reds (REC dots, notification badges, confetti) and any named product colors. Note any stray pink found and add a follow-up task to route that literal through a token.

- [ ] **Step 3: Persistence pass** — relaunch the app; confirm the chosen theme is retained. Reset app; confirm onboarding re-asks Pink/Blue.

- [ ] **Step 4: Final build** → `** BUILD SUCCEEDED **`.

---

## Self-review notes (spec coverage)

- Full app accent swap → Phases A (tokens) + C/D/E/F (inline sweep). ✅
- Onboarding step after nickname → Phase B. ✅
- Persistence + relaunch → A2/A3, G2.3. ✅
- Camera icon white for both → G1. ✅
- Night animation untouched → no task modifies `HomeBackgroundView` night branch; verified G2.1. ✅
- Pink pixel-identical → token pink branches use current literals; verified G2.1. ✅
- Semantic reds preserved → enumerated in Conventions; honored in D1/F1/F3. ✅

**Open judgment call flagged for the implementer:** PetShopCatalog (F3) and any "named pink product" — preserve literal pink for items a user deliberately bought as pink; only theme generic accent UI. Decide per inspection.
