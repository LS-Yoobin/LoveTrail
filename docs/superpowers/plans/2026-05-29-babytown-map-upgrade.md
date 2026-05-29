# BabyTown Map Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three Bloggo map behaviors to the BabyTown memory map — POI tap → in-app Google web sheet, circular photo previews on individual pins, and a header with gradient shadow + search + country filter.

**Architecture:** Keep the existing UIKit `MKMapView` wrapper (`MemoryMapView`) and its built-in clustering. Add `selectableMapFeatures` for POI taps, a new `MKAnnotationView` subclass for photo pins, a `country` field on `Moment` (backward-compatible Codable), and SwiftUI overlay chrome in `MapView`.

**Tech Stack:** SwiftUI, UIKit, MapKit, WebKit, CoreLocation. Xcode project `BabyTown.xcodeproj`, scheme `BabyTown`.

> **Testing note:** This project has **no XCTest target** and the changes are visual/interactive MapKit + SwiftUI. Per-task verification is therefore **(1) `xcodebuild ... BUILD SUCCEEDED`** and **(2) the listed manual checks in the iOS Simulator**, followed by a commit. Do not add a test target.

**Build/verify command (used in every task):**
```bash
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected tail: `** BUILD SUCCEEDED **`. (SourceKit "Cannot find type … (SourceKit)" live diagnostics are spurious indexer noise; trust the `xcodebuild` result.)

---

### Task 1: EmbeddedWebView (WKWebView wrapper)

**Files:**
- Create: `BabyTown/Components/EmbeddedWebView.swift`

- [ ] **Step 1: Create the web view wrapper**

Create `BabyTown/Components/EmbeddedWebView.swift`:

```swift
import SwiftUI
import WebKit

/// Minimal in-app web view. Loads `url` once and reloads only when `url` changes.
struct EmbeddedWebView: UIViewRepresentable {
    let url: URL

    final class Coordinator {
        var lastRequestedURL: URL?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastRequestedURL != url else { return }
        context.coordinator.lastRequestedURL = url
        webView.load(URLRequest(url: url))
    }
}
```

- [ ] **Step 2: Add the file to the Xcode target**

The project uses a standard target membership. Confirm the new file is included in the `BabyTown` target (Xcode usually auto-adds files under the synced group; if using a project that lists sources explicitly, ensure it compiles in Step 3).

- [ ] **Step 3: Build**

Run the build/verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Components/EmbeddedWebView.swift
git commit -m "feat(map): add EmbeddedWebView WKWebView wrapper"
```

---

### Task 2: POIInfoSheet (web modal content)

**Files:**
- Create: `BabyTown/Components/POIInfoSheet.swift`
- Depends on: `EmbeddedWebView` (Task 1), `BabyTownTheme`

- [ ] **Step 1: Create the sheet**

Create `BabyTown/Components/POIInfoSheet.swift`:

```swift
import SwiftUI
import CoreLocation

/// Pull-up sheet shown when a user taps an Apple Maps POI. Loads a Google search
/// for the place name + reverse-geocoded city in an in-app web view.
struct POIInfoSheet: View {
    let placeName: String
    let coordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss
    @State private var resolvedCity: String?
    @State private var searchReady = false

    private var displayName: String {
        placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nearby Place" : placeName
    }

    private var googleSearchURL: URL {
        var query = displayName
        if let city = resolvedCity { query += " \(city)" }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?q=\(encoded)")
            ?? URL(string: "https://www.google.com/search")!
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(white: 0.5).opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            HStack(alignment: .center) {
                Text(displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            if searchReady {
                EmbeddedWebView(url: googleSearchURL)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                resolvedCity = placemark.locality ?? placemark.administrativeArea
            }
            searchReady = true
        }
    }
}
```

- [ ] **Step 2: Build**

Run the build/verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Components/POIInfoSheet.swift
git commit -m "feat(map): add POIInfoSheet web modal"
```

---

### Task 3: Wire POI selection into the map (Component A complete)

**Files:**
- Modify: `BabyTown/Components/MemoryMapView.swift`
- Modify: `BabyTown/Views/MapView.swift`

- [ ] **Step 1: Enable POI features and add the callback in `MemoryMapView`**

In `BabyTown/Components/MemoryMapView.swift`, add a new stored property after `var isInteractive: Bool = true`:

```swift
    var onSelectPOI: (_ title: String, _ coordinate: CLLocationCoordinate2D) -> Void = { _, _ in }
