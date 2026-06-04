# Blue Color Theme — Design

**Date:** 2026-06-03
**Status:** Approved for planning

## Summary

Add a selectable **Blue** color theme alongside the existing look (now named
**Pink**). The user picks Pink or Blue during onboarding, immediately after
entering their nickname. Pink is the current app appearance and is unchanged
(with one deliberate exception: the camera icon — see below). Blue recolors a
small, explicit set of home-page surfaces.

This is intentionally **narrow in scope**: only the surfaces listed below
change. The rest of the app's pink/red accents (CTA buttons, hearts, pet room,
editors, profile, letters, paywall, etc.) stay pink for both themes.

## Surfaces that change under Blue

| # | Surface | Pink (current) | Blue | Location |
|---|---------|----------------|------|----------|
| 1 | Home **day** background | ≈white gradient | soft light-blue gradient | `HomeBackgroundView.swift` (day branch) |
| 2 | Home **memory cards** (day & night) | rose `(0.96,0.82,0.86)` | baby-blue `(0.80,0.88,0.96)` | 7 home-feed card components |
| 3 | **ToC launcher** circle (book icon button) | `accentGradient`, white icon | standard-blue gradient, white icon | `HomeView.swift` header row |
| 4 | **ToC screen** month/season titles | pink accent | standard blue | `TableOfContentsView.swift` |
| 5 | **Camera** button backdrop/stroke/shadow | pink | standard blue | `HomeView.swift` `cameraButton` |
| 6 | **Up-arrow** scroll-to-top button | `accentGradient` | standard-blue gradient | `HomeView.swift` `upButton` |

### Camera icon — applies to BOTH themes
The camera glyph (`camera.fill`) is currently a pink gradient. It becomes
**white for both Pink and Blue**. This is the one deliberate change to the Pink
appearance.

### Night mode is preserved
The animated night background (deep-blue gradient, star field, shooting stars in
`HomeBackgroundView` night branch) is **untouched** for both themes. Only the
memory cards and the circular buttons recolor at night — the card fill does not
branch on night today, so making the card token theme-aware naturally covers
night mode without touching the animation.

### Standard blue
"Standard blue" reuses the theme's existing `savePillFill`
`Color(red: 0.22, green: 0.48, blue: 0.96)` so the new accent is consistent with
the blue already used for Save pills.

## Blue palette values

| Token | Blue value |
|-------|-----------|
| Home day background gradient | `[white, Color(red:0.88,green:0.94,blue:0.99)]` |
| Memory card background | `Color(red:0.80,green:0.88,blue:0.96)` (darker than the bg) |
| Accent / standard blue | `savePillFill` = `Color(red:0.22,green:0.48,blue:0.96)` |
| Icon-circle gradient (ToC launcher, up button) | `[savePillFill, savePillFill.opacity(0.82)]` |
| Icon-circle shadow | `savePillFill.opacity(0.3)` |
| Camera backdrop gradient | `[savePillFill.opacity(0.15), savePillFill.opacity(0.08)]` |
| Camera stroke | `savePillFill.opacity(0.25)` |
| Camera shadow | `savePillFill.opacity(0.3)` |

Pink palette tokens return the exact current values (no visual change for Pink
apart from the camera icon).

## Architecture

The app already uses `BabyTownTheme.<token>` as a global design-token namespace
(250+ call sites). We keep that namespace and make the relevant tokens
**theme-aware** rather than introducing a parallel system. This minimizes
call-site churn for a 4–6 surface change.

Rejected alternatives:
- **EnvironmentObject palette injection** — more idiomatic SwiftUI, but threads a
  palette through ~10 files (including 7 card components) for a narrow change.
- **Parameter passing** — most explicit, most churn. Same objection, worse.

### Components

1. **`ColorTheme` enum** — `{ case pink, blue }`, `String` raw value, default
   `.pink`.

2. **`DataPersistenceManager`** — `saveColorTheme(_:)` / `loadColorTheme()`
   backed by `UserDefaults`; returns `.pink` when unset.

3. **`ThemeManager: ObservableObject`** (singleton) — `@Published var theme:
   ColorTheme`, initialized from `DataPersistenceManager`. `setTheme(_:)` updates
   the published value and persists. Views that should react (e.g. `HomeView`)
   observe it; the onboarding picker calls `setTheme`.

4. **Theme-aware tokens on `BabyTownTheme`** — new computed statics that read
   `ThemeManager.shared.theme` and branch Pink/Blue:
   - `homeDayBackgroundGradient`
   - `memoryCardBackground` *(new token — see note below)*
   - `themedAccent` (ToC month/season titles)
   - `iconCircleGradient`, `iconCircleShadow` (ToC launcher + up button)
   - `cameraBackdropGradient`, `cameraStroke`, `cameraShadow`

   > **Card token note:** the existing static `cardBackground` is shared by
   > home-feed cards **and** non-home surfaces (pet market, pet rename, invite
   > paywall). To keep scope tight, we introduce a separate `memoryCardBackground`
   > token and migrate only the **7 home-feed card components** to it. The other
   > `cardBackground` users keep the pink value for both themes.
   >
   > Home-feed components to migrate: `DayClusterCard`, `PinnedMemoryCard`,
   > `PinnedPromptMemoryCard`, `SpecialDateMemoryCard` (two fills),
   > `FoundingPlaceholderCard`, `PromptMemoryCard`, `PromptDisplayCard`.

5. **`ColorThemeView`** (onboarding step) — "What color theme do you prefer?
   Pink or Blue?" Two tappable options styled to match existing onboarding
   screens (`NicknameView` idiom). On selection: `ThemeManager.shared.setTheme`,
   then advance.

6. **`ContentView` flow** — add a `.colorTheme` screen case inserted **after
   `.nickname`, before `.firstMemories`**. `NicknameView`'s continue handler
   routes to `.colorTheme`; `ColorThemeView`'s handler routes to
   `.firstMemories`.

## Data flow

```
Onboarding: NicknameView → ColorThemeView
                               │ setTheme(.blue)
                               ▼
                        ThemeManager.shared  ──persist──▶ DataPersistenceManager (UserDefaults)
                               │ @Published
                               ▼
   BabyTownTheme.<themed token> reads ThemeManager.shared.theme
                               │
                               ▼
   HomeBackgroundView / home cards / ToC / camera / up button render Blue
```

On subsequent launches, `ThemeManager` loads the persisted theme at init, so the
home screen renders in the chosen theme without re-asking.

## Edge cases & notes

- **Default / pre-existing users:** unset theme → `.pink` → no change. Existing
  users keep today's appearance.
- **Reset app:** `onResetApp` clears data and returns to onboarding; theme
  selection is re-asked. (Confirm `clearAllData` clears or leaves the theme key —
  either is acceptable since onboarding re-sets it.)
- **Reactivity:** theme is fixed after onboarding, so non-reactive reads would
  also work; observing `ThemeManager` keeps it correct if a settings toggle is
  added later (out of scope now).

## Out of scope (explicitly)

- Recoloring any pink/red accent outside the 6 surfaces above.
- A settings screen to change the theme after onboarding.
- Theming the night background animation.

## Testing

- Onboarding routes Nickname → ColorTheme → FirstMemories; both options persist
  and advance.
- Pink selection produces pixel-identical home to today, except the camera icon
  is white.
- Blue selection recolors exactly the 6 surfaces, day and night, with the night
  animation unchanged.
- Relaunch preserves the chosen theme.
- Non-home `cardBackground` surfaces (pet market, paywall, rename) stay pink
  under Blue.
