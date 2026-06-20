# Covela Documentation System — Design Spec
Date: 2026-06-19

## Overview

A structured set of markdown files that gives AI agents (Claude, Cursor) and interns a complete, always-current picture of Covela: what it is, how it sounds, how it looks, how the code is organized, and how to get unstuck fast.

## Goals

- AI agents have enough context to write correct, on-brand code and copy without repeated correction
- Interns can onboard independently with no knowledge gaps
- The "stuck loop" problem is broken by a clear file map and escalation protocol in CLAUDE.md
- Voice, brand, and design are documented once and referenced everywhere

## File Structure

```
/                            (project root)
├── CLAUDE.md                AI master index + steering guide
├── Brand.MD                 Covela brand identity and three-phase model
├── Voice.MD                 Phase-dependent tone guide
└── docs/
    ├── Design.MD            Color system, typography, component patterns
    └── Onboarding.MD        Codebase architecture + intern getting-started guide
    └── superpowers/         Existing specs and plans (untouched)
```

---

## CLAUDE.md

### Purpose
The first file every AI agent reads. It orients, maps, constrains, and steers.

### Sections

**1. Project Snapshot**
- App name: Covela (never "BabyTown" in new code or copy)
- Platform: iOS, SwiftUI
- What it is: A shared private space for couples to own their moments, build a digital world of places visited, and stay connected
- Three phases: Prelude, Together, Breakup transition (see Brand.MD)

**2. Tech Stack**
- SwiftUI (primary UI)
- SpriteKit (pet/game layer)
- MongoDB (backend database)
- DataPersistenceManager (local persistence layer)

**3. Feature Area → Files Map**
A table agents must read before touching any feature area:

| Feature | Read before touching |
|---|---|
| Theme / colors | `BabyTown/Theme/BabyTownTheme.swift`, `BabyTown/Theme/ColorTheme.swift` |
| Onboarding | `BabyTown/Views/StoryOnboardingFlow.swift`, `DesignOnboardingstoryboard.md` |
| Pet / game | `BabyTown/Game/`, `BabyTown/Services/` |
| Data / persistence | `BabyTown/Services/DataPersistenceManager.swift` |
| Content / models | `BabyTown/Models/` |
| UI components | `BabyTown/Components/` |
| Design specs | `docs/superpowers/specs/` |

**4. Conventions**
- Never use ` - ` (space dash space) in any user-facing string, label, button, notification, or placeholder
- Always use `BabyTownTheme.*` tokens for colors — never hardcode hex or RGB values
- Both Pink and Blue themes must always be supported — never assume one theme
- UI copy must match the phase context (Prelude / Together / Breakup) — see Voice.MD
- File naming: Swift files use PascalCase, assets use snake_case

**5. When Stuck Protocol**
If the same fix has failed twice:
1. Stop. Do not try the same approach a third time.
2. Read the relevant spec in `docs/superpowers/specs/` for the feature area
3. Re-read the key files listed in the Feature Map above
4. Step back and identify the root cause before writing any new code
5. If still unclear, surface the blocker explicitly to the user rather than guessing

**6. Document Index**
- Brand identity and three phases → `Brand.MD`
- Voice and copy tone → `Voice.MD`
- Color system and components → `docs/Design.MD`
- Architecture and intern setup → `docs/Onboarding.MD`

---

## Brand.MD

### Purpose
Defines what Covela is, what it stands for, and the mental model every team member and AI agent should operate from.

### Sections

**1. Brand Name**
Covela. The name evokes "Cove" — a private, sheltered place that belongs to two people. Never abbreviated. Never referred to as "BabyTown" in any new work.

**2. What Covela Is**
A shared private space for couples who cherish time together. Users build a digital world anchored to real places they have visited, own their moments completely, and can take a trip down memory lane whenever they want. When apart, Covela keeps them connected. A gamification layer (pet adoption, pet room, coins) adds ongoing delight and daily return habit.

**3. The Three Phases**

| Phase | Who it's for | What they do |
|---|---|---|
| Prelude | One person, not yet official | Private journaling and thoughts about someone they are interested in |
| Together | An official couple | Shared Cove — building their story, uploading moments, caring for their pet, exploring their map |
| Breakup transition | Separating couple | Graceful data handling; place metadata preserved on the Covela map, personal photos downloadable before clearing |

The Breakup phase is still being designed. Key principle: the app remains valuable after a relationship ends and should support starting fresh with a new partner in the future.

