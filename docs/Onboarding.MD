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
