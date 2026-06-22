# Spec: Date Selection for "A First" Captures

**Date:** 2026-06-12
**Branch:** watch

---

## Overview

Users recording an "A First" capture need to be able to set the date when that first actually happened — not just when they opened the app to record it. Firsts (first date, first laugh, first text) often occurred days, weeks, or months before the user starts using the app. All other capture types (note, voice memo, reason) remain fixed at their creation timestamp.

---

## Data Model

### `PreludeCapture` — add one optional field

```swift
var firstDate: Date?
```

- Stores the user-specified date for when the first occurred.
- `createdAt` is unchanged and continues to serve as the record creation timestamp used for sorting and ordering.
- `firstDate` is `Optional` and `Codable`. Existing saved records decode `firstDate` as `nil` — no migration required.
- When `firstDate` is `nil` (pre-feature records), the UI falls back to displaying `createdAt`.
- The full `Date` value (year + month + day) is persisted. Time component is irrelevant for this field and can be midnight or the time of save — it is never displayed.
- Default value on new `.first` captures: `Date()` (today).

---

## Editor Layout — `CaptureEditorView` (`.first` type only)

The `firstEditor` computed property is restructured into two zones within a `VStack`:

### Fixed zone (non-scrolling, at top of sheet)

Rendered in order:

1. **"📅 When was this?" label** — small uppercase section label matching existing style.
2. **Date banner** — warm gradient card (`#fdf0ea → #fce8de`) showing the date in two lines:
   - Large bold text: month + day (e.g. "June 12")
   - Smaller muted text: year (e.g. "2026")
   - Calendar emoji on the right with a small "tap to change" hint.
   - Tapping the banner toggles an inline `DatePicker` (`.graphical` display mode) that expands directly below the banner within the fixed zone. Picker is bound to the `firstDate` state variable. Users can navigate to any month/year. Tapping the banner again collapses the picker.
3. **"— What was the first? —" section divider** — horizontal lines with label centered between them, matching existing `promptChip` style hierarchy.
4. **Dashed custom text field** — existing "Write your own first…" `TextField` with dashed border, unchanged.
5. **"or pick one" label** — small centered muted text.

### Scrollable zone (beneath fixed zone)

- A `ScrollView` (vertical, indicators hidden) containing a `VStack` of all preset option chips.
- The `ScrollView` takes the remaining available height via `.frame(maxHeight: .infinity)`.
- A bottom fade mask (`LinearGradient` as `.mask`) is applied to hint that the list is scrollable.
- Preset chips: tapping selects the chip and clears `customFirstLabel`; tapping the custom field clears the chip selection. This existing behavior is unchanged.

### State additions to `CaptureEditorView`

```swift
@State private var firstDate: Date = Date()
```

- Loaded from `existing.firstDate` (or `Date()` if nil) in `loadExisting()`.
- Passed as `firstDate` when constructing the `PreludeCapture` on save.

### Save behavior

`firstDate` is only written when `type == .first`. All other types pass `nil` for `firstDate` (field is not surfaced in their editors).

---

## Card Display — `CaptureRowCard`

For `.first` captures, the date line in the row changes:

```swift
// Before
Text(capture.createdAt, style: .date)

// After (for .first type only)
Text(capture.firstDate ?? capture.createdAt, style: .date)
```

All other capture types continue displaying `createdAt` unchanged.

---

## Editability — `PreludeHomeView`

Remove the guard that currently blocks `.first` captures from being tapped:

```swift
// Remove this:
guard capture.type != .first else { return }
```

Tapping a `.first` capture row now opens `CaptureEditorView` in edit mode, allowing the user to update both the label and the date. All other capture types remain non-editable via tap (their dates are fixed at creation time).

---

## Scope Boundaries

- No changes to `PreludeViewModel`, `DataPersistenceManager`, or any persistence layer beyond the model field addition.
- No changes to `GiftCurationView`, `PreludeChapterView`, or any other consumer of `PreludeCapture` — they continue using `createdAt` for their purposes.
- No changes to note, voice memo, or reason capture flows — their dates are fixed.
- No year-only or month-only picker variant — the full `Date` is always stored, displayed as month + day + year.
