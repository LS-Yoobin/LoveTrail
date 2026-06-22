# Prelude Capture Delete Button

**Date:** 2026-06-12  
**Status:** Approved

## Overview

Add a visible trash icon button to the trailing edge of each capture row card in `PreludeHomeView`. Tapping shows a confirmation alert before deleting.

## Files Affected

- `BabyTown/Views/Prelude/PreludeHomeView.swift` — only file changed

## Design

### `CaptureRowCard`

- Add `onDelete: () -> Void` parameter
- Replace trailing `Spacer()` with `Spacer() + Button(action: onDelete)` containing `Image(systemName: "trash")` styled in `BabyTownTheme.textSecondary`
- `.buttonStyle(.plain)` to prevent the whole card tap gesture from firing

### `PreludeHomeView.captureList`

- Add `@State private var captureToDelete: PreludeCapture?`
- Pass `onDelete: { captureToDelete = capture }` into each `CaptureRowCard`
- Attach `.alert` on the scroll view, triggered by `$captureToDelete` (using the `item:` overload)
  - Title: "Delete capture?"
  - Message: none
  - Buttons: **Delete** (role: `.destructive`) and **Cancel**
  - Confirm: `withAnimation { viewModel.deleteCapture(capture) }`

### Preserved behavior

- Existing `.swipeActions` delete stays unchanged

## Out of Scope

- No changes to `CaptureEditorView`, `PreludeViewModel`, or any model
