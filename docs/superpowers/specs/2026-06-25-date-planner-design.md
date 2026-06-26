# Spec: Date Planner

**Date:** 2026-06-25
**Phase:** Together (Prelude support is out of scope — deferred)

---

## Overview

A Date Planner feature accessible from the `StickyActionBar` on the Home screen. Couples can create, edit, and browse itineraries for planned dates. Each plan is a Partiful-style single-scroll page with a cover photo hero, date strip, notes, an ordered itinerary of stops, and a map overview. Plans sync between partners via MongoDB. Plans older than 30 days are automatically vaulted unless the couple has Forever unlocked.

---

## Entry Point

A new **"Planner"** secondary pill is added to `StickyActionBar`, positioned immediately after the "Scan" pill. It uses system image `calendar.badge.plus` and calls a new `onPlanner: (() -> Void)?` closure — same optional pattern as `onScan` and `onPrompt`.

`HomeView` wires `onPlanner` to a new `@State private var showPlanner = false` and presents `DatePlannerHubView` as a full-screen sheet.

---

## Navigation Structure

### `DatePlannerHubView`

Full-screen sheet containing:

- **Top tab strip** — two segments: "Plans" and "Log"
- **"+" button** top-right — opens `NewPlanSheet` to create a plan

**Plans tab:**
- Shows the currently selected plan rendered as `DatePlanDetailView` (the Partiful scroll).
- A **plan switcher** lives at the very top — a horizontally scrollable strip of plan name chips. The active chip is highlighted with `BabyTownTheme.accent`. Tapping a chip switches the displayed plan.
- If no plans exist: an empty state card with a soft illustration and "Plan your next date" prompt, plus a large "+" CTA.

**Log tab:**
- Chronological list of all plans, newest first.
- Each row: cover photo thumbnail, plan title, date, stop count badge.
- Past plans (date has passed): visually subdued — slightly desaturated cover, a small "Past" pill label.
- Vaulted plans: blurred cover photo + lock icon overlay + "Locked" label. Tapping shows `PlanVaultSheet`.
- Active/upcoming plans: full color.

**Last-selected plan persistence:**
On every plan switch, the selected plan's `UUID` is written to `UserDefaults` under key `plannerLastSelectedPlanID`. On hub load, this key is read first; if the plan still exists it is pre-selected, otherwise the most recent plan is shown.

---

## Creating a Plan — `NewPlanSheet`

A bottom sheet (`.presentationDetents([.medium])`) with:

1. A text field: "Name this date…" (placeholder), bound to `title`. Character limit: 40.
2. An inline `.graphical` `DatePicker` for picking the planned date. Min date: today. No max.
3. An optional time toggle — off by default. When toggled on, reveals a `.hourAndMinute` picker row.
4. A **"Create Plan"** primary button (disabled until title is non-empty).

On confirm: a new `DatePlan` is created, saved locally and queued for sync, then the hub switches to Plans tab with the new plan selected and opened.

---

## Plan Detail View — `DatePlanDetailView`

A single `ScrollView` with `PlannerBackgroundView` as the background. Sections top to bottom:

### 1. Hero
- Full-bleed cover photo, height 280pt, `clipped`.
- If no cover photo: `PlannerBackgroundView` fills the hero area with a centered camera icon overlay and "Add cover photo" label.
- Gradient overlay (transparent → black 55%) along the bottom 120pt.
- Plan title in `.system(size: 28, weight: .bold, design: .serif)`, white, bottom-left of hero, 16pt inset.
- A pencil `Button` top-right corner (16pt inset from safe area) toggles `isEditing` mode.
- Tapping the hero in edit mode opens `ImagePickerSheet` (Photos library picker, no scan).

### 2. Date Strip
- A rounded card (`.ultraThinMaterial` background) with a calendar icon, the date in `"EEEE, MMMM d"` format, and — if time is set — the time in `"h:mm a"` format.
- Tapping in edit mode opens a sheet containing an inline `.graphical` `DatePicker` plus the optional time toggle. Mirrors `NewPlanSheet` picker UI.

