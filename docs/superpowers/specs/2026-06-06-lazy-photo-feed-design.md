# Lazy Photo Loading + Paginated Home Feed — Design

**Date:** 2026-06-06
**Status:** Approved (pending spec review)

## Problem

The BabyTown home feed gets slow and memory-heavy as the number of moments grows
(there is no cap — it can reach thousands). Two root causes:

1. **Every photo is fully decoded into RAM at launch.** `Moment.thumbnail` and
   `PromptPhoto.thumbnail` are stored, eagerly-decoded `UIImage`s. All moments live
   in a single `moments.json` (and prompt memories in `prompt_memories.json`) with
   each photo's JPEG embedded inline as base64. `loadMoments()` /
   `loadPromptMemories()` decode the entire file at startup, so every `UIImage`
   exists in memory regardless of what's on screen.

2. **Every edit re-encodes everything.** `moments.didSet` calls `saveMoments`, which
   re-JPEGs every thumbnail (quality 0.8) on every mutation.

A previous attempt (via Cursor) added only **UI-level pagination** — rendering fewer
SwiftUI rows. This did not reduce decoded images in memory (they are all already
decoded), made scrolling slower (heavy computed properties re-run on every scroll
event), and shipped a **broken load-more**: the button was gated behind `!canScroll`
and auto-load was driven by fragile scroll-offset math that accumulated moment counts.
It also left `.cursor` debug-logging instrumentation (`agentDebugLog`) in
`HomeViewModel`.

## Goals

- Fast launch and bounded memory regardless of photo count.
- Smooth scrolling — no main-thread image decoding during scroll.
- Reliable Instagram-style feed: render a page, auto-load more as the user nears the
  bottom, with a button fallback.
- No data loss for existing users (one-time migration).
- Minimal blast radius: `.thumbnail` is read in ~70 places across 30 files and
  constructed in ~66 places; the public `thumbnail: UIImage` API must stay intact.

## Non-Goals

- Re-architecting the viewer, share, or map image paths (they show few images at once
  and can keep the synchronous full-decode path).
- Changing the on-disk JPEG quality or thumbnail dimensions produced at capture time.
- Unrelated refactors.

## Architecture

### 1. `ThumbnailStore` (new service)

Owns photo bytes on disk and an in-memory cache. One instance (`ThumbnailStore.shared`).

- **Disk layout:** `Documents/thumbnails/<uuid>.jpg`, keyed by the moment/photo `id`.
- **Memory cache:** `NSCache<NSString, UIImage>` with `totalCostLimit` in bytes
  (target ~64 MB; cost = approximate decoded byte size). Auto-evicts under memory
  pressure and when off-screen items age out.
- **API:**
  - `fullImage(for id: UUID) -> UIImage?` — cache → disk (full decode) → nil.
    Used by non-feed call sites and by the `thumbnail` accessor.
  - `feedImage(for id: UUID, targetPixels: CGFloat) -> UIImage?` — **downsampled**
    decode via ImageIO (`CGImageSourceCreateThumbnailAtIndex` with
    `kCGImageSourceThumbnailMaxPixelSize`), so a large source never becomes a
    full-size bitmap to fill a small card. Cached under a size-bucketed key.
  - `cache(_ image: UIImage, for id: UUID)` — in-memory only (no disk write).
  - `persistIfNeeded(for id: UUID)` — writes `<id>.jpg` from the cached image if the
    file does not already exist (idempotent, cheap).
  - `store(_ image: UIImage, for id: UUID)` — cache + write to disk immediately
    (used where a synchronous guarantee is wanted).
  - `remove(for id: UUID)` — delete disk file + evict cache.
  - `fileExists(for id: UUID) -> Bool`.

Decode work (`feedImage`) runs off the main thread; the store itself is thread-safe
(`NSCache` is; disk reads are serialized as needed).

### 2. `Moment` & `PromptPhoto` model change (API-preserving)

- `thumbnail` changes from a stored `let thumbnail: UIImage` to a **computed
  accessor**:

  ```swift
  var thumbnail: UIImage { ThumbnailStore.shared.fullImage(for: id) ?? Self.placeholder }
  ```

- Initializers that currently take `thumbnail: UIImage` call
  `ThumbnailStore.shared.cache(image, for: id)` so the image is available
  immediately, before persistence.
- `Codable` drops the inline `thumbnailData` key. Decoding no longer materializes a
  `UIImage`; encoding no longer writes image bytes.
- Because the public surface (`thumbnail: UIImage`) is unchanged, the ~70 read sites
  and ~66 construction sites keep compiling without edits.

**New-moment safety:** when a new moment is created and added to `moments`, the
`didSet` runs `saveMoments` synchronously in the same turn; `saveMoments` calls
`persistIfNeeded` which writes the cached image to disk. So by the time the in-memory
cache could evict, the disk file exists — no loss of freshly captured photos.

Throwaway/derived moments (e.g. `convertToMapMoment`, sample data) only populate the
in-memory cache and are never persisted, which is fine.

### 3. Persistence + one-time migration

- `saveMoments` / `savePromptMemories`: encode **metadata-only** JSON (no image
  bytes — tiny and cheap), then call `persistIfNeeded(for:)` for each photo id. This
  also removes the "re-JPEG every photo on every edit" cost.