```

In `makeUIView(context:)`, after `mapView.isPitchEnabled = false`, add:

```swift
        mapView.selectableMapFeatures = [.pointsOfInterest]
```

- [ ] **Step 2: Handle the feature tap in the coordinator**

In `MemoryMapView.Coordinator`, replace the existing `mapView(_:didSelect:)` method with this version (adds the `MKMapFeatureAnnotation` branch first; other branches unchanged):

```swift
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard parent.isInteractive else {
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }
            if let feature = view.annotation as? MKMapFeatureAnnotation {
                parent.onSelectPOI(feature.title ?? "", feature.coordinate)
                mapView.deselectAnnotation(feature, animated: false)
            } else if let annotation = view.annotation as? MemoryMapAnnotation {
                parent.onSelect(annotation.section)
                mapView.deselectAnnotation(annotation, animated: true)
            } else if let cluster = view.annotation as? MKClusterAnnotation {
                let rect = cluster.memberAnnotations.reduce(MKMapRect.null) { rect, annotation in
                    let point = MKMapPoint(annotation.coordinate)
                    return rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
                }
                mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
            }
        }
```

- [ ] **Step 3: Add POI selection state and the sheet in `MapView`**

In `BabyTown/Views/MapView.swift`, add this type just above `struct MapView: View`:

```swift
struct POISelection: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
}
```

Add this state property alongside the other `@State` vars (e.g. after `@State private var showEmptyStatePrompt = true`):

```swift
    @State private var poiSelection: POISelection?
```

- [ ] **Step 4: Pass the callback and present the sheet**

In `MapView.body`, update the `MemoryMapView(...)` call to add the `onSelectPOI` argument (keep the existing `region`, `annotations`, `onSelect` arguments):

```swift
            MemoryMapView(
                region: $region,
                annotations: annotations,
                onSelect: { section in
                    onOpenMemory(section)
                },
                onSelectPOI: { title, coordinate in
                    poiSelection = POISelection(title: title, coordinate: coordinate)
                }
            )
            .ignoresSafeArea()
```

Attach a sheet modifier to the outer `ZStack` (add it next to `.onAppear { ... }` at the end of the `ZStack`):

```swift
        .sheet(item: $poiSelection) { selection in
            POIInfoSheet(placeName: selection.title, coordinate: selection.coordinate)
        }
```

- [ ] **Step 5: Build**

Run the build/verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manual verification (Simulator)**

Open the map (pull down on the home feed). Tap an Apple Maps POI (e.g. a labeled restaurant/park). Expected: a bottom sheet rises with a drag handle, the place name, a "Done" button, and a Google search web view for that place. "Done" dismisses it; the POI is no longer highlighted afterward.

- [ ] **Step 7: Commit**

```bash
git add BabyTown/Components/MemoryMapView.swift BabyTown/Views/MapView.swift
git commit -m "feat(map): open web sheet when tapping Apple Maps POIs"
```

---

### Task 4: Photo-preview markers for individual pins (Component B complete)

**Files:**
- Create: `BabyTown/Components/MemoryPhotoMarkerView.swift`
- Modify: `BabyTown/Components/MemoryMapView.swift`

- [ ] **Step 1: Create the photo marker view**

Create `BabyTown/Components/MemoryPhotoMarkerView.swift`:

```swift
import MapKit
import UIKit

/// Annotation view for an individual memory pin: a circular photo thumbnail in a
/// white-ringed accent circle, with the place-name pill below. Clusters use the
/// existing `MemoryMapMarkerAnnotationView` count marker instead.
final class MemoryPhotoMarkerView: MKAnnotationView {

    private static let circleDiameter: CGFloat = 46
    private static let imageDiameter: CGFloat = 40
    private static let ringWidth: CGFloat = 2
    private static let fillColor = UIColor(red: 1.0, green: 0.4, blue: 0.5, alpha: 1.0)
    private static let pillMaxWidth: CGFloat = 148
    private static let pillHorizontalPadding: CGFloat = 10
    private static let pillVerticalPadding: CGFloat = 5
    private static let pillBelowSpacing: CGFloat = 4

    private let circleView = UIView()
    private let imageView = UIImageView()
    private let glyphView = UIImageView()
    private let placeNamePill = UIView()
    private let placeNameLabel = UILabel()

