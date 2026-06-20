# Covela Design System

This document is the single source of truth for visual design and UI patterns in Covela. Read it before touching any UI. It covers color, typography, spacing, components, and the rules that keep the app feeling consistent.

---

## 1. Color Themes

The app ships with two selectable themes. `BabyTownTheme` is the token layer all UI code should read from. Never hardcode hex values that belong to a theme.

### Pink (default)
Warm, blush-toned. The original look.

### Blue
Calm sky, cool mornings.

Users switch themes in Settings. The selection persists via `ThemeManager.shared` / `UserDefaults` key `"colorTheme"`. Observe `ThemeManager.shared` in views that need to react to live changes.

---

## 2. Design Tokens — `BabyTownTheme`

Always use these tokens. Never reach past them to raw `Color(red:green:blue:)` unless you are defining a new token inside `BabyTownTheme.swift`.

### Backgrounds

| Property | Pink | Blue | Notes |
|---|---|---|---|
| `BabyTownTheme.background` | `Color.white` | `Color.white` | Base page background |
| `BabyTownTheme.backgroundGradient` | white → white | white → light blue | Applied to the home scroll surface |
| `BabyTownTheme.blush` | `pink.opacity(0.15)` | `blue.opacity(0.15)` | Subtle tint surfaces |
| `BabyTownTheme.blushSoft` | warm blush `(1.0, 0.92, 0.94)` | cool sky `(0.92, 0.95, 1.0)` | Very light fills |

### Accents

| Property | Pink | Blue |
|---|---|---|
| `BabyTownTheme.accent` | `Color.pink` | `(0.22, 0.48, 0.96)` |
| `BabyTownTheme.accentDeep` | `(0.88, 0.22, 0.38)` | `(0.14, 0.34, 0.78)` |
| `BabyTownTheme.accentSoft` | `accent.opacity(0.08)` | same |
| `BabyTownTheme.accentMuted` | salmon `(0.93, 0.55, 0.52)` | muted blue `(0.52, 0.68, 0.90)` |
| `BabyTownTheme.accentGradient` | accent → accentDeep, leading → trailing | same |
| `BabyTownTheme.accentIconGradient` | accent → accentDeep, topLeading → bottomTrailing | same |
| `BabyTownTheme.accentIconBackdropGradient` | accent/0.15 → accentDeep/0.08 | same |

### Text

| Property | Value | Usage |
|---|---|---|
| `BabyTownTheme.textPrimary` | `Color(.darkGray)` | Body, card titles |
| `BabyTownTheme.textSecondary` | `Color(.secondaryLabel)` | Metadata, dates |
| `BabyTownTheme.textTertiary` | `Color(.tertiaryLabel)` | Place names, low-emphasis |

### Cards

| Property | Pink | Blue |
|---|---|---|
| `BabyTownTheme.cardBackground` | `(0.96, 0.82, 0.86)` | `(0.80, 0.88, 0.96)` |
| `BabyTownTheme.cardShadow` | `black.opacity(0.05)` | same |
| `BabyTownTheme.cardRadius` | `18` pt | same |
| `BabyTownTheme.cardTintLight` | `(1.0, 0.97, 0.94)` | `(0.96, 0.98, 1.0)` |
| `BabyTownTheme.cardTintDeep` | `(0.99, 0.90, 0.93)` | `(0.86, 0.92, 0.99)` |

### Buttons

| Property | Value |
|---|---|
| `BabyTownTheme.buttonGradient` | `accent → accent.opacity(0.82)`, leading → trailing |
| `BabyTownTheme.buttonShadow` | `accent.opacity(0.3)` |
| `BabyTownTheme.savePillFill` | `(0.22, 0.48, 0.96)` — always blue, theme-independent |
| `BabyTownTheme.savePillShadow` | `savePillFill.opacity(0.35)` |

### Pet Room (SpriteKit)

Use `BabyTownTheme.roomWallTopSK`, `roomWallBottomSK`, `roomFloorSK`, `accentSK`, `accentDeepSK` when touching SpriteKit code. Never convert UIColor manually.

### Search Bar (day mode)

Fixed palette — does not flip dark because the home search bar sits on a colored surface.

| Property | Value |
|---|---|
| `BabyTownTheme.daySearchBarFill` | `(0.66, 0.66, 0.68)` |
| `BabyTownTheme.daySearchBarText` | `Color.white` |
| `BabyTownTheme.daySearchBarPlaceholder` | `white.opacity(0.72)` |
| `BabyTownTheme.daySearchBarIcon` | `white.opacity(0.85)` |

