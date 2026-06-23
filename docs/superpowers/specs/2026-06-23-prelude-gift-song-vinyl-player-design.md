# Prelude Gift Song — Vinyl Record Player

**Date:** 2026-06-23
**Phase:** Prelude
**Files touched:** `GiftCurationView`, `PreludeGiftBookView`, `DataPersistenceManager`, new `PreludeGiftSong` model, new `PreludeGiftSongImportCoordinator`

---

## Overview

Users in the Prelude phase can attach a single song to their gift. The song is chosen via the existing import-from-video flow and saved independently of the Together-phase couple playlist. When the partner opens the gift scrapbook, the song plays automatically on loop with an animated vinyl record widget in the top-right corner. If no song was ever chosen, the vinyl widget does not appear in the scrapbook.

---

## Data Model

### `PreludeGiftSong`

```swift
struct PreludeGiftSong: Codable {
    var fileName: String      // audio file name stored in the gift song directory
    var displayName: String   // user-given name shown on the vinyl card
}
```

Stored as `prelude_gift_song/metadata.json` in the app's Documents directory. The audio file lives alongside it at `prelude_gift_song/<fileName>`.

Completely separate from `CouplePlaylistStore` — no coupling to the Together phase.

### `DataPersistenceManager` additions

Four new methods:

| Method | Purpose |
|---|---|
| `savePreludeGiftSong(_ song: PreludeGiftSong, audioData: Data)` | Write metadata JSON + audio file |
| `loadPreludeGiftSong() -> PreludeGiftSong?` | Read metadata; nil if none saved |
| `deletePreludeGiftSong()` | Remove metadata JSON + audio file |
| `preludeGiftSongAudioURL() -> URL` | Return the audio file URL for playback |

---

## Gift Curation UI (`GiftCurationView`)

A compact vinyl song card is inserted between the capture list and the "Send Invite" button.

### No song chosen (empty state)

- Static (non-spinning) `VinylRecordPlayerView` on the left
- "Add a song" label in muted secondary text
- Tapping anywhere on the card opens the `PhotosPicker` via `PreludeGiftSongImportCoordinator`

### Song chosen

- Spinning `VinylRecordPlayerView` on the left (animated, not playing audio — visual affordance only)
- Song `displayName` in the center
- Trash icon button on the right calls `DataPersistenceManager.shared.deletePreludeGiftSong()` and clears local state

### Visual style

Matches the existing `GiftCaptureRow` language: `RoundedRectangle(cornerRadius: 12)`, `BabyTownTheme.cardBackground` fill, `BabyTownTheme.accent` for the vinyl tint. Card sits at `.padding(.horizontal, 24)` above the send button.

### Sheets presented by `GiftCurationView`

- `CoupleSongTrimSheet` — bound to `importCoordinator.draftAwaitingTrim` (reused unchanged)
- `CoupleSongNameSheet` — bound to `importCoordinator.trackAwaitingName` (reused unchanged)
- Import error alert — bound to `importCoordinator.statusMessage`

---

## Gift Scrapbook UI (`PreludeGiftBookView`)

### When a gift song exists

- `VinylRecordPlayerView(isPlaying: isPlaying, scale: 1.0)` overlaid via `.overlay(alignment: .topTrailing)` with `.padding(16)` inset
- Not tappable — purely ambient
- On `.onAppear`: load audio from `DataPersistenceManager.shared.preludeGiftSongAudioURL()`, create `AVAudioPlayer`, set `numberOfLoops = -1`, call `play()`, set `isPlaying = true`
- On `.onDisappear`: call `stop()`, set `isPlaying = false`
- Audio session category: `.playback`, mode: `.default` (same as voice memo playback in `GiftCardView`)

### When no gift song exists

No overlay rendered. Scrapbook appearance is unchanged from today.

---

## Import Flow (`PreludeGiftSongImportCoordinator`)

New `ObservableObject` coordinator. Mirrors `BackgroundMusicImportCoordinator` in structure but saves to `DataPersistenceManager` instead of `CouplePlaylistStore`.

### Supporting type

```swift
struct PreludeGiftSongDraft: Identifiable {
    let id: UUID = UUID()
    var initialName: String
    var audioData: Data
}
```

Used only within the coordinator to carry trimmed audio through the naming step before saving.

### Published state

```swift
@Published var pickerItem: PhotosPickerItem?
@Published var draftAwaitingTrim: AudioTrimDraft?
@Published var trackAwaitingName: PreludeGiftSongDraft?
@Published var isImporting: Bool = false
@Published var statusMessage: String?
```

### Completion callback

Coordinator is initialised with `onSongSaved: (PreludeGiftSong) -> Void`. After a successful save, it calls this closure so `GiftCurationView` can update its local `@State var giftSong: PreludeGiftSong?` without a notification broadcast.

### Flow

1. User taps card → `PhotosPicker` opens (matching `.videos`)
2. `onChange(of: pickerItem)` → calls `importPickedVideo(_:)`
3. `BackgroundMusicImporter` extracts audio → sets `draftAwaitingTrim`
4. User trims in `CoupleSongTrimSheet` → calls `confirmTrim(draft:startSeconds:endSeconds:)`
5. User names in `CoupleSongNameSheet` → calls `finishNamingTrack(displayName:)`
6. Coordinator calls `DataPersistenceManager.shared.savePreludeGiftSong(_:audioData:)`
7. Coordinator calls `onSongSaved(savedSong)` → `GiftCurationView` updates `giftSong`

### Reused components (zero changes)

- `BackgroundMusicImporter` — audio extraction
- `CoupleSongTrimSheet` — trim UI
- `CoupleSongNameSheet` — naming UI
- `VinylRecordPlayerView` — display

---

## What is not changed

- `VinylRecordPlayerView`
- `CouplePlaylistStore`
- `OurSongSheet`
- `BackgroundMusicImporter`
- `CoupleSongTrimSheet`
- `CoupleSongNameSheet`
- `AudioManager`
- `GiftCaptureRow`

---

## Scope boundary

The sync of the gift song audio file to the partner's device via the backend (MongoDB) is out of scope for this spec. The scrapbook reads from local `DataPersistenceManager` storage; how the audio arrives on the partner's device is handled by the existing gift sync infrastructure.