    override var annotation: MKAnnotation? {
        didSet { applyContent() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "memoryCluster"
        displayPriority = .required
        clipsToBounds = false
        canShowCallout = false
        setupViews()
        applyContent()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let d = Self.circleDiameter
        frame = CGRect(x: 0, y: 0, width: d, height: d)
        centerOffset = CGPoint(x: 0, y: -d / 2)

        circleView.frame = CGRect(x: 0, y: 0, width: d, height: d)
        circleView.backgroundColor = Self.fillColor
        circleView.layer.cornerRadius = d / 2
        circleView.layer.borderColor = UIColor.white.cgColor
        circleView.layer.borderWidth = Self.ringWidth
        circleView.layer.masksToBounds = true

        let img = Self.imageDiameter
        imageView.frame = CGRect(x: (d - img) / 2, y: (d - img) / 2, width: img, height: img)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = img / 2
        imageView.layer.masksToBounds = true

        glyphView.frame = circleView.bounds
        glyphView.image = UIImage(
            systemName: "heart.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        )
        glyphView.tintColor = .white
        glyphView.contentMode = .center

        circleView.addSubview(glyphView)
        circleView.addSubview(imageView)
        addSubview(circleView)

        placeNamePill.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        placeNamePill.isHidden = true
        placeNamePill.isUserInteractionEnabled = false

        placeNameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        placeNameLabel.textColor = .white
        placeNameLabel.textAlignment = .center
        placeNameLabel.numberOfLines = 1
        placeNameLabel.lineBreakMode = .byTruncatingTail

        placeNamePill.addSubview(placeNameLabel)
        addSubview(placeNamePill)
    }

    private func applyContent() {
        guard let memory = annotation as? MemoryMapAnnotation else {
            imageView.image = nil
            imageView.isHidden = true
            glyphView.isHidden = false
            placeNamePill.isHidden = true
            return
        }

        if let thumbnail = memory.section.moments.first?.thumbnail {
            imageView.image = thumbnail
            imageView.isHidden = false
            glyphView.isHidden = true
        } else {
            imageView.image = nil
            imageView.isHidden = true
            glyphView.isHidden = false
        }

        let text = memory.section.placeDisplay
        placeNameLabel.text = text
        placeNamePill.isHidden = text.isEmpty
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutPlaceNamePill()
    }

    private func layoutPlaceNamePill() {
        guard !placeNamePill.isHidden, placeNameLabel.text != nil else { return }

        let maxLabelWidth = Self.pillMaxWidth - Self.pillHorizontalPadding * 2
        let measured = placeNameLabel.sizeThatFits(
            CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude)
        )
        let labelWidth = min(measured.width, maxLabelWidth)
        let pillWidth = labelWidth + Self.pillHorizontalPadding * 2
        let pillHeight = measured.height + Self.pillVerticalPadding * 2

        placeNamePill.bounds.size = CGSize(width: pillWidth, height: pillHeight)
        placeNamePill.layer.cornerRadius = pillHeight / 2

        placeNameLabel.frame = CGRect(
            x: Self.pillHorizontalPadding,
            y: Self.pillVerticalPadding,
            width: labelWidth,
            height: measured.height
        )

        placeNamePill.center = CGPoint(
            x: circleView.frame.midX,
            y: circleView.frame.maxY + Self.pillBelowSpacing + pillHeight / 2
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        placeNamePill.isHidden = true
        placeNameLabel.text = nil
    }
}
```

- [ ] **Step 2: Register the new view and route it in the coordinator**

In `BabyTown/Components/MemoryMapView.swift` `makeUIView`, replace the four `mapView.register(...)` lines with:

```swift
        mapView.register(
            MemoryPhotoMarkerView.self,
            forAnnotationViewWithReuseIdentifier: "MemoryPin"
        )
        mapView.register(
            MemoryMapMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: "MemoryCluster"
        )
        mapView.register(
            MemoryMapMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
```

Replace the coordinator's `mapView(_:viewFor:)` method with:

```swift
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MemoryCluster",
                    for: annotation
                ) as? MemoryMapMarkerAnnotationView
                    ?? MemoryMapMarkerAnnotationView(annotation: annotation, reuseIdentifier: "MemoryCluster")
                view.annotation = annotation
                return view
            } else if annotation is MemoryMapAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MemoryPin",
                    for: annotation
                ) as? MemoryPhotoMarkerView
                    ?? MemoryPhotoMarkerView(annotation: annotation, reuseIdentifier: "MemoryPin")
                view.annotation = annotation
                return view
            }
            return nil
        }
