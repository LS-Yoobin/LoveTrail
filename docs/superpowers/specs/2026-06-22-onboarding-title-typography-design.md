# Onboarding Title Typography — New York Display

**Date:** 2026-06-22
**Scope:** `StoryOnboardingFlow.swift` (SceneContentView), `WelcomeView.swift`

## Problem

The current onboarding scene titles use plain SF Pro Bold at 28pt — the same font weight and size used throughout the rest of the app's UI. For a screen that is meant to feel like a cinematic love story unfolding scene by scene, the titles read as generic labels rather than expressive moments.

## Decision

Switch to **New York Display** (Apple's built-in serif, accessed via `.design: .serif` on the system font) at a larger display size. Pair with a small tracked uppercase subtitle. This creates an editorial high-contrast pairing that signals "this is a scene, not a settings screen."

## Typography Spec

### Scene Titles (`SceneContentView` — all 5 story scenes)

| Property | Value |
|---|---|
| Font | `.system(size: 40, weight: .bold, design: .serif)` |
| Tracking | `-0.5` |
| Color | `StoryOnboardingTheme.textDark` |
| Alignment | `.center` |

### Scene Subtitles (`SceneContentView` — when `scene.subtitle` is present)

| Property | Value |
|---|---|
| Font | `.system(size: 11, weight: .semibold)` |
| Tracking | `2.5` |
| Text case | `.textCase(.uppercase)` |
| Color | `StoryOnboardingTheme.textDark.opacity(0.45)` |
| Alignment | `.center` |

### Welcome Screen Title (`WelcomeView`)

| Property | Value |
|---|---|
| Font | `.system(size: 38, weight: .bold, design: .serif)` |
| (No tracking change needed — single line) | |
| Color | `.primary` (unchanged) |

## Files to Change

| File | Change |
|---|---|
| `BabyTown/Views/StoryOnboardingFlow.swift` | Update title + subtitle modifiers in `SceneContentView` |
| `BabyTown/Views/WelcomeView.swift` | Bump title from 28pt to 38pt |

## Non-Goals

- No changes to body/story text, CTA buttons, or progress indicators
- No new font files — stays 100% on-device iOS fonts
- No changes to color tokens
