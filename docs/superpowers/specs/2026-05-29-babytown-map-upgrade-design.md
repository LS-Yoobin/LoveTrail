# BabyTown Map Upgrade — Design

**Date:** 2026-05-29
**Status:** Approved (pending spec review)
**Author:** Justin Seo (with Claude)

## Summary

Bring three Bloggo "Places Visited" map behaviors to the BabyTown memory map:

- **A. POI tap → pull-up web modal.** Tapping an Apple Maps point of interest (restaurant, park, etc.) opens a bottom sheet with an in-app web view showing a Google search for that place.
- **B. Photo-preview markers for individual memories.** Individual (non-clustered) memory pins display a circular photo thumbnail. Clusters remain plain count markers.
- **C. Map header chrome.** A black gradient shadow behind the top controls, an expandable search field, and a country filter menu in the top-right.

## Decisions & rationale

- **Keep the UIKit `MKMapView`** (`MemoryMapView`), do **not** migrate to SwiftUI `Map`.
  - BabyTown's map relies on MKMapView's **built-in clustering**, which scales as the moment count grows — the central longevity concern for this app. SwiftUI `Map` would require hand-rolled clustering (regression risk, more to maintain).
  - Bloggo itself uses the UIKit `selectableMapFeatures` + `MKMapFeatureAnnotation` approach for POIs (in `EditPlaceStopNameSheet`), so this path is proven.
- **Add a real, cached `country` to `Moment`** (rather than skipping the filter or filtering by place name) so the country filter is faithful to Bloggo and reusable by future features. Capturing country is free — it comes from the same placemark `LocationNameResolver` already fetches.

## Out of scope

- Migrating the map to SwiftUI `Map`.
- Category filters / category badges on markers (Bloggo has these; BabyTown has no category data).
- Changing clustering behavior or the cluster marker's appearance.
- Photo previews on cluster markers (clusters stay as count markers by explicit decision).

---

## Component A — POI tap → pull-up web modal

### Behavior
1. User taps an Apple Maps POI on the map.
2. A bottom sheet rises (`.presentationDetents([.medium, .large])`) with a drag handle, a header (place name + "Done"), and an in-app web view.
3. The web view loads `https://www.google.com/search?q=<place name> <city>`, where `<city>` is reverse-geocoded from the POI coordinate.
4. Dismissing the sheet clears the POI selection.

### Implementation
- **`MemoryMapView` (modified):**
  - `makeUIView`: `mapView.selectableMapFeatures = [.pointsOfInterest]`.
  - Add closure property: `var onSelectPOI: (_ title: String, _ coordinate: CLLocationCoordinate2D) -> Void`.
  - Coordinator `mapView(_:didSelect:)`: if `view.annotation is MKMapFeatureAnnotation`, call `onSelectPOI(feature.title ?? "", feature.coordinate)` then `mapView.deselectAnnotation(_, animated: false)`. Existing `MemoryMapAnnotation` and `MKClusterAnnotation` branches are unchanged.
- **`POISelection` (new, in `MapView.swift` or its own small file):** `struct POISelection: Identifiable { let id = UUID(); let title: String; let coordinate: CLLocationCoordinate2D }`.
- **`MapView` (modified):** `@State private var poiSelection: POISelection?`; pass `onSelectPOI:` into `MemoryMapView`; present `.sheet(item: $poiSelection) { POIInfoSheet(title:coordinate:) }`.
- **`POIInfoSheet` (new):** drag handle + header + `EmbeddedWebView`. Resolves city with a one-shot `CLGeocoder.reverseGeocodeLocation` in `.task`, then builds the Google search URL. Styled with BabyTown theme tokens (`BabyTownTheme`).
- **`EmbeddedWebView` (new):** `UIViewRepresentable` wrapping `WKWebView`, ported from Bloggo's `GoogleSearchEmbeddedWebView`. Loads a URL; reloads only when the URL changes.

### Interface contract
`POIInfoSheet(title: String, coordinate: CLLocationCoordinate2D)` — self-contained; depends only on `EmbeddedWebView` and `CLGeocoder`. Knows nothing about moments.

---

## Component B — Photo-preview markers (individual only)

### Behavior
- An individual memory pin renders a circular photo (the section's first moment's thumbnail) in a white-ringed circle, with the existing place-name pill below it.
- When pins collapse into a cluster, the cluster shows the existing count marker (unchanged). No photo on clusters.
- Tapping an individual pin behaves exactly as today (`onSelect(section)`); tapping a cluster zooms in (unchanged).

### Implementation
- **Individual pin view (new or refactor of `MemoryMapMarkerAnnotationView`):** a custom `MKAnnotationView` subclass:
  - 46pt circle (accent fill) containing a 40pt `UIImageView` of `annotation.section.moments.first?.thumbnail`, clipped to a circle with a 2px white ring.
  - Falls back to the current heart glyph / accent fill when no thumbnail exists.
  - Reuses the existing place-name pill layout below the circle.
  - Sets `clusteringIdentifier = "memoryCluster"` so MapKit clustering is preserved.
  - Implements `prepareForReuse()` to clear the image (avoid recycled-cell image bleed).
