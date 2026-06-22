# Covela Documentation System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create five markdown documentation files that give AI agents and interns complete, always-current context about Covela — eliminating repeated corrections and stuck loops.

**Architecture:** Root-level files (`CLAUDE.md`, `Brand.MD`, `Voice.MD`) are reached immediately by any agent or intern. Deeper files (`docs/Design.MD`, `docs/Onboarding.MD`) live alongside existing specs. `CLAUDE.md` is the master index — it points every agent to the right file for every task.

**Tech Stack:** Markdown only. No code changes. No dependencies.

## Global Constraints

- App name is Covela — never "BabyTown" in any new copy or documentation
- No ` - ` (space dash space) in any user-facing string across the entire app
- Both Pink and Blue themes must always be supported — never assume one theme
- Always use `BabyTownTheme.*` tokens — never hardcode hex or RGB values
- File location: `CLAUDE.md`, `Brand.MD`, `Voice.MD` at project root; `Design.MD`, `Onboarding.MD` in `docs/`

---

## Task 1: CLAUDE.md

**Files:**
- Create: `CLAUDE.md` (project root)

**Interfaces:**
- Produces: The master index file all agents read first. References `Brand.MD`, `Voice.MD`, `docs/Design.MD`, `docs/Onboarding.MD`.

- [ ] **Step 1: Verify root is correct location**

Run:
```bash
ls /Users/ybstudio/Desktop/Projects/Covela/CLAUDE.md 2>/dev/null && echo "EXISTS" || echo "OK TO CREATE"
```
Expected: `OK TO CREATE`

- [ ] **Step 2: Create CLAUDE.md**

Create `/Users/ybstudio/Desktop/Projects/Covela/CLAUDE.md` with this exact content:

```markdown
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
```

- [ ] **Step 3: Verify file was created and has all required sections**

Run:
```bash
grep -c "##" /Users/ybstudio/Desktop/Projects/Covela/CLAUDE.md
```
Expected: `6` (Project Snapshot, Tech Stack, Feature Area, Conventions, When Stuck, Document Index)

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md — AI agent master index and steering guide"
```

---

## Task 2: Brand.MD

**Files:**
- Create: `Brand.MD` (project root)

**Interfaces:**
- Produces: Brand identity, three-phase model, brand values, Cove concept. Referenced by `CLAUDE.md` and `Voice.MD`.

- [ ] **Step 1: Create Brand.MD**

Create `/Users/ybstudio/Desktop/Projects/Covela/Brand.MD` with this exact content:

```markdown
# Covela — Brand Identity

## Brand Name
Covela. The name evokes "Cove" — a private, sheltered place that belongs to two people. Never abbreviated. Never referred to as "BabyTown" in any new work.

## What Covela Is
A shared private space for couples who cherish time together. Users build a digital world anchored to real places they have visited, own their moments completely, and can take a trip down memory lane whenever they want. When apart, Covela keeps them connected.

A gamification layer — pet adoption, a pet room, and an in-app coin economy — adds ongoing delight and daily return habit.

## The Three Phases

| Phase | Who it's for | What they do |
|---|---|---|
| Prelude | One person, not yet official | Private journaling and thoughts about someone they are interested in |
| Together | An official couple | Shared Cove: building their story, uploading moments, caring for their pet, exploring their map |
| Breakup | Separating couple | Graceful data handling; place metadata preserved on Covela's map, personal photos downloadable before clearing |

**Breakup phase is still being designed.** Key principle: the app remains valuable after a relationship ends and supports starting fresh with a new partner in the future. Place name metadata persists on the map even after a relationship ends. Photos and notes are cleared when a new relationship begins (user downloads what they want to keep first).

## Brand Values
- **Ownership** — Your moments, your world. Nothing is harvested or shown to others.
- **Intimacy** — Private by design. The Cove belongs only to the couple.
- **Joy** — Playful gamification that makes returning to the app feel like a treat.
- **Continuity** — Memories and places persist in meaningful ways across time.

## Visual Identity
Warm, soft, never clinical. Two selectable themes: Pink (warm blush, soft evenings) and Blue (calm sky, quiet mornings). Both communicate care and warmth — never tech-cold or sterile. Full color system in `docs/Design.MD`.

## The Cove
The couple's shared space is called their Cove. Language across the app should reinforce that this space is theirs — protected, personal, and built together.

Prefer:
- "your Cove" over "your account" or "your profile"
- "your story" over "your data"
- "your world" over "your content"
```

- [ ] **Step 2: Verify file was created and has all required sections**

Run:
```bash
grep -c "##" /Users/ybstudio/Desktop/Projects/Covela/Brand.MD
```
Expected: `6` (Brand Name, What Covela Is, Three Phases, Brand Values, Visual Identity, The Cove)

- [ ] **Step 3: Commit**

```bash
git add Brand.MD
git commit -m "docs: add Brand.MD — Covela brand identity and three-phase model"
```

---

## Task 3: Voice.MD

**Files:**
- Create: `Voice.MD` (project root)

**Interfaces:**
- Produces: Phase-dependent tone guide, do/don't examples, hard copy rules. Referenced by `CLAUDE.md` and `docs/Design.MD`.

- [ ] **Step 1: Create Voice.MD**

Create `/Users/ybstudio/Desktop/Projects/Covela/Voice.MD` with this exact content:

```markdown
# Covela — Voice Guide