---

## 3. Onboarding Theme — `StoryOnboardingTheme`

Story onboarding uses its own sub-palette (a thin wrapper around `BabyTownTheme`). Use these tokens only inside onboarding components.

| Property | Pink | Blue |
|---|---|---|
| `backgroundBlush` | `(1.0, 0.95, 0.95)` | `(0.95, 0.97, 1.0)` |
| `primaryRed` | `BabyTownTheme.accentDeep` | same |
| `accentPink` | `(1.0, 0.7, 0.75)` | `(0.62, 0.78, 1.0)` |
| `textDark` | `(0.2, 0.15, 0.15)` | same |
| `cornerRadius` | `20` pt | same |
| `shadowRadius` | `8` pt | same |
| `spacing` | `24` pt | same |

---

## 4. Typography

All type is set with `.system(size:weight:)`. No custom fonts are imported.

| Role | Size | Weight | Notes |
|---|---|---|---|
| Card title / date label | 14 | `.semibold` | DayClusterCard header |
| Section header | 17 | `.bold` | CoupleSpaceCard "Us" title |
| Body / caption | 12 | `.regular` | Memory captions, place names |
| Subtext / badge | 10–11 | `.medium` | Prompt pills, pinned badge |
| Pill label | 14 | `.semibold` | StickyActionBar pills |
| Settings list row | 16 | `.regular` | SettingsSheet list items |
| CTA button | 18 | `.semibold` | PrimaryCTAButton |
| Navigation title | system default | `.semibold` (toolbar Done) | NavigationStack title is `.inline` |
| Onboarding back | 28 | `.light` | OnboardingBackButton `"<"` |

**Rules:**
- Use `.lineLimit(1)` or `.lineLimit(2)` on cards to prevent layout blowout.
- Never set a fixed font size below 10 pt.
- Metadata and secondary text use `foregroundStyle(.secondary)` or `BabyTownTheme.textSecondary`, not arbitrary opacities.

---

## 5. Spacing and Layout

| Constant | Value | Where used |
|---|---|---|
| `StoryOnboardingTheme.spacing` | 24 pt | Onboarding vertical gaps |
| Card internal padding | 12 pt | `DayClusterCard` |
| Card corner radius | 18 pt (`BabyTownTheme.cardRadius`) | All memory cards |
| Photo corner radius (inside card) | 12 pt | Collage clipping |
| Photo gap (collage) | 3 pt | Between photos in a cluster |
| Home horizontal padding | 20 pt | StickyActionBar, CoupleSpaceCard |
| Action bar vertical padding | 10 pt | StickyActionBar scroll wrapper |
| Pill horizontal padding | 20 pt | Action bar pills |
| Pill vertical padding | 11 pt | Action bar pills |
| Standard touch target | 44 × 44 pt | All tappable icon buttons |
| Header height | 56 pt | BabyTownHeader |

---

## 6. Backgrounds

### Home — Day Mode
`BabyTownTheme.backgroundGradient` applied via `HomeBackgroundView`. White base for both themes; the blue theme adds a subtle light-blue fade at the bottom.

### Home — Night Mode
Deep blue gradient: `(0.05, 0.08, 0.15)` top → `(0.10, 0.15, 0.25)` bottom, with `StarFieldView` and `ShootingStarView` overlaid. Night mode is driven by `NightModeManager`.

Toggle between modes with `.transition(.opacity)` and `withAnimation(.easeInOut)`.

---

## 7. Components

### BabyTownHeader
Top navigation bar. 56 pt tall. Contains optional settings gear, map, and envelope icons at 18 pt. Touch targets are 44 × 44 pt. In night mode icons become `white.opacity(0.9)`; in day mode `BabyTownTheme.textPrimary.opacity(0.6)`.

File: [BabyTown/Components/BabyTownHeader.swift](BabyTown/Components/BabyTownHeader.swift)

### StickyActionBar
Horizontally scrolling pill row at the bottom of the home content area.

- **Primary pill** (Select Photos): filled with `BabyTownTheme.accentGradient`, white label, capsule shape, shadow with `BabyTownTheme.buttonShadow`.
- **Secondary pill** (Scan, Prompt): outlined with a 1.5 pt `BabyTownTheme.accent` stroke; accent-colored label.
- **Camera icon button**: circle with `BabyTownTheme.accentSoft` fill; icon uses `BabyTownTheme.accentIconGradient`.
- All pill labels: `.system(size: 14, weight: .semibold)`, icon at 14 pt inside a fixed 14 × 14 pt frame.