- **Cluster view:** keep the existing `MKMarkerAnnotationView`-based count marker (the current `MemoryMapMarkerAnnotationView` cluster branch). Registration in `MemoryMapView.makeUIView` updated so individual vs. cluster reuse identifiers map to the right view classes.
- Thumbnails are already resident `UIImage`s on `Moment`; no async image loading required.

### Interface contract
The annotation view reads only `MemoryMapAnnotation.section` (existing). No new dependencies.

---

## Component C — Header chrome (shadow + search + country filter)

### Behavior
- A black gradient (`.black.opacity(0.45)` → clear, top→bottom) sits behind the top control strip so white controls stay legible over the map.
- A search affordance (magnifying glass) expands into a text field; typing filters the visible memory pins by place name, country, or date text.
- A country filter menu (top-right, `line.3.horizontal.decrease.circle`, filled when a country is active) lists "All Countries" + each distinct country. Selecting one filters the visible memory pins to that country.
- Year chips (existing) continue to work and compose with the country filter and search.

### Implementation
- **`Moment` (modified):** add `var country: String?`.
  - Add `country` to `CodingKeys`; decode with `decodeIfPresent` and encode with `encodeIfPresent`. Backward compatible — existing `moments.json` loads with `country == nil`.
- **`LocationNameResolver` (modified):** add a method that returns both display name and country (e.g. `resolveDetails(...) -> (name: String?, country: String?)`) from the same placemark (`placemark.country`). Existing name-only API stays for callers that don't need country.
- **`MomentFactory` (modified):** when creating moments, populate `country` from the resolver (no extra geocode — same placemark/coordinate cache).
- **`HomeViewModel` (modified):**
  - `availableCountries: [String]` — distinct, sorted, non-nil countries across moments (+ prompt memories if they carry coordinates).
  - `backfillCountriesIfNeeded()` — for moments with coordinates but `country == nil`, reverse-geocode via the cached resolver in a **throttled** background `Task` (respect CLGeocoder's ~50 req/min limit; the coordinate-rounded cache means many moments share results), then write the resolved countries back into `moments` (persisted via existing `didSet`). Idempotent and resumable across launches.
- **`MapView` (modified):**
  - Add the gradient background behind the top controls.
  - Add `@State private var searchText: String`, `@State private var isSearchActive: Bool`, `@State private var selectedCountry: String?`.
  - Compute the displayed annotations by filtering memories by selected year (existing), selected country, and search text.
  - Add the search field UI and the country `Menu`.
  - Call `viewModel.backfillCountriesIfNeeded()` on appear.

### Filtering composition
Displayed pins = memories matching **all** active filters: year (existing) AND country (if set) AND search text (if non-empty). Search matches place name, country, or formatted date substring (case-insensitive).

### Interface contract
- `HomeViewModel.availableCountries` and `backfillCountriesIfNeeded()` are the only new VM surface.
- The map view owns its own filter state; the VM exposes data, not UI state.

---

## Data flow

1. **Moment creation** (`MomentFactory`) → `placeName` + `country` resolved from one geocode → stored on `Moment` → persisted.
2. **Map open** → `backfillCountriesIfNeeded()` fills `country` for legacy moments → `availableCountries` updates → country menu populates.
3. **Filter change** (year / country / search) → `MapView` recomputes displayed annotations → `MemoryMapView.updateUIView` diffs and updates pins.
4. **POI tap** → `MemoryMapView` coordinator → `onSelectPOI` → `MapView` sets `poiSelection` → `.sheet` presents `POIInfoSheet` → city geocoded → `EmbeddedWebView` loads Google search.

## Error handling

- **Geocoding failure** (POI city or country backfill): fall back gracefully — POI search uses place name only; backfill leaves `country == nil` (pin still shows under "All Countries", just not under a specific country). No crashes, no blocking UI.
- **Missing thumbnail** on an individual pin: fall back to the existing heart-glyph pin style.
- **Web view load failure:** WKWebView shows its own error page; the sheet remains dismissible via "Done".
- **No coordinates** on a moment: excluded from the map as today.

## Testing / verification

- Build succeeds (`xcodebuild ... BUILD SUCCEEDED`).
- Manual verification on the Map screen:
  - Tapping an Apple Maps POI opens the sheet and loads a Google search for that place; "Done" dismisses and clears selection.
  - Individual memory pins show circular photos; zooming out collapses them into count clusters (no photos on clusters); zooming in restores photos.
  - The top gradient shadow is visible; search filters pins live; the country menu lists real countries and filters pins; year + country + search compose correctly.
  - Relaunch: backfilled countries persist; no duplicate geocoding storm.
- Backward compatibility: an existing `moments.json` (no `country`) loads without error and backfills over time.

## Risks

- **Country backfill cost/throttling** is the only nontrivial piece: large libraries hit CLGeocoder rate limits. Mitigated by the coordinate-rounded cache and throttled, resumable backfill. Acceptable because it runs in the background and degrades gracefully.