## Core Principle
Covela's voice matures with the relationship. It is not a fixed brand voice — it is a living one. Before writing any string, identify which phase it belongs to.

## Phase Voice Matrix

| Phase | Tone | Feel | Avoid |
|---|---|---|---|
| Prelude | Playful, light, giddy | Butterflies, possibility, secret excitement | Heavy commitment language, "we" or "our," anything that assumes a couple |
| Together | Intimate, warm, poetic | Belonging, tenderness, shared world | Generic or transactional copy, cold instructional tone, impersonal language |
| Breakup | Gentle, honoring, calm | Dignity, care, no blame | Dramatic language, urgency, pressure, anything that diminishes what the relationship was |

## Do / Don't Examples

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

## Hard Rules (All Phases)
- No ` - ` (space dash space) in any user-facing string
- No all-caps for emphasis
- Warm contractions preferred: "you're," "let's," "it's"
- No cold instructional tone ("Please enter," "You must," "Error:")
- Button labels are invitations, not commands ("Save our moment" not "Save")

## UI Copy Checklist
Before shipping any label, notification, or empty state:
1. Which phase does this appear in?
2. Does the tone match the phase matrix above?
3. Does it feel right at 11pm on a couch with your partner?
4. Does it contain a dash? (Remove it.)
```

- [ ] **Step 2: Verify file was created and has all required sections**

Run:
```bash
grep -c "##" /Users/ybstudio/Desktop/Projects/Covela/Voice.MD
```
Expected: `5` (Core Principle, Phase Voice Matrix, Do/Don't, Hard Rules, UI Copy Checklist)

- [ ] **Step 3: Commit**

```bash
git add Voice.MD
git commit -m "docs: add Voice.MD — phase-dependent tone guide for all UI copy"
```

---

## Task 4: docs/Design.MD

**Files:**
- Create: `docs/Design.MD`

**Interfaces:**
- Produces: Color system with exact tokens, typography, component patterns, animation principles. Referenced by `CLAUDE.md`.

- [ ] **Step 1: Create docs/Design.MD**

Create `/Users/ybstudio/Desktop/Projects/Covela/docs/Design.MD` with this exact content:

```markdown
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

## Special: Story Onboarding Theme
The story onboarding flow uses `StoryOnboardingTheme` — a separate blush/red theme distinct from the main app. Do not use main app theme tokens inside `StoryOnboardingFlow.swift` or its scene views.
```

- [ ] **Step 2: Verify file was created and has all required sections**

Run:
```bash
grep -c "##" /Users/ybstudio/Desktop/Projects/Covela/docs/Design.MD
```
Expected: `7` (Color System, Typography, Component Patterns, Spacing, Animation, Special)

- [ ] **Step 3: Commit**

```bash
git add docs/Design.MD
git commit -m "docs: add Design.MD — color system, component patterns, animation principles"
```

---

## Task 5: docs/Onboarding.MD

**Files:**
- Create: `docs/Onboarding.MD`

**Interfaces:**
- Produces: Intern getting-started guide + codebase architecture map. Referenced by `CLAUDE.md`.

- [ ] **Step 1: Create docs/Onboarding.MD**

Create `/Users/ybstudio/Desktop/Projects/Covela/docs/Onboarding.MD` with this exact content:

```markdown
# Covela — Onboarding Guide

For new interns and contributors. Read this before writing any code.

---

## What is Covela?

Covela is an iOS app for couples who cherish time together. It is a shared private space — called a **Cove** — where couples build a digital world of places they have visited, relive memories, and stay connected when apart. A gamification layer (pet, pet room, coins) adds delight and daily habit.

Read `Brand.MD` for the full picture before touching any product copy or feature.

## The Three Phases

All features belong to one of three relationship phases. Know which phase you're working in before building anything.

| Phase | Who it's for | Key characteristics |
|---|---|---|
| **Prelude** | One person, not yet official | Solo journaling, private, no shared state |
| **Together** | Official couple | Shared Cove, full feature access, gamification active |
| **Breakup** | Separating couple | Graceful data transition, map metadata preserved |

## Key Concepts Glossary

| Term | What it means |
|---|---|
| **Cove** | The couple's shared private space — the core product concept |
| **Moment** | A memory entry: photos, notes, date, place |
| **Pet Room** | The gamification space where the couple's adopted pet lives |
| **Coin** | In-app currency earned through engagement, spent in the pet room |
| **Prelude** | Phase 1 — solo, before the relationship is official |
| **Together** | Phase 2 — couple's shared Cove is active |
| **Breakup** | Phase 3 — relationship ends, graceful data transition |

