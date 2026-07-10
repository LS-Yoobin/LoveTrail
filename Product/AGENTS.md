# Covela — AI Agent Instructions

## Project Snapshot
- **App name:** Covela (never "BabyTown" in new code or copy)
- **Platform:** iOS, SwiftUI
- **What it is:** A shared private space for couples to own their moments, build a digital world of places visited together, and stay connected. Includes a gamification layer (pet adoption, pet room, coins).
- **Three phases:** Prelude (solo journaling/crushing), Together (shared Cove), Breakup transition
- See `Brand.MD` for the full three-phase model.

## Tech Stack
- SwiftUI — primary UI framework
- SpriteKit — pet and game layer
- MongoDB — backend database
- DataPersistenceManager — local persistence (UserDefaults and on-device storage)

## Feature Area → Files Map

Read these files before touching any feature area. Do not skip this step.

| Feature | Read before touching |
|---|---|
| Theme / colors | `BabyTown/Theme/BabyTownTheme.swift`, `BabyTown/Theme/ColorTheme.swift` |
| Onboarding | `BabyTown/Views/StoryOnboardingFlow.swift`, `DesignOnboardingstoryboard.md` |
| Pet / game | `BabyTown/Game/`, `BabyTown/Services/` |
| Data / persistence | `BabyTown/Services/DataPersistenceManager.swift` |
| Content / models | `BabyTown/Models/` |
| UI components | `BabyTown/Components/` |
| Design specs | `docs/superpowers/specs/` |

## Conventions
- Never use ` - ` (space dash space) in any user-facing string, label, button, notification, or placeholder
- Always use `BabyTownTheme.*` tokens for colors — never hardcode hex or RGB values
- Both Pink and Blue themes must always be supported — never assume one theme
- UI copy must match the phase context (Prelude / Together / Breakup) — see `Voice.MD`
- Swift file naming: PascalCase; asset naming: snake_case

## When Stuck Protocol

If the same fix has failed twice:

1. Stop. Do not try the same approach a third time.
2. Read the relevant spec in `docs/superpowers/specs/` for the feature area.
3. Re-read the key files listed in the Feature Map above.
4. Step back and identify the root cause before writing any new code.
5. If still unclear, surface the blocker explicitly to the user rather than guessing.

## Document Index
- Brand identity and three phases → `Brand.MD`
- Voice and copy tone → `Voice.MD`
- Color system and design tokens → `docs/Design.MD`
- Architecture and intern setup → `docs/Onboarding.MD`
- Feature specs → `docs/superpowers/specs/`
- Implementation plans → `docs/superpowers/plans/`
