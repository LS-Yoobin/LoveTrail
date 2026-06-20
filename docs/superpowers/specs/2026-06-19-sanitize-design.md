# Sanitize Skill Design

**Date:** 2026-06-19
**Skill name:** `sanitize`
**Invocation:** `/sanitize <directory>`
**Language target:** Swift (includes SpriteKit)

---

## Overview

A manually invoked superpowers skill that cleans Swift code in a chosen directory. Uses a two-phase pipeline: analysis first, fixes only after user approval. Skips already-clean files using git to track changes since the last run, minimizing token usage.

---

## Invocation

```
/sanitize BabyTown/Components
```

No path defaults to the current open folder. Changes only files modified since the last git commit tagged `#sanitized`.

---

## Two-Phase Pipeline

### Phase 1 — Analysis Agent

1. Runs `git diff --name-only` to find `.swift` files modified since last run
2. Reads each changed file
3. Identifies all issues across two categories (see below)
4. Produces a structured report grouped by file
5. Presents report to user and waits for approval

### Phase 2 — Fix Agent

1. Activates only after user approves the report
2. Works file by file, completing and saving each before moving to the next
3. Only touches files and issues the user approved
4. Prints a one-line summary per file: `SettingsSheet.swift — 3 fixes applied`
5. Leaves all changes unstaged in git for user review
6. Prints a final summary: total files touched, total issues fixed

---

## Issue Categories

### Syntax Issues
| Issue | Example | Fix |
|---|---|---|
| Force unwrap | `profile!.name` | `guard let` or `if let` |
| Unused import | `import Foundation` (unused) | Remove import |
| Redundant type annotation | `let name: String = "Bob"` | `let name = "Bob"` |
| Commented-out code | 3+ lines of `//` dead code | Remove block |
| Dead code | Declared variable never read | Remove declaration |
| Unnecessary `self.` | `self.name` inside closure where not required | Remove `self.` |

### Structure Issues
| Issue | Threshold | Fix |
|---|---|---|
| Function too long | Over 50 lines | Extract into named sub-methods |
| File too large | Over 300 lines | Suggest splitting into focused files |
| Vague naming | `data`, `temp`, `manager2` | Rename to intent-revealing name |
| View doing business logic | SwiftUI body containing data fetching | Move logic to ViewModel |
| SpriteKit node all-inline | All node logic in one method | Separate into named methods |

---

## Report Format

```
SANITIZATION REPORT — BabyTown/Components (14 files changed)
═══════════════════════════════════════════════════════════

SettingsSheet.swift
  ⚠ Line 23  SYNTAX   Force unwrap on optional user profile
             Issue:   `profile!.name` will crash if profile is nil
             Fix:     Replace with `guard let profile = profile else { return }`
             Why:     Silent crash risk on first launch before profile loads

  ⚠ Line 87  SYNTAX   Commented-out code block (12 lines)
             Issue:   Old notification logic left in file
             Fix:     Remove lines 87-99
             Why:     Dead code adds noise and confuses future readers

  ⚠ Line 112 STRUCTURE  Function `setupView()` is 74 lines
             Issue:   Too long, handling layout AND data binding
             Fix:     Extract data binding into `bindViewModel()`
             Why:     Single responsibility makes testing and debugging easier

─────────────────────────────────────────────────────────
SUMMARY: 3 files  |  8 issues  (5 syntax, 3 structure)
Proceed with fixes? (yes / skip [filename] / cancel)
```

User responses:
- `yes` — apply all fixes
- `skip SettingsSheet.swift` — skip that file, fix the rest
- `cancel` — abort, no changes made

---

## Git Integration

- Uses `git diff --name-only HEAD` to find changed files
- Skips files with no changes since last commit
- Leaves all fixes unstaged so the user can review with `git diff`
- User commits with message including `#sanitized` to mark the baseline for next run

---

## Constraints

- Swift files only (`.swift` extension)
- Directory scope only, not single files or full project
- Report shown before any file is modified
- Fix agent never touches files the user skipped
- No auto-commit — user controls all git actions