**4. Brand Values**
- **Ownership** — Your moments, your world. Nothing is harvested or shown to others.
- **Intimacy** — Private by design. The Cove belongs only to the couple.
- **Joy** — Playful gamification that makes returning to the app feel like a treat.
- **Continuity** — Memories and places persist in meaningful ways across time.

**5. Visual Identity**
Warm, soft, never clinical. Two selectable themes: Pink (warm blush, soft evenings) and Blue (calm sky, quiet mornings). Both communicate care and warmth — never tech-cold or sterile. Full color system in `docs/Design.MD`.

**6. The Cove**
The couple's shared space is called their Cove. Language across the app should reinforce that this space is theirs — protected, personal, and built together. Prefer "your Cove" over "your account," "your profile," or "your space."

---

## Voice.MD

### Purpose
Defines how Covela speaks to users at each phase of their relationship. All UI copy, notifications, empty states, and onboarding strings must match the phase they appear in.

### Core Principle
Covela's voice matures with the relationship. It is not a fixed brand voice — it is a living one. Before writing any string, identify which phase it belongs to.

### Phase Voice Matrix

| Phase | Tone | Feel | Avoid |
|---|---|---|---|
| Prelude | Playful, light, giddy | Butterflies, possibility, secret excitement | Heavy commitment language, "we" or "our," anything that assumes a couple |
| Together | Intimate, warm, poetic | Belonging, tenderness, shared world | Generic or transactional copy, cold instructional tone, impersonal language |
| Breakup | Gentle, honoring, calm | Dignity, care, no blame | Dramatic language, urgency, pressure, anything that diminishes what the relationship was |

### Do / Don't Examples

**Prelude**
- "Start writing your story" not "Create a journal entry"
- "Someone's on your mind" not "Add a new contact"
- "Just between you and these pages" not "Private notes enabled"

**Together**
- "Your Cove" not "Your account"
- "A moment worth keeping" not "Photo added"
- "You two have been here" not "Location saved"
- "Let's go back together" not "View memory"

**Breakup**
- "Your memories are safe to download" not "Export your data"
- "Take all the time you need" not "Complete your account transition"
- "The places you visited together will always be part of your map" not "Location history retained"

### Hard Rules (All Phases)
- No ` - ` (space dash space) in any user-facing string
- No all-caps for emphasis
- Warm contractions preferred: "you're," "let's," "it's"
- No cold instructional tone ("Please enter," "You must," "Error:")
- Button labels are invitations, not commands ("Save our moment" not "Save")

### UI Copy Checklist
Before shipping any label, notification, or empty state, ask:
1. Which phase does this appear in?
2. Does the tone match the phase matrix above?
3. Does it feel right at 11pm on a couch with your partner?
4. Does it contain a dash? (Remove it.)

---

## docs/Design.MD

### Purpose
The single source of truth for Covela's visual design system. All UI work must use these tokens and patterns.

### Color System

Always use `BabyTownTheme.*` properties — never hardcode values. Both themes must be supported.

**Pink Theme** (default, "warm blush and soft evenings")

| Token | Value |
|---|---|
| `accent` | `Color.pink` |
| `accentDeep` | `rgb(0.88, 0.22, 0.38)` |
| `cardBackground` | `rgb(0.96, 0.82, 0.86)` |
| `cardTintLight` | `rgb(1.0, 0.97, 0.94)` |
| `cardTintDeep` | `rgb(0.99, 0.90, 0.93)` |
| `blushSoft` | `rgb(1.0, 0.92, 0.94)` |
| `background` | `Color.white` |

**Blue Theme** ("calm sky and quiet mornings")

| Token | Value |
|---|---|
| `accent` | `rgb(0.22, 0.48, 0.96)` |
| `accentDeep` | `rgb(0.14, 0.34, 0.78)` |
| `cardBackground` | `rgb(0.80, 0.88, 0.96)` |
| `cardTintLight` | `rgb(0.96, 0.98, 1.0)` |
| `cardTintDeep` | `rgb(0.86, 0.92, 0.99)` |
| `blushSoft` | `rgb(0.92, 0.95, 1.0)` |
| `background` | `Color.white` (soft blue gradient to bottom) |

**Fixed colors (not theme-dependent)**
- Save pill fill: `rgb(0.22, 0.48, 0.96)` (always blue regardless of theme)
- Text primary: `Color(.darkGray)`
- Text secondary: `Color(.secondaryLabel)`
- Card shadow: `Color.black.opacity(0.05)`

