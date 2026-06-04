# Blue Color Theme — Design

**Date:** 2026-06-03
**Status:** Approved for planning

## Summary

Add a selectable **Blue** color theme alongside the existing look (now named
**Pink**). The user picks Pink or Blue during onboarding, immediately after
entering their nickname. The choice persists and applies on every launch.

**Scope: full app accent swap.** Under Blue, *everything* that is currently
pink/red becomes blue — backgrounds, cards, every button and gradient, hearts,
icons, the pet room and pet cards, editors, profile, letters, paywall, the lot.
Nothing pink remains. The goal is a genuine "Pink app vs. Blue app" choice so a
user who prefers blue is comfortable everywhere, not just on the home screen.

**Pink is unchanged** (pixel-identical to today) with one deliberate exception:
the home camera icon glyph becomes **white for both themes**.

The **night-mode background animation** (deep-blue gradient, star field, shooting
stars) is **not** part of the accent system and stays exactly as-is for both
themes.

## Strategy: two tiers

Pink today comes from two sources. Both must flip under Blue.

### Tier 1 — Theme tokens (high leverage, one file)
The app already centralizes design tokens in `BabyTownTheme.<token>`. Making
these ~10 tokens **theme-aware** flips the majority of the app by editing a
single file:

| Token | Pink uses | Notes |
|-------|-----------|-------|
| `accent` | 155 | primary pink |
| `accentDeep` | 55 | deep rose/red `(0.88,0.22,0.38)` |
| `accentGradient` | 45 | accent → accentDeep |
| `buttonShadow` | 24 | `pink.opacity(0.3)` |
| `buttonGradient` | 15 | accent → accent.opacity |
| `backgroundGradient` | 14 | home/app background (day) |
| `accentSoft` | 13 | `pink.opacity(0.08)` |
| `cardBackground` | 12 | rose card `(0.96,0.82,0.86)` |
| `accentIconGradient` | 5 | icon tint |
| `accentIconBackdropGradient` | 5 | icon backdrop |
| `blush` | 0 | unused, theme anyway for completeness |

`savePillFill` (already blue) is **left as-is** for both themes.

### Tier 2 — Inline literal sweep (the long tail)
Some pink bypasses the tokens as hard-coded literals and must be routed through
(new or existing) theme tokens, or it would stay pink under Blue:

- **`.pink` / `.red` literals:** 54 occurrences across 17 files (e.g.
  `NicknameView` background + continue button, floating-hearts overlays, story
  onboarding scenes).
- **Rosy `Color(red:…)` gradients:** hand-built rose fills, most notably
  `PetProfileCard` (`(1.0,0.97,0.94)→(0.99,0.90,0.93)`, panel fills, etc.) and
  similar pet/profile surfaces.

**Not swept (intentionally left):** night-background blues
(`(0.05,0.08,0.15)` …), neutral grays (`systemGray*`, search-bar gray
`(0.66,0.66,0.68)`), white, black, and `savePillFill`. The sweep targets only
pink/rose hues.

> Each distinct pink shade gets a named theme token (e.g. `accent`, `accentDeep`,
> `cardBackground`, and a small number of new ones for unique gradients like the
> pet-profile rose). Inline literals are then replaced by the matching token so
> they flip with the theme. Where a literal is a one-off shade, add a
> purpose-named token rather than reusing an approximate one.

## The camera icon (both themes)
`camera.fill` in `HomeView.cameraButton` is currently a pink gradient; it becomes
**white** for both Pink and Blue. This is the one intentional change to Pink.

## Blue palette

Blue counterparts for each pink token/shade. "Standard blue" anchors on the
existing `savePillFill` `Color(red:0.22,green:0.48,blue:0.96)` for consistency
with blue already in the app.