File: [BabyTown/Components/StickyActionBar.swift](BabyTown/Components/StickyActionBar.swift)

### PrimaryCTAButton
Full-width button for onboarding CTAs.
- Height: fills `.padding(.vertical, 18)` on the label.
- Enabled: `StoryOnboardingTheme.primaryRed` fill, same-color shadow `opacity(0.3)`, radius 8, y offset 4.
- Disabled: `Color.gray.opacity(0.3)`, no shadow.
- Corner radius: `StoryOnboardingTheme.cornerRadius` (20 pt).
- Animate state changes with `.animation(.easeInOut(duration: 0.3))`.

File: [BabyTown/Components/PrimaryCTAButton.swift](BabyTown/Components/PrimaryCTAButton.swift)

### CircleBackdropCloseButton
Circular dark dismiss button for full-screen overlays.
- Default circle: 36 pt, `black.opacity(0.55)`.
- Icon: `xmark.circle.fill` at 30 pt, `.hierarchical` rendering, `white.opacity(0.95)`.
- Use `.buttonStyle(.plain)`.

File: [BabyTown/Components/CircleBackdropCloseButton.swift](BabyTown/Components/CircleBackdropCloseButton.swift)

### OnboardingBackButton
Plain `"<"` back affordance for the story onboarding shell.
- Font: `.system(size: 28, weight: .light)`, black.
- Touch target: 44 × 44 pt, left-aligned.
- Apply via the `.onboardingBackButton(action:)` view modifier to overlay it at `topLeading`.

File: [BabyTown/Components/OnboardingBackButton.swift](BabyTown/Components/OnboardingBackButton.swift)

### YearFilterChip
Filter chip for the timeline year selector.
- Selected: `BabyTownTheme.accentGradient` fill, white label, `.semibold`, 20 pt corner radius.
- Unselected: `Color(white: 0.88)` fill, black label, `.regular`.
- Padding: 20 pt horizontal, 10 pt vertical.

File: [BabyTown/Components/YearFilterChip.swift](BabyTown/Components/YearFilterChip.swift)

### HeartProgressIndicator
Five-heart step tracker used during story onboarding.
- Empty hearts: `StoryOnboardingTheme.accentPink.opacity(0.4)`.
- Filled hearts: `StoryOnboardingTheme.primaryRed`.
- Current step scales to `1.2` with `.spring(response: 0.3, dampingFraction: 0.6)`.
- Heart spacing: 12 pt.

File: [BabyTown/Components/HeartProgressIndicator.swift](BabyTown/Components/HeartProgressIndicator.swift)

### DayClusterCard
The main memory card in the home timeline.
- Background: `BabyTownTheme.cardBackground.opacity(0.75)`, corner radius `BabyTownTheme.cardRadius`.
- Shadow: `black.opacity(0.15)`, radius 12, y 6.
- Internal padding: 12 pt all sides.
- Collage layouts: 1 photo full-width 190 pt tall; 2 side-by-side 140 pt; 3 hero + two 120 + 85 pt; 4+ two balanced rows at 95 pt each. Photo gap: 3 pt. Clip radius: 12 pt.
- Caption empty state: accent-tinted rounded rect (8 pt radius) with accent stroke at `opacity(0.3)`.
- Prompt pill: `accent.opacity(0.1)` fill, accent text, capsule. Founding memories use green fill with white text.
- Cat decoration: `cat_variant_N` image, `(index % 5) + 1`, 110 × 110 pt, bottom-trailing alignment within the collage.
- Appear transition: `.scale(scale: 0.96).combined(with: .opacity)`.

File: [BabyTown/Components/DayClusterCard.swift](BabyTown/Components/DayClusterCard.swift)

### PinnedMemoryCard
Used for pinned memories at the top of the home feed (horizontal scroll row).
- Same card radius and background as `DayClusterCard`.
- Photo area: 150 pt tall, `cornerRadius: 14`.
- Slideshow: auto-advances every 8 s with `.easeInOut(duration: 0.35)`.
- Overlay menu button: 28 pt circle, `black.opacity(0.6)` fill, white `ellipsis` icon.
- Locked state: `black.opacity(0.4)` overlay + `lock.fill` icon.