### 3. Notes
- A soft card with the notes text. If empty and not editing: "Add notes, vibes, or anything you're excited about" placeholder in secondary color.
- Tapping in edit mode opens `NoteEditorSheet` (full-screen text editor, same pattern as `ProfileNoteEditorSheet`).

### 4. Itinerary
Section header: "Itinerary" in small caps uppercase.

Each stop is a `ItineraryStopCard`:
- Leading: a numbered circle badge (accent background, white number).
- Photo thumbnail: 48×48pt rounded rectangle. If no photo: accent-tinted location pin icon.
- Place name in `.system(size: 15, weight: .semibold)`.
- Optional note in `.system(size: 13)` secondary color, 1 line, truncated.
- In edit mode: trailing drag handle (`line.3.horizontal`) for reordering; swipe-to-delete enabled.

Below all stops in edit mode: an **"Add a stop"** button (dashed border pill, accent color) that opens `StopSearchSheet`.

### 5. Map Overview
A fixed-height (220pt) `MKMapView` card (rounded corners 16pt) showing:
- Photo-pin markers for each geolocated stop (uses existing `MemoryPhotoMarkerView` pattern). Marker label shows the stop's order number.
- A `MKPolyline` overlay connecting stops in itinerary order, styled with accent color, line width 2.5pt, dash pattern `[6, 4]`.
- Map is non-interactive (scroll/zoom disabled). Tapping opens a full-screen interactive `PlannerFullMapView`.
- If fewer than 2 geolocated stops exist: map is hidden entirely.

### 6. AI Button (scaffolded)
A floating circle button (48pt diameter, `BabyTownTheme.accentGradient` fill, white sparkle icon) pinned to bottom-right with 20pt inset from safe area. In this release it shows a "Coming soon" toast on tap. The button is always visible, does not scroll with content.

---

## Stop Search Sheet — `StopSearchSheet`

A `.presentationDetents([.large])` sheet with two tabs:

**"Places" tab:**
- A search bar at the top wired to a new `PlannerPlaceSearchViewModel` — wraps existing `MemoryPlaceSearchViewModel` logic (MapKit `MKLocalSearchCompleter`, POI + address results).
- Results list: place name + address subtitle. Tapping a result resolves coordinates via `MKLocalSearch.Request` and creates an `ItineraryStop` with `placeName`, `latitude`, `longitude`. No photo for new place search results (photo remains nil, pin icon shown).
- Empty state: "Search for a restaurant, park, cinema…"

**"Our Moments" tab:**
- A grid (2 columns) of the couple's saved `Moment` objects that have a non-nil `placeName`.
- Each cell: thumbnail photo, place name label, date label.
- Tapping a moment creates an `ItineraryStop` with:
  - `placeName` from `moment.placeName`
  - `latitude` / `longitude` from the moment
  - `photoData`: the moment's `thumbnail` compressed to JPEG at 0.6 quality
  - `note`: the moment's `caption`
  - `momentID`: the moment's `id`
- Search bar at top filters by place name.
- Empty state: "No moments with a saved location yet."

---

## Background — `PlannerBackgroundView`

A pure SwiftUI `View` rendered as `.ignoresSafeArea()` behind all content.

Layers (bottom to top):

1. **Base:** `BabyTownTheme.backgroundGradient` — inherits Pink/Blue theme automatically.
2. **Grid lines:** A `Canvas` drawing horizontal and vertical lines every 60pt, `BabyTownTheme.accent.opacity(0.03)`, line width 0.5pt.
3. **Dashed routes:** 4 diagonal dashed lines across the canvas, drawn as `Path` with `strokeStyle(dash: [6, 8])`, `BabyTownTheme.accent.opacity(0.05)`.
4. **Pin outlines:** 6 `Image(systemName: "mappin")` instances placed at fixed relative positions (expressed as `GeometryReader` fractions), `BabyTownTheme.accent.opacity(0.06)`, font size 14pt, no fill.
5. **Compass rose:** A single `Image(systemName: "safari")` (or `"location.north.line"`) at bottom-left quadrant (~20% x, ~80% y), 72pt, `BabyTownTheme.accent.opacity(0.05)`.

