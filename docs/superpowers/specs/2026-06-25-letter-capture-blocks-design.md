# Letter Capture Blocks Design

**Date:** 2026-06-25  
**Phase:** Together (`officialCouple`)  
**Status:** Implemented

## Summary

Official users compose letters as an envelope (title + optional intro text) with embeddable **Note**, **Voice**, and **Reason** blocks. Prelude's **First** type is excluded. Capture editors from Prelude are reused via `CaptureEditorDestination`; letter media is stored separately from prelude journaling.

## User Flow

1. Tap envelope FAB in Letters (`NotificationCenterView`) → `ComposeLetterView`
2. Write title and/or body text
3. Use quick-add bar (Note / Voice / Reason) to open `CaptureEditorView` in letter mode
4. Added blocks appear as inline previews inside the letter card
5. Send or Schedule — letter persists with `blocks` array and any voice files in `letter_voice_memos/`
6. Partner reads letter in `UserLetterDetailView` with rendered blocks

## Data Model

### `LetterBlock`

| Field | Note | Voice | Reason |
|-------|------|-------|--------|
| `noteText`, `noteMood` | ✓ | — | — |
| `voiceMemoFileId` | — | ✓ | — |
| `reasonText` | — | — | ✓ |

### `UserLetter`

- New field: `blocks: [LetterBlock]` (defaults to `[]` for backward compatibility)
- Save validation: non-empty body **or** at least one block

## Storage

| Asset | Path |
|-------|------|
| Letters JSON | `Documents/user_letters.json` |
| Letter voice memos | `Documents/letter_voice_memos/` |

Prelude captures and voice memos remain untouched.

## Editor Reuse

`CaptureEditorView` accepts `CaptureEditorDestination`:

- `.prelude(PreludeViewModel)` — existing Prelude behavior
- `.letter(onSave:)` — builds `LetterBlock`, hides gift toggle, uses Together-phase `LetterPrompts`

## Copy (Together Phase)

| Type | Prompt direction |
|------|------------------|
| Note | Partner appreciation, shared moments |
| Voice | "Say something you want them to hear out loud" |
| Reason | "One reason I love you:" |

## Out of Scope (v1)

- First moments in letters
- Attaching existing prelude captures
- Editing blocks after send
- Partner cloud delivery
- Scheduled delivery auto-fire

## Files

| File | Role |
|------|------|
| `BabyTown/Models/LetterBlock.swift` | Block model |
| `BabyTown/Models/VoiceMemoStorage.swift` | Prelude vs letter voice I/O |
| `BabyTown/Models/UserLetter.swift` | `blocks` field |
| `BabyTown/ViewModels/LetterPrompts.swift` | Together-phase copy |
| `BabyTown/Services/DataPersistenceManager.swift` | Letter voice memo helpers |
| `BabyTown/Views/Prelude/CaptureEditorView.swift` | Destination refactor |
| `BabyTown/Views/ComposeLetterView.swift` | Quick-add + previews |
| `BabyTown/Views/UserLetterDetailView.swift` | Block rendering |
| `BabyTown/Components/LetterBlockPreviewCard.swift` | Compose previews |
| `BabyTown/Components/LetterBlockDetailView.swift` | Read-only blocks |
| `BabyTown/Components/VoiceMemoPlayerView.swift` | Playback in detail |