---

## Codebase Architecture

### Top-Level Folders

| Folder | What's in it |
|---|---|
| `BabyTown/` | All app source code (folder name is legacy; app name is now Covela) |
| `BabyTown/Views/` | Full-screen views |
| `BabyTown/Components/` | Reusable UI components |
| `BabyTown/ViewModels/` | ObservableObject view models |
| `BabyTown/Models/` | Data models and structs |
| `BabyTown/Services/` | Business logic, persistence, audio |
| `BabyTown/Theme/` | Color system and design tokens |
| `BabyTown/Game/` | SpriteKit pet and game layer |
| `BabyTown/Resources/` | Assets, fonts, audio files |
| `docs/superpowers/specs/` | Feature design specs |
| `docs/superpowers/plans/` | Implementation plans |

### Key Files

| File | Purpose |
|---|---|
| `BabyTown/ContentView.swift` | Root navigation — controls which screen is shown |
| `BabyTown/Theme/BabyTownTheme.swift` | All design tokens — read before any UI work |
| `BabyTown/Theme/ColorTheme.swift` | Pink/Blue theme enum and per-token values |
| `BabyTown/Services/DataPersistenceManager.swift` | All UserDefaults and on-device storage |
| `BabyTown/Views/StoryOnboardingFlow.swift` | Onboarding story flow |

### Data Flow
Views observe ViewModels (`@ObservedObject` / `@StateObject`). ViewModels call Services. Services read and write via `DataPersistenceManager` locally and MongoDB remotely. The `ThemeManager` singleton holds the active `ColorTheme` and drives `BabyTownTheme.*` values reactively.

---

## Environment Setup

1. Open `BabyTown.xcodeproj` in Xcode
2. Select a simulator or connected device (iOS 16 or later recommended)
3. Build and run — no additional dependencies required for UI work
4. MongoDB backend connection: ask the team lead for config details
5. To reset onboarding during development: use the Reset option from Home, which clears `hasCompletedOnboarding` in `DataPersistenceManager`

---

## How to Work with AI Agents

### Start every session with CLAUDE.md
Open a new Claude or Cursor session and reference `CLAUDE.md` first. It tells the agent what the project is, where things live, and what rules to follow.

### Point agents to specs before asking them to build
Relevant specs are in `docs/superpowers/specs/`. If a feature has a design spec, share it with the agent before asking it to implement anything.

### When the agent is stuck in a loop
1. Stop the conversation
2. Ask the agent to re-read the relevant spec and the key files from the CLAUDE.md feature map
3. Ask it to explain what it thinks the root cause is before writing more code
4. If still stuck, surface the blocker to the team — do not keep iterating

### Always specify the phase for copy work
When asking an agent to write any UI string, tell it which phase (Prelude, Together, or Breakup) the string appears in. Reference `Voice.MD`. Never accept generic app copy.

### Always verify theme coverage
When asking an agent to build any UI component, confirm it supports both Pink and Blue themes. Never accept hardcoded color values — all colors must come from `BabyTownTheme.*`.
```

- [ ] **Step 2: Verify file was created and has all required sections**

Run:
```bash
grep -c "##" /Users/ybstudio/Desktop/Projects/Covela/docs/Onboarding.MD
```
Expected: `7` (What is Covela, Three Phases, Glossary, Architecture, Key Files, Setup, AI Agents)

- [ ] **Step 3: Commit**

```bash
git add docs/Onboarding.MD
git commit -m "docs: add Onboarding.MD — intern guide, architecture map, AI agent workflow"
```

---

## Final Verification

- [ ] **Confirm all five files exist**

Run:
```bash
ls /Users/ybstudio/Desktop/Projects/Covela/CLAUDE.md \
   /Users/ybstudio/Desktop/Projects/Covela/Brand.MD \
   /Users/ybstudio/Desktop/Projects/Covela/Voice.MD \
   /Users/ybstudio/Desktop/Projects/Covela/docs/Design.MD \
   /Users/ybstudio/Desktop/Projects/Covela/docs/Onboarding.MD
```
Expected: all five paths listed with no errors

- [ ] **Confirm no dashes in any file**

Run:
```bash
grep -rn " - " /Users/ybstudio/Desktop/Projects/Covela/CLAUDE.md \
  /Users/ybstudio/Desktop/Projects/Covela/Brand.MD \
  /Users/ybstudio/Desktop/Projects/Covela/Voice.MD \
  /Users/ybstudio/Desktop/Projects/Covela/docs/Design.MD \
  /Users/ybstudio/Desktop/Projects/Covela/docs/Onboarding.MD
```
Expected: no output (no ` - ` in any file outside of code blocks and intentional examples in Voice.MD)