```

- [ ] **Step 3: Build**

Run the build/verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual verification (Simulator)**

Open the map with several memories that have locations. Expected: individual pins show a circular photo thumbnail with a white ring and the place-name pill below. Zoom out until nearby pins merge — they collapse into the existing count cluster marker (no photo on clusters). Zoom back in — photos reappear. Tapping an individual pin still opens its memory; tapping a cluster zooms in.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Components/MemoryPhotoMarkerView.swift BabyTown/Components/MemoryMapView.swift
git commit -m "feat(map): show photo thumbnails on individual memory pins"
```

---

### Task 5: Add `country` to the Moment model

**Files:**
- Modify: `BabyTown/Models/Moment.swift`

- [ ] **Step 1: Add the stored property and init parameter**

In `BabyTown/Models/Moment.swift`, add the property after `var isPlaceNameUserSet: Bool`:

```swift
    var country: String?
```

In the memberwise `init(...)`, add `country: String? = nil` as the last parameter (after `isPlaceNameUserSet: Bool = false`) and assign it in the body:

```swift
        self.country = country
```

- [ ] **Step 2: Add the coding key**

In `enum CodingKeys`, add `country` to the case list (e.g. after `isPlaceNameUserSet`):

```swift
        case id, dateTaken, assetIdentifier, thumbnailData, placeName, caption, voiceNotePath, promptText, isPinned, pinnedAt, isLocked, unlockTime, latitude, longitude, isAddedFromOnThisDay, isPlaceNameUserSet, country
```

- [ ] **Step 3: Decode and encode it (backward compatible)**

In `init(from decoder:)`, after the `isPlaceNameUserSet` decode line, add:

```swift
        country = try container.decodeIfPresent(String.self, forKey: .country)
```

In `func encode(to encoder:)`, after the `isPlaceNameUserSet` encode line, add:

```swift
        try container.encodeIfPresent(country, forKey: .country)
```

- [ ] **Step 4: Build**

Run the build/verify command. Expected: `** BUILD SUCCEEDED **`. (All existing `Moment(...)` call sites still compile because `country` has a default value.)

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Models/Moment.swift
git commit -m "feat(model): add backward-compatible country field to Moment"
```

---

### Task 6: Resolve country on moment creation

**Files:**
- Modify: `BabyTown/Services/LocationNameResolver.swift`
- Modify: `BabyTown/Services/MomentFactory.swift`

- [ ] **Step 1: Add a combined name+country resolver**

In `BabyTown/Services/LocationNameResolver.swift`, add a country cache next to the existing `cache` property:

```swift
    private var countryCache: [String: String?] = [:]
```

Add these methods inside the class (e.g. after the existing private `reverseGeocode(_ location:)`):

```swift
    /// Resolve display name and country in a single geocode call (both cached).
    func resolveNameAndCountry(from location: CLLocation) async -> (name: String?, country: String?) {
        let key = cacheKey(for: location)
        if let name = cache[key], let country = countryCache[key] {
            return (name, country)
        }

        let geocoder = CLGeocoder()
        do {
            let placemark = try await geocoder.reverseGeocodeLocation(location).first
            let name = placemark.flatMap { Self.buildDisplayName(from: $0) }
            let country = placemark?.country
            cache[key] = name
            countryCache[key] = country
            return (name, country)
        } catch {
            cache[key] = nil
            countryCache[key] = nil
            return (nil, nil)
        }
    }

    /// Resolve just the country for a coordinate (cached, shares the geocode above).
    func country(from coordinate: CLLocationCoordinate2D) async -> String? {
        await resolveNameAndCountry(
            from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ).country
    }
```

- [ ] **Step 2: Populate country in `MomentFactory`**

In `BabyTown/Services/MomentFactory.swift`, in `createMoments(from:)`, replace the per-moment resolution block. Find:

```swift
            let asset = assets[index]
            let dateTaken = asset.creationDate ?? Date()
            let placeName = await locationResolver.resolve(from: asset)
            
            // Extract location coordinates from asset
            let latitude = asset.location?.coordinate.latitude
            let longitude = asset.location?.coordinate.longitude

            moments.append(Moment(
                id: UUID(),
                dateTaken: dateTaken,
                assetIdentifier: asset.localIdentifier,
                thumbnail: thumbnail,
                placeName: placeName,
                latitude: latitude,
                longitude: longitude
            ))
