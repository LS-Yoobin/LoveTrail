# Onboarding Path Selector + Prelude Intro Design

## Context

Covela currently routes all new users through a single onboarding flow ending at the couple home screen. There is no moment where the user declares whether they are in a Prelude (someone special, not yet official) or Already Official. Users who land in Prelude also have no way to access settings or return to onboarding from the Prelude home screen.

---

## What We Are Building

Three additions to the onboarding system:

1. **PathSelectorView** — a new screen inserted after the Birthday step, letting users choose their relationship context before the flow branches.
2. **PreludeOnboardingView** — a new screen that explains the Prelude concept (shown only to users who choose the Prelude path), before they land in PreludeHomeView.
3. **Settings icon on PreludeHomeView** — a top-left gear icon that surfaces a settings sheet, with an option to return to onboarding.

---

## Revised Onboarding Flow

```
Welcome → Nickname → ColorTheme → Birthday → PathSelectorView
                                                  │
                          ┌───────────────────────┴────────────────────────┐
                     "Prelude"                                    "Already Official"
                          │                                                 │
                  PreludeOnboardingView                          FirstMemoriesView
                          │                                                 │
              (set stage = .prelude,                              HowItWorksView
               complete onboarding)                                         │
                          │                                        PhotoAccessView
                   PreludeHomeView                                          │
                                                                        HomeView
```

---

## Screen 1 — PathSelectorView

A clean, centered screen that presents two tappable cards. Shown immediately after the Birthday step.

**Header copy:**
- Title: "Where are you right now?"
- Subtitle: "We will set things up just right for you."

**Card A — Prelude**
- Icon: a small envelope-heart or sparkle
- Label: "Prelude"
- Description: "There is someone special on your mind. Not official yet."

**Card B — Already Official**
- Icon: a pair of hearts or interlinked circles
- Label: "Already Official"
- Description: "You are in a relationship and ready to build your shared space."

Styling follows the active color theme (BabyTownTheme.accent). Cards use the same rounded rect + shadow pattern as the rest of onboarding. No back button needed on the first version (Birthday → PathSelector is a forward-only step).

---

## Screen 2 — PreludeOnboardingView

A single-scroll screen that introduces the Prelude concept. Shown after the user taps "Prelude" on PathSelectorView. Respects the active color theme.

**Structure (top to bottom):**

### Hero section
- Background: soft pink gradient (BabyTownTheme.accent at low opacity, fading to white)
- Large emoji or icon: 💌
- Title (serif, bold): "Your space to fall in love, quietly."
- Subtitle: "Capture every feeling before you are official."

### Feature rows (four items)

| Icon | Title | Subtext |
|---|---|---|
| 📝 | Notes & Reflections | Write how you feel whenever it hits you. Even the small stuff. |
| ⭐ | Firsts | Every first has a story. Do not let a single one slip away. |
| 🎙️ | Voice Memos | Speak your mind in the moment. Raw, real, and unfiltered. |
| 💗 | Reasons | The little things you love about them, in your own words. |

### Gift section (visually distinct)
- Dark plum gradient background (approximately #4a1942 → #8b3d5c)
- Icon: 🎁
- Title: "When you are ready, send them a gift."
- Body: "Package your captured moments into a scrapbook. When they join, they will see exactly how you felt before you were ever official."

### CTA button
- Label: "Begin my Prelude"
- Full-width capsule, BabyTownTheme.accentGradient fill, white text
- Tapping this: sets onboarding completed, sets relationshipStage to .prelude, navigates to PreludeHomeView

**No dashes** in any copy on this screen (or anywhere in the app).

---

## Screen 3 — Settings icon on PreludeHomeView

A gear icon (SF Symbol: `gearshape`) placed at the top-left of PreludeHomeView, visible at all times.

Tapping it presents a sheet (`PreludeSettingsSheet`) with the following options:

- **Return to Onboarding** — clears onboarding completion flag and navigates back to Welcome (triggers a full ContentView screen reset via a notification or callback)
- **Color Theme** — opens ColorThemeView inline (or as a sheet) so users can change their theme from within Prelude

The sheet uses the same card/rounded rect styling as the rest of the app.

### ContentView wiring

PreludeHomeView needs an `onReturnToOnboarding` callback passed from ContentView (similar to `onResetApp` on HomeView). This callback clears onboarding state and sets `screen = .welcome`.

---

## Copy Rules

- No dash characters (hyphen, en-dash, em-dash) anywhere in user-facing strings.
- All UI text uses sentence case.
- Subtext is concise: one to two short sentences maximum per feature row.

---

## Files Affected

| File | Change |
|---|---|
| `ContentView.swift` | Add `.pathSelector` and `.preludeOnboarding` cases to Screen enum; wire navigation callbacks |
| `Views/PathSelectorView.swift` | New file |
| `Views/Prelude/PreludeOnboardingView.swift` | New file |
| `Views/Prelude/PreludeHomeView.swift` | Add settings icon + sheet; accept onReturnToOnboarding callback |
| `Views/Prelude/PreludeSettingsSheet.swift` | New file |