### Typography
- Emotional / headline moments: serif font
- Utility / body / labels: SF Pro (system font)
- Hierarchy: Title → Headline → Body → Label → Caption
- Never use all-caps in user-facing text

### Component Patterns

**Cards**
- Corner radius: 18pt
- Shadow: `cardShadow` token, not custom values
- Background: `cardBackground` or gradient from `cardTintLight` to `cardTintDeep`

**Primary CTA Buttons**
- Background: `buttonGradient` (accent to accent at 82% opacity, leading to trailing)
- Shadow: `buttonShadow` (accent at 30% opacity)
- Label: warm invitation phrasing (see Voice.MD)

**Save Pill Buttons**
- Fixed blue fill (`savePillFill`), not theme-dependent
- Used for confirmation actions in editors and sheets

**Icon gradients**
- Use `accentIconGradient` for icon tints on onboarding and camera controls
- Use `accentIconBackdropGradient` for the icon background fill

### Spacing and Layout
- Standard card inset: 16pt horizontal
- Section spacing: 24pt
- Safe area: always respected, never overlapped by content
- Bottom sheet / half-sheet pattern for secondary actions

### Animation Principles
- Soft and springy — never abrupt or mechanical
- Float, pulse, and sparkle effects are on-brand
- Transitions should feel like turning a page, not clicking a button
- Abrupt cuts and harsh snaps are off-brand
- Story onboarding uses the blush/red theme (`StoryOnboardingTheme`) — distinct from main app

---

## docs/Onboarding.MD

### Purpose
Everything a new intern needs to understand the codebase and start contributing. Also covers how to work effectively with AI agents on this project.

### Codebase Architecture

**Top-level folders**

| Folder | What's in it |
|---|---|
| `BabyTown/` | All app source code |
| `BabyTown/Views/` | Full-screen views |
| `BabyTown/Components/` | Reusable UI components |
| `BabyTown/ViewModels/` | View models (ObservableObject) |
| `BabyTown/Models/` | Data models and structs |
| `BabyTown/Services/` | Business logic, persistence, audio |
| `BabyTown/Theme/` | Color system and theme tokens |
| `BabyTown/Game/` | SpriteKit pet/game layer |
| `BabyTown/Resources/` | Assets, fonts, audio files |
| `docs/` | Design specs, plans, and this file |

**Key files to know**

| File | Purpose |
|---|---|
| `BabyTown/ContentView.swift` | Root navigation — controls which screen is shown |
| `BabyTown/Theme/BabyTownTheme.swift` | All design tokens — read this before any UI work |
| `BabyTown/Theme/ColorTheme.swift` | Pink/Blue theme enum and per-token values |
| `BabyTown/Services/DataPersistenceManager.swift` | Local data persistence — all UserDefaults and storage |
| `BabyTown/Views/StoryOnboardingFlow.swift` | Onboarding story flow |

### Key Concepts Glossary

| Term | What it means |
|---|---|
| Cove | The couple's shared private space — the core product concept |
| Moment | A memory entry: photos, notes, date, place |
| Pet Room | The gamification space where the couple's adopted pet lives |
| Prelude | Phase 1 — solo, before the relationship is official |
| Together | Phase 2 — couple's shared Cove is active |
| Breakup | Phase 3 — relationship ends, graceful data transition |
| Coin | In-app currency earned through engagement, spent in pet room |

### Environment Setup
1. Open `BabyTown.xcodeproj` in Xcode
2. Select a simulator or connected device
3. Build and run — no additional dependencies should be needed for UI work
4. MongoDB backend connection details are in the backend config (ask the team lead)

### How to Work with AI Agents

**Always start with CLAUDE.md.** If you are opening a new Claude or Cursor session, paste or reference CLAUDE.md first. It tells the agent what the project is, where things live, and what rules to follow.

**Point agents to specs before asking them to build.** Relevant specs are in `docs/superpowers/specs/`. If a feature has a design spec, share it with the agent before asking it to implement.

**When the agent is stuck in a loop:**
- Stop the conversation
- Ask the agent to re-read the relevant spec and key files from the CLAUDE.md map
- Ask it to explain what it thinks the problem is before writing more code
- If still stuck, surface the blocker to the team rather than continuing to iterate

**Voice and copy:** When asking an agent to write any UI string, always tell it which phase (Prelude, Together, or Breakup) the string appears in. Reference Voice.MD. The agent should never default to generic app copy.

**Theme:** When asking an agent to build any UI component, remind it that both Pink and Blue themes must work. Never accept hardcoded color values.