```

Replace it with:

```swift
            let asset = assets[index]
            let dateTaken = asset.creationDate ?? Date()

            // Extract location coordinates from asset
            let latitude = asset.location?.coordinate.latitude
            let longitude = asset.location?.coordinate.longitude

            var placeName: String? = nil
            var country: String? = nil
            if let location = asset.location {
                let details = await locationResolver.resolveNameAndCountry(from: location)
                placeName = details.name
                country = details.country
            }

            moments.append(Moment(
                id: UUID(),
                dateTaken: dateTaken,
                assetIdentifier: asset.localIdentifier,
                thumbnail: thumbnail,
                placeName: placeName,
                latitude: latitude,
                longitude: longitude,
                country: country
            ))
```

- [ ] **Step 3: Build**

Run the build/verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Services/LocationNameResolver.swift BabyTown/Services/MomentFactory.swift
git commit -m "feat(map): resolve and store country when creating moments"
```

---

### Task 7: Country list + lazy backfill in HomeViewModel

**Files:**
- Modify: `BabyTown/ViewModels/HomeViewModel.swift`

- [ ] **Step 1: Add a resolver, backfill guard, and the countries list**

In `BabyTown/ViewModels/HomeViewModel.swift`, add these stored properties near the other private properties (e.g. after `private var cancellables = Set<AnyCancellable>()`):

```swift
    private let locationResolver = LocationNameResolver()
    private var isBackfillingCountries = false
```

Add this computed property (e.g. near `availableYears()`):

```swift
    var availableCountries: [String] {
        let names = moments.compactMap { moment -> String? in
            guard let country = moment.country?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !country.isEmpty else { return nil }
            return country
        }
        return Set(names).sorted()
    }
```

- [ ] **Step 2: Add the throttled, resumable backfill**

Add this method to `HomeViewModel`:

```swift
    /// Fill `country` for legacy moments that have coordinates but no country yet.
    /// Throttled to respect CLGeocoder limits; batches one save at the end.
    func backfillCountriesIfNeeded() {
        guard !isBackfillingCountries else { return }

        let targets = moments.filter { $0.country == nil && $0.location != nil }
        guard !targets.isEmpty else { return }

        isBackfillingCountries = true
        Task { @MainActor in
            defer { isBackfillingCountries = false }

            var updates: [UUID: String] = [:]
            for moment in targets {
                guard let coordinate = moment.location?.coordinate else { continue }
                if let country = await locationResolver.country(from: coordinate) {
                    updates[moment.id] = country
                }
                // ~50 requests/minute ceiling for CLGeocoder.
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }

            guard !updates.isEmpty else { return }
            var newMoments = moments
            for index in newMoments.indices {
                if let country = updates[newMoments[index].id] {
                    newMoments[index].country = country
                }
            }
            moments = newMoments
        }
    }
```

- [ ] **Step 3: Build**

Run the build/verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/ViewModels/HomeViewModel.swift
git commit -m "feat(map): expose availableCountries and lazy country backfill"
```

---

### Task 8: Map header chrome — gradient, search, country filter (Component C complete)

**Files:**
- Modify: `BabyTown/Views/MapView.swift`

- [ ] **Step 1: Add filter state**

In `BabyTown/Views/MapView.swift`, add these `@State` properties alongside the others:

```swift
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var selectedCountry: String?
```

- [ ] **Step 2: Apply country + search filtering when building annotations**

Replace the existing `updateAnnotations()` method with:

```swift
    private func updateAnnotations() {
        let base: [DaySection]
        if selectedYear == 0 {
            base = viewModel.memoriesWithLocation()
        } else {
            base = viewModel.memories(forYear: selectedYear)
        }

        let filtered = base.filter { section in
            matchesCountry(section) && matchesSearch(section)
        }
        annotations = filtered.map { MemoryMapAnnotation(section: $0) }
    }

    private func matchesCountry(_ section: DaySection) -> Bool {
        guard let selectedCountry else { return true }
        return section.moments.contains { $0.country == selectedCountry }
    }

    private func matchesSearch(_ section: DaySection) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        let place = (section.placeName ?? "").lowercased()
        let country = section.moments.compactMap { $0.country }.joined(separator: " ").lowercased()
        let date = section.timeDisplay.lowercased()
        return place.contains(query) || country.contains(query) || date.contains(query)
    }
