# Covela — Design System

## Color System

Always use `BabyTownTheme.*` properties. Never hardcode color values. Both themes must always be supported.

### Pink Theme (default)
*"Warm blush and soft evenings"*

| Token | Swift property | Approximate value |
|---|---|---|
| Accent | `BabyTownTheme.accent` | `Color.pink` |
| Accent Deep | `BabyTownTheme.accentDeep` | `rgb(0.88, 0.22, 0.38)` |
| Card Background | `BabyTownTheme.cardBackground` | `rgb(0.96, 0.82, 0.86)` |
| Card Tint Light | `BabyTownTheme.cardTintLight` | `rgb(1.0, 0.97, 0.94)` |
| Card Tint Deep | `BabyTownTheme.cardTintDeep` | `rgb(0.99, 0.90, 0.93)` |
| Blush Soft | `BabyTownTheme.blushSoft` | `rgb(1.0, 0.92, 0.94)` |
| Background | `BabyTownTheme.background` | `Color.white` |

### Blue Theme
*"Calm sky and quiet mornings"*

| Token | Swift property | Approximate value |
|---|---|---|
| Accent | `BabyTownTheme.accent` | `rgb(0.22, 0.48, 0.96)` |
| Accent Deep | `BabyTownTheme.accentDeep` | `rgb(0.14, 0.34, 0.78)` |
| Card Background | `BabyTownTheme.cardBackground` | `rgb(0.80, 0.88, 0.96)` |
| Card Tint Light | `BabyTownTheme.cardTintLight` | `rgb(0.96, 0.98, 1.0)` |
| Card Tint Deep | `BabyTownTheme.cardTintDeep` | `rgb(0.86, 0.92, 0.99)` |
| Blush Soft | `BabyTownTheme.blushSoft` | `rgb(0.92, 0.95, 1.0)` |
| Background | `BabyTownTheme.background` | White with soft blue gradient to bottom |

### Note Editor Colors (theme-dependent)

These tokens power the note-capture sheet. Both themes must always be supported.

| Token | Swift property | Pink value | Blue value |
|---|---|---|---|
| Editor background | `BabyTownTheme.noteEditorBackground` | `rgb(0.94, 0.90, 0.85)` warm linen | `rgb(0.88, 0.92, 0.97)` cool sky |
| Prompt chip fill | `BabyTownTheme.notePromptFill` | `rgb(0.529, 0.424, 0.318)` warm mocha | `rgb(0.35, 0.45, 0.62)` steel blue |
| Text area fill | `BabyTownTheme.noteTextAreaFill` | `rgb(0.863, 0.816, 0.765)` warm sand | `rgb(0.80, 0.86, 0.94)` cool mist |
| Tape decoration | `BabyTownTheme.notePromptTapeFill` | `rgb(0.86, 0.80, 0.72)` at 90% (fixed, theme-neutral) | same |

### Fixed Colors (not theme-dependent)

| Purpose | Token | Value |
|---|---|---|
| Save pill / confirm actions | `BabyTownTheme.savePillFill` | `rgb(0.22, 0.48, 0.96)` |
| Save pill shadow | `BabyTownTheme.savePillShadow` | savePillFill at 35% opacity |
| Text primary | `BabyTownTheme.textPrimary` | `Color(.darkGray)` |
| Text secondary | `BabyTownTheme.textSecondary` | `Color(.secondaryLabel)` |
| Text tertiary | `BabyTownTheme.textTertiary` | `Color(.tertiaryLabel)` |
| Card shadow | `BabyTownTheme.cardShadow` | `Color.black.opacity(0.05)` |

## Typography
- **Emotional / headline moments:** serif font
- **Utility / body / labels:** SF Pro (system font)
- **Hierarchy:** Title → Headline → Body → Label → Caption
- Never use all-caps in user-facing text

## Component Patterns

### Cards
- Corner radius: 18pt (`BabyTownTheme.cardRadius`)
- Shadow: `BabyTownTheme.cardShadow` — never custom shadow values
- Background: `BabyTownTheme.cardBackground` or gradient from `cardTintLight` → `cardTintDeep`

### Primary CTA Buttons
- Background: `BabyTownTheme.buttonGradient` (accent → accent at 82% opacity, leading to trailing)
- Shadow: `BabyTownTheme.buttonShadow` (accent at 30% opacity)
- Label: warm invitation phrasing — see `Voice.MD`

### Save Pill Buttons
- Fixed blue fill (`BabyTownTheme.savePillFill`) regardless of active theme
- Shadow: `BabyTownTheme.savePillShadow`
- Used for confirmation actions in editors and sheets

### Icon Gradients
- Icon tint: `BabyTownTheme.accentIconGradient`
- Icon backdrop fill: `BabyTownTheme.accentIconBackdropGradient`

## Spacing and Layout
- Standard card inset: 16pt horizontal
- Section spacing: 24pt
- Safe area: always respected, never overlapped by content
- Bottom sheet / half-sheet pattern for secondary actions

## Animation Principles
- Soft and springy — never abrupt or mechanical
- Float, pulse, and sparkle effects are on-brand
- Transitions should feel like turning a page, not clicking a button
- Abrupt cuts and harsh snaps are off-brand

## Note Editor — Image Assets

All note editor assets live in `Assets.xcassets` using snake_case names.

### Stamp images
Custom PNG crops from `stamps.png` / `stamps selected.png` (75×75pt each, 5 moods).
`StampCarouselView` resolves them automatically via `"stamp_\(mood.displayName.lowercased())_\(isSelected ? "sel" : "unsel")"`.

| Asset name | State | Mood |
|---|---|---|
| `stamp_butterflies_unsel` / `stamp_butterflies_sel` | unsel / sel | Butterflies |
| `stamp_giddy_unsel` / `stamp_giddy_sel` | unsel / sel | Giddy |
| `stamp_smitten_unsel` / `stamp_smitten_sel` | unsel / sel | Smitten |
| `stamp_dreamy_unsel` / `stamp_dreamy_sel` | unsel / sel | Dreamy |
| `stamp_playful_unsel` / `stamp_playful_sel` | unsel / sel | Playful |

### Other note assets

| Asset name | Usage |
|---|---|
| `note_washi_tape` | Tape decoration strip on the prompt chip (57×17pt) |
| `note_polaroid_frame` | Photo upload placeholder in the note editor (125×152pt) |
| `note_textbox` | Textbox background decoration |
| `note_paperclip` | Paperclip decoration on the textbox |

## Special: Story Onboarding Theme
The story onboarding flow uses `StoryOnboardingTheme` — a separate blush/red theme distinct from the main app. Do not use main app theme tokens inside `StoryOnboardingFlow.swift` or its scene views.