- **`ThumbnailMigration`** (new, run once at app launch, guarded by a
  `UserDefaults` flag):
  1. If legacy `moments.json` / `prompt_memories.json` contain inline `thumbnailData`,
     read them with `JSONSerialization` (not the model decoder).
  2. For each entry, base64-decode `thumbnailData` and write `<id>.jpg` to the
     thumbnails directory (skip if file already exists).
  3. Rewrite the JSON files without the `thumbnailData` field (metadata-only).
  4. Set the migration-done flag.
  - Idempotent and resumable: re-running only writes missing files.
  - Runs before the first `loadMoments()` that the new model decoder sees.

### 4. Feed renders lazily

- New `AsyncThumbnail(id: UUID, targetPixels: CGFloat)` SwiftUI view:
  - Shows a neutral placeholder immediately.
  - Loads `ThumbnailStore.shared.feedImage(for:targetPixels:)` in a `Task`
    (off main thread); assigns the result on the main actor when ready.
  - Reuses cached results instantly on re-appear.
- Replace `Image(uiImage: …thumbnail)` with `AsyncThumbnail` **only in the hot feed
  cards**: `DayClusterCard` (line ~326), `PromptMemoryCard` (the photo grid, lines
  ~254–410), and `PhotoGridCell` (change it to take an `id: UUID` instead of
  `thumbnail: UIImage?`).
- Viewer, share, and map components keep the synchronous `.thumbnail` (full-decode)
  path — they show only a few images at a time.

### 5. Pagination rewritten

Replace Cursor's geometry/accumulation logic entirely.

- State: `@State private var visibleRowCount = pageSize` (rows, not moments;
  `pageSize` ≈ 8).
- Feed renders `memoryTimelineRows.prefix(visibleRowCount)`.
- **Auto-load:** an invisible sentinel view at the bottom of the `LazyVStack` with
  `.onAppear { loadMore() }`. This is the standard reliable infinite-scroll pattern —
  no scroll-offset math. `loadMore()` increments `visibleRowCount` by `pageSize`
  (clamped to total), with a guard against double-firing.
- **Button fallback:** "Load older memories" shown only when `hasMore` **and** the
  list is too short to scroll (so the sentinel might not appear). Reuses the cheap
  `canScroll` metric for visibility only — never to drive auto-load.
- `hasMore = visibleRowCount < memoryTimelineRows.count`.
- The "The Beginning…" footer renders only when `!hasMore`.
- Reset `visibleRowCount` to `pageSize` when the underlying data set changes
  meaningfully (e.g. counts change), clamped to total.

### 6. Cleanup

- Remove the leftover Cursor instrumentation from `HomeViewModel`:
  the `agentDebugLog(...)` method, all its call sites, and the
  `.cursor/debug-0ff6b2.log` writes.
- Keep Cursor's `mapDaySections` caching (`refreshMapDaySections` in the didSets) —
  that is a legitimate optimization and is retained.

## Data Flow

**Launch:** migration (once) → `loadMoments()` decodes metadata only → feed shows
first page → `AsyncThumbnail` cells decode downsampled images on demand off-main →
`NSCache` bounds memory.

**Capture/import:** new `Moment` caches image in memory → added to `moments` →
`didSet` → `saveMoments` writes metadata JSON + `persistIfNeeded` writes `<id>.jpg`.

**Scroll down:** bottom sentinel `.onAppear` → `loadMore()` grows `visibleRowCount`
→ new rows render → their `AsyncThumbnail`s load lazily.

## Error Handling

- Missing/corrupt disk file → `fullImage`/`feedImage` return nil → placeholder shown
  (same as the existing `UIImage(systemName: "photo")!` fallback). No crash.
- Migration failure on a single entry → log + skip that entry; flag not set until the
  pass completes, so it retries next launch.
- Off-main decode failures are swallowed into the placeholder path.

## Testing

- **ThumbnailStore:** store → `fullImage` round-trips; `feedImage` returns a
  downsampled image within target pixels; `remove` deletes file + cache; missing id
  returns nil.
- **Migration:** given a legacy JSON blob with inline `thumbnailData`, produces
  `<id>.jpg` files and metadata-only JSON; idempotent on re-run; sets flag.
- **Model:** decoding metadata-only JSON yields a `Moment` whose `thumbnail` resolves
  via the store; encoding writes no image bytes.
- **Pagination (logic):** `hasMore`, `loadMore` clamping, and reset-on-data-change
  behave correctly for various row counts.
- **Manual/simulator:** verify scroll smoothness, that load-more works both by
  scrolling and via the button fallback, and that existing photos survive migration.
  (See memory: verify UI by temporarily routing the app entry point; trust
  `xcodebuild` over SourceKit diagnostics.)

## Risks / Notes

- Single biggest risk is the model API change touching many files; mitigated by
  keeping `thumbnail: UIImage` as a computed accessor so call sites are unchanged.
- Migration must run before any new-model decode of the legacy files; it reads raw
  JSON via `JSONSerialization` so it does not depend on the changed `Codable`.
- SpriteKit texture limits are unrelated here but downsampling in `feedImage` also
  guards against oversized bitmaps in the feed.