All elements are static — no animation. Zero `@State`, zero timers.

---

## Vault Locking

### Rule
A `DatePlan` is vaulted when both conditions are true:
- `Date().timeIntervalSince(createdAt) > 30 * 24 * 60 * 60`
- `StoreManager.shared.isForeverUnlocked == false`

This is a computed property on `DatePlan`, not a stored field — no migration needed.

```swift
var isVaulted: Bool {
    !StoreManager.shared.isForeverUnlocked
        && Date().timeIntervalSince(createdAt) > 30 * 24 * 60 * 60
}
```

### Log view
Vaulted plans: cover photo replaced with a blurred placeholder, a lock SF Symbol centered, and a "Locked" pill label. Tapping presents `PlanVaultSheet`.

### `PlanVaultSheet`
`.presentationDetents([.medium])` bottom sheet:

- Lock icon (large, accent tint) at top.
- Title: "This date is in the vault"
- Body: "Date plans are kept safe after 30 days. Unlock Forever to relive every date you planned together."
- Primary button: "Unlock Forever" → triggers existing `showForeverPaywall` flow.
- Secondary button: "Later" → dismisses.

No plan is deleted. Vaulted plans remain in the Log indefinitely.

---

## Data Model

### `DatePlan`

```swift
struct DatePlan: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var time: Date?
    var notes: String?
    var coverPhotoData: Data?
    var itinerary: [ItineraryStop]
    let createdByUserID: String
    var createdAt: Date
    var updatedAt: Date

    var isVaulted: Bool {
        !StoreManager.shared.isForeverUnlocked
            && Date().timeIntervalSince(createdAt) > 30 * 24 * 60 * 60
    }

    var isPast: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}
```

### `ItineraryStop`

```swift
struct ItineraryStop: Identifiable, Codable {
    let id: UUID
    var order: Int
    var placeName: String
    var latitude: Double?
    var longitude: Double?
    var momentID: UUID?
    var photoData: Data?
    var note: String?
}
```

---

## `DatePlanStore` Service

New service class (singleton, mirrors `DataPersistenceManager` pattern):

- **Local persistence:** Encodes `[DatePlan]` to JSON, stored in the app's Documents directory as `date_plans.json`.
- **`UserDefaults` key:** `plannerLastSelectedPlanID` — stores the `UUID` string of the last opened plan.
- **MongoDB sync:** On every save (create/update), queues a background push to the `date_plans` collection scoped to `coupleID`. On app launch, fetches the partner's latest changes and merges by `updatedAt` (last-write-wins per plan).
- **CRUD:** `createPlan(_:)`, `updatePlan(_:)`, `deletePlan(id:)`, `allPlans() -> [DatePlan]`.

---

## Sync

MongoDB collection: `date_plans`
Document structure mirrors `DatePlan` (JSON-encoded). Keyed by `coupleID` + `plan.id`.
`coverPhotoData` and `ItineraryStop.photoData` are stored inline as Base64 strings (compressed JPEG at 0.6 quality, max 400×400pt thumbnail before encoding to keep document size manageable).
Sync is optimistic: local write first, background upload, no conflict UI for this release.

---

## Scope Boundaries

- Prelude support: out of scope. `DatePlannerHubView` checks `DataPersistenceManager.shared.isPartnerAccount()` or couple-linked status and shows an "Available once you connect with a partner" empty state for solo users.
- AI button: scaffolded (visible, shows "Coming soon" toast). No Foundation Models integration in this release.
- Notifications (e.g. day-before reminder): out of scope.
- Plan sharing outside the app (share sheet): out of scope.
- Full-screen map (`PlannerFullMapView`) is interactive but read-only — no editing stops from the map view.