File: [BabyTown/Components/PinnedMemoryCard.swift](BabyTown/Components/PinnedMemoryCard.swift)

### CoupleSpaceCard
Compact home-feed entry for the couple space.
- Background: `.ultraThinMaterial`, corner radius 18, white stroke at `opacity(0.5)` / 1 pt.
- Garden glyph: 50 × 50 pt, corner radius 14. Fallback gradient: sky blue `(0.78, 0.90, 0.98)` → green `(0.66, 0.80, 0.55)`.
- Avatar stack: 40 pt circles with 2 pt white ring; partner revealed at 45% (staggered overlap).
- Partner placeholder: `.ultraThinMaterial` circle + dashed border + `heart.circle` icon.

File: [BabyTown/Components/CoupleSpaceCard.swift](BabyTown/Components/CoupleSpaceCard.swift)

### BabyTownLogoView
Three trailing hearts (sizing down + blurring) + one sharp main heart, all in `BabyTownTheme.accentIconGradient`. Circle backdrop with `accent.opacity(0.10 → 0.18)` gradient.

File: [BabyTown/Components/BabyTownLogoView.swift](BabyTown/Components/BabyTownLogoView.swift)

---

## 8. Animation Patterns

| Situation | Pattern |
|---|---|
| Day / night mode transition | `.transition(.opacity)` on all background layers |
| Card appear | `.scale(scale: 0.96).combined(with: .opacity)` |
| Heart progress step | `.spring(response: 0.3, dampingFraction: 0.6)` |
| Button enabled state | `.easeInOut(duration: 0.3)` |
| Pinned photo slideshow | `.easeInOut(duration: 0.35)`, timer every 8 s |
| Pet trick progress alert | Spring or built-in implicit animations (see `PetTrickProgressAlertView`) |
| Map pull reveal | `peakPullOffset` driving a custom pull layer; haptic on threshold cross |
| Floating hearts | `FloatingHeartsOverlay` / `FloatingHeartsView` (continuous) |

Prefer SwiftUI implicit animation over explicit `withAnimation` unless you need precise control over when the animation starts.

---

## 9. Text Content Rules

- No dash characters (`-`) in any user-visible string. Use commas, line breaks, or reword instead.
- Tone: warm, personal, playful but not childish.
- Use sentence case for all labels (not Title Case for multi-word phrases).
- CTA labels are imperative: "Select Photos", "Save our memories", "Enter Covela".

---

## 10. Locked Content

When content is locked (time-gated):
- Blur the image: `.blur(radius: 20)`.
- Overlay `black.opacity(0.4)`.
- Show `lock.fill` at 16–20 pt in white.
- Optionally show `TimeUntilUnlockView` below the icon.

---

## 11. Settings Sheet Conventions

Settings UI uses a standard SwiftUI `List` inside a `NavigationStack` with `.navigationBarTitleDisplayMode(.inline)`. Bottom inset uses `.safeAreaInset` with `.ultraThinMaterial` background. A `ToolbarItem(.confirmationAction)` "Done" button dismisses the sheet.

File: [BabyTown/Components/SettingsSheet.swift](BabyTown/Components/SettingsSheet.swift)

---

## 12. File Conventions

| Concern | Location |
|---|---|
| Design tokens | `BabyTown/Theme/BabyTownTheme.swift` |
| Color theme enum | `BabyTown/Theme/ColorTheme.swift` |
| Onboarding sub-palette | `BabyTown/Components/StoryOnboardingTheme.swift` |
| Reusable components | `BabyTown/Components/` |
| Screen-level views | `BabyTown/Views/` |
| Game / SpriteKit | `BabyTown/Game/` |
| Onboarding design doc | `DesignOnboardingstoryboard.md` |

New shared UI pieces go in `Components/`, named after what they are, not where they appear (e.g. `PrimaryCTAButton`, not `OnboardingNextButton`).

---

## 13. What to Check Before Adding New UI

1. Is there already a token in `BabyTownTheme` for this color? If yes, use it. If no, add one there.
2. Does a component already do this? Check `BabyTown/Components/` before building a new one.
3. Does it work in both Pink and Blue themes? Run the SwiftUI preview with `ThemeManager.shared.setTheme(.blue)`.
4. Does it work in both day and night modes where relevant?
5. Are all user-visible strings dash-free?
6. Are touch targets at least 44 × 44 pt?