| Pink shade | Blue counterpart |
|-----------|------------------|
| `accent` (pink) | `Color(red:0.22,0.48,0.96)` (standard blue) |
| `accentDeep` `(0.88,0.22,0.38)` | a deeper blue, e.g. `(0.14,0.34,0.78)` |
| `cardBackground` `(0.96,0.82,0.86)` | baby-blue `(0.80,0.88,0.96)` |
| Home day background | white → soft light-blue `(0.88,0.94,0.99)` |
| `accentSoft` / `blush` opacities | same opacities over blue |
| Pet-profile rose gradient | parallel light-blue gradient |

Gradients (`accentGradient`, `buttonGradient`, icon gradients, shadows) are
derived from the blue `accent`/`accentDeep` exactly as the pink ones are derived
today, so their structure is unchanged — only the base hues differ.

> Exact blue values are tunable during implementation; the table above is the
> starting point. Pink token values are the current literals verbatim, so Pink
> renders identically.

## Architecture

### Components

1. **`ColorTheme` enum** — `{ case pink, blue }`, `String` raw value, default
   `.pink`.

2. **`DataPersistenceManager`** — `saveColorTheme(_:)` / `loadColorTheme()`
   backed by `UserDefaults`; returns `.pink` when unset.

3. **`ThemeManager: ObservableObject`** (singleton, `ThemeManager.shared`) —
   `@Published var theme: ColorTheme`, initialized from
   `DataPersistenceManager`. `setTheme(_:)` updates the published value and
   persists. The onboarding picker calls `setTheme`; `BabyTownTheme` tokens read
   `ThemeManager.shared.theme`.

4. **`BabyTownTheme` becomes theme-aware** — each pink-bearing token changes from
   a stored `let` to a computed `static var` that branches on
   `ThemeManager.shared.theme`, returning the Pink literal or the Blue
   counterpart. Pink branch = today's exact values. A few new tokens are added
   for inline shades that lacked a token (e.g. pet-profile rose gradient).

5. **`ColorThemeView`** (onboarding step) — "What color theme do you prefer?
   Pink or Blue?" Two tappable options styled to match existing onboarding
   screens (`NicknameView` idiom), ideally previewing each theme's color. On
   selection: `ThemeManager.shared.setTheme(...)`, then advance.

6. **`ContentView` flow** — add a `.colorTheme` screen case inserted **after
   `.nickname`, before `.firstMemories`**. `NicknameView` continue → `.colorTheme`;
   `ColorThemeView` selection → `.firstMemories`.

### Reactivity note
Theme is chosen once during onboarding (before the themed screens appear) and
loaded from persistence at launch, so static computed token reads always return
the correct value — no live mid-session re-theming is required. Observing
`ThemeManager` from host views is optional and only matters if a post-onboarding
settings toggle is added later (out of scope).

## Data flow

```
Onboarding: NicknameView → ColorThemeView
                               │ setTheme(.blue)
                               ▼
                        ThemeManager.shared ──persist──▶ DataPersistenceManager (UserDefaults)
                               │ theme
                               ▼
   BabyTownTheme.<token> reads ThemeManager.shared.theme  →  whole app renders Blue
```

## Edge cases & notes

- **Default / existing users:** unset → `.pink` → no change.
- **Reset app:** `onResetApp` returns to onboarding; theme is re-asked.
- **Pink fidelity:** Pink branch returns current literals verbatim → Pink stays
  pixel-identical (except the white camera icon).
- **Night animation:** untouched for both themes.

## Out of scope (explicitly)

- A settings screen to change the theme after onboarding.
- Theming the night-background animation, neutral grays, or `savePillFill`.

## Testing / verification

- Onboarding routes Nickname → ColorTheme → FirstMemories; both options persist
  and advance; relaunch preserves choice.
- **Pink:** home, pet room, pet cards, editors, profile, letters render
  identically to today, except the camera icon is white.
- **Blue:** the same surfaces show no remaining pink — explicitly verify the
  inline-literal hotspots (NicknameView, FloatingHeartsOverlay, story scenes,
  PetProfileCard, pet market/rename, paywall).
- Night mode: cards/buttons recolor per theme; background animation unchanged.
- Because the swap is app-wide, verification is visual across major screens (see
  the simulator-routing technique in project memory) in addition to building.