```

- [ ] **Step 3: Add the gradient shadow + search/filter controls to the top overlay**

In `MapView.body`, replace the top-controls block — the `VStack(alignment: .leading, spacing: 12) { ... }` that contains the back button and year chips — with this version (adds the trailing search button + country menu row and a gradient background):

```swift
            // Top controls (map visible behind)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Button {
                        onDismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isSearchActive.toggle() }
                        if !isSearchActive {
                            searchText = ""
                            updateAnnotations()
                        }
                    } label: {
                        mapCircleIcon(isSearchActive ? "xmark" : "magnifyingglass", filled: isSearchActive)
                    }

                    Menu {
                        Button("All Countries") {
                            selectedCountry = nil
                            updateAnnotations()
                            centerMapOnMemories()
                        }
                        ForEach(viewModel.availableCountries, id: \.self) { country in
                            Button(country) {
                                selectedCountry = country
                                updateAnnotations()
                                centerMapOnMemories()
                            }
                        }
                    } label: {
                        mapCircleIcon(
                            selectedCountry == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill",
                            filled: selectedCountry != nil
                        )
                    }
                }

                if isSearchActive {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.black.opacity(0.5))
                        TextField("Search place, country, or date", text: $searchText)
                            .foregroundStyle(.black)
                            .autocorrectionDisabled()
                            .onChange(of: searchText) { _, _ in updateAnnotations() }
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                updateAnnotations()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.black.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    )
                }

                if !availableYears.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableYears, id: \.self) { year in
                                YearFilterChip(
                                    title: year == 0 ? "All" : String(year),
                                    isSelected: year == selectedYear
                                ) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedYear = year
                                        updateAnnotations()
                                        centerMapOnMemories()
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.45), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
```

- [ ] **Step 4: Add the circular icon helper**

Add this method to `MapView` (e.g. just before `private func setupMapData()`):

```swift
    private func mapCircleIcon(_ systemName: String, filled: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(filled ? BabyTownTheme.accent : .black)
        }
    }
```

- [ ] **Step 5: Trigger backfill on appear**

In `MapView`, update the `.onAppear` to also kick off the backfill:

```swift
        .onAppear {
            setupMapData()
            showEmptyStatePrompt = true
            viewModel.backfillCountriesIfNeeded()
        }
```

- [ ] **Step 6: Build**

Run the build/verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Manual verification (Simulator)**

Open the map. Expected:
- A subtle black gradient sits behind the top controls so the white buttons/chips stay legible over the map.
- Tapping the magnifying-glass reveals a search field; typing a place/country/date substring filters the visible pins live; clearing or closing search restores all pins.
- The filter (funnel) menu lists "All Countries" plus each resolved country; selecting one filters pins to that country and recenters; the icon fills when a country is active.
- Year chips still work and compose with country + search.
- On first open with legacy data, countries populate in the menu over the next ~minute as backfill runs; relaunching does not re-geocode already-filled moments.

- [ ] **Step 8: Commit**

```bash
git add BabyTown/Views/MapView.swift
git commit -m "feat(map): add header gradient, search, and country filter"
```

---

## Self-Review

**Spec coverage:**
- A. POI → web modal → Tasks 1, 2, 3. ✓
- B. Photo markers for individual pins (clusters unchanged) → Task 4. ✓
- C. Header gradient + search + country filter → Tasks 5 (model), 6 (populate), 7 (VM list + backfill), 8 (UI). ✓
- Backward-compatible Codable for `country` → Task 5. ✓
- Error handling (geocode/thumbnail/web fallbacks): POI uses name-only when city geocode fails (Task 2); pin falls back to heart glyph when no thumbnail (Task 4); backfill skips on failure leaving `country == nil` (Task 7); WKWebView shows its own error page (Task 1). ✓

**Type consistency:**
- `onSelectPOI(_ title:_ coordinate:)` defined in Task 3 (MemoryMapView) and used in Task 3 (MapView) with matching signature. ✓
- `POISelection(title:coordinate:)` defined and used in Task 3; consumed by `POIInfoSheet(placeName:coordinate:)` (defined Task 2). ✓
- `MemoryPhotoMarkerView` defined Task 4, registered/dequeued under "MemoryPin" in Task 4. ✓
- `resolveNameAndCountry(from:)` and `country(from:)` defined Task 6, used in Tasks 6 (MomentFactory) and 7 (HomeViewModel). ✓
- `Moment(..., country:)` parameter defined Task 5, used Task 6. ✓
- `availableCountries` / `backfillCountriesIfNeeded()` defined Task 7, used Task 8. ✓
- `updateAnnotations()` / `centerMapOnMemories()` are existing methods; redefined `updateAnnotations()` in Task 8 keeps the same name. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code. ✓
