# Date Planner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Date Planner feature accessible from the StickyActionBar — couples create Partiful-style scrollable date itineraries with stops, a map, and cover photos, synced between partners.

**Architecture:** New `DatePlanStore` singleton mirrors `DataPersistenceManager` for local JSON persistence with background MongoDB sync stubs. `DatePlannerHubView` is a full-screen sheet with Plans/Log tabs; `DatePlanDetailView` is the scrollable plan page. `StopSearchSheet` wraps the existing `PlannerPlaceSearchViewModel` (mirrors `MemoryPlaceSearchViewModel`) to add map-pinned itinerary stops.

**Tech Stack:** SwiftUI, MapKit (MKMapView via UIViewRepresentable, MKLocalSearchCompleter), PhotosUI, BabyTownTheme tokens

## Global Constraints

- No dashes (`-`) in any user-facing string, label, placeholder, or button copy — ever
- All colors use `BabyTownTheme.*` tokens; no hardcoded hex or RGB values
- Both Pink and Blue themes must render correctly in all views
- Phase gate: Together only. Hub shows "Available once you connect with a partner" empty state for solo users (check `DataPersistenceManager.shared.isPartnerAccount()`)
- AI button: scaffolded only; shows "Coming soon" toast on tap; no Foundation Models in this release
- `StoreManager.shared.isForeverUnlocked` (computed, `@Published` on `StoreManager`) gates vault

---

## File Map

**New files:**
| Path | Responsibility |
|---|---|
| `BabyTown/Models/DatePlan.swift` | `DatePlan` + `ItineraryStop` Codable structs |
| `BabyTown/Services/DatePlanStore.swift` | Singleton: local JSON CRUD + sync stubs |
| `BabyTown/ViewModels/PlannerPlaceSearchViewModel.swift` | MapKit autocomplete (mirrors `MemoryPlaceSearchViewModel`) |
| `BabyTown/Views/DatePlanner/PlannerBackgroundView.swift` | Static map-aesthetic decorative background |
| `BabyTown/Views/DatePlanner/NewPlanSheet.swift` | Create plan bottom sheet (`.medium` detent) |
| `BabyTown/Views/DatePlanner/PlanVaultSheet.swift` | Locked-plan upsell bottom sheet (`.medium` detent) |
| `BabyTown/Views/DatePlanner/NoteEditorSheet.swift` | Full-screen plain text editor for plan notes |
| `BabyTown/Views/DatePlanner/ItineraryStopCard.swift` | Single stop row component for itinerary list |
| `BabyTown/Views/DatePlanner/PlannerMapView.swift` | Non-interactive MKMapView UIViewRepresentable + full-screen variant |
| `BabyTown/Views/DatePlanner/StopSearchSheet.swift` | Places + Our Moments search tabs |
| `BabyTown/Views/DatePlanner/DatePlanDetailView.swift` | Main scrollable plan page |
| `BabyTown/Views/DatePlanner/DatePlannerHubView.swift` | Top-level hub with Plans/Log tabs |

**Modified files:**
| Path | Change |
|---|---|
| `BabyTown/Components/StickyActionBar.swift` | Add `onPlanner: (() -> Void)?` pill after Scan |
| `BabyTown/Views/HomeView.swift` | Add `@State showPlanner`, wire closure, present hub |

---

## Task 1: Data Models

**Files:**
- Create: `BabyTown/Models/DatePlan.swift`

**Interfaces:**
- Produces: `DatePlan` (Identifiable, Codable), `ItineraryStop` (Identifiable, Codable) — used by all subsequent tasks

- [ ] **Step 1: Create `BabyTown/Models/DatePlan.swift`**

```swift
import Foundation

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

- [ ] **Step 2: Build** — ⌘B in Xcode. Expected: Build Succeeded with no new errors.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/DatePlan.swift
git commit -m "feat: add DatePlan and ItineraryStop models"
```

---

## Task 2: `DatePlanStore` Service

**Files:**
- Create: `BabyTown/Services/DatePlanStore.swift`

**Interfaces:**
- Consumes: `DatePlan`, `ItineraryStop` from Task 1
- Produces: `DatePlanStore.shared` singleton with:
  - `allPlans() -> [DatePlan]`
  - `createPlan(_ plan: DatePlan)`
  - `updatePlan(_ plan: DatePlan)`
  - `deletePlan(id: UUID)`
  - `lastSelectedPlanID: UUID?` (computed, reads UserDefaults)
  - `setLastSelectedPlanID(_ id: UUID?)`

- [ ] **Step 1: Create `BabyTown/Services/DatePlanStore.swift`**

```swift
import Foundation

final class DatePlanStore {
    static let shared = DatePlanStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default
    private let lastSelectedKey = "plannerLastSelectedPlanID"

    private var fileURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("date_plans.json")
    }

    private init() {}

    // MARK: - Last Selected

    var lastSelectedPlanID: UUID? {
        guard let str = UserDefaults.standard.string(forKey: lastSelectedKey) else { return nil }
        return UUID(uuidString: str)
    }

    func setLastSelectedPlanID(_ id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: lastSelectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastSelectedKey)
        }
    }

    // MARK: - CRUD

    func allPlans() -> [DatePlan] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let plans = try? decoder.decode([DatePlan].self, from: data) else {
            return []
        }
        return plans
    }

    func createPlan(_ plan: DatePlan) {
        var plans = allPlans()
        plans.append(plan)
        persist(plans)
        Task { await syncToMongoDB(plan) }
    }

    func updatePlan(_ updated: DatePlan) {
        var plans = allPlans()
        guard let idx = plans.firstIndex(where: { $0.id == updated.id }) else { return }
        plans[idx] = updated
        persist(plans)
        Task { await syncToMongoDB(updated) }
    }

    func deletePlan(id: UUID) {
        var plans = allPlans()
        plans.removeAll { $0.id == id }
        persist(plans)
    }

    // MARK: - Persistence

    private func persist(_ plans: [DatePlan]) {
        guard let data = try? encoder.encode(plans) else { return }
        try? data.write(to: fileURL)
    }

    // MARK: - Sync stubs

    private func syncToMongoDB(_ plan: DatePlan) async {
        // TODO: POST /date_plans with { coupleID, plan } — last-write-wins on updatedAt
    }

    func fetchPartnerChanges() async {
        // TODO: GET /date_plans?coupleID=X — merge by updatedAt per plan id
    }
}
```

- [ ] **Step 2: Build** — ⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Services/DatePlanStore.swift
git commit -m "feat: add DatePlanStore with local JSON persistence and sync stubs"
```

---

## Task 3: `PlannerPlaceSearchViewModel`

**Files:**
- Create: `BabyTown/ViewModels/PlannerPlaceSearchViewModel.swift`

**Interfaces:**
- Produces: `PlannerPlaceSearchViewModel` — `ObservableObject`, `@Published var query: String`, `@Published var suggestions: [PlaceSuggestion]`, `func resolveDetails(for: PlaceSuggestion) async -> CLLocationCoordinate2D?`

- [ ] **Step 1: Create `BabyTown/ViewModels/PlannerPlaceSearchViewModel.swift`**

```swift
import Combine
import CoreLocation
import MapKit

final class PlannerPlaceSearchViewModel: NSObject, ObservableObject {
    @Published var query: String = ""
    @Published var suggestions: [PlaceSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]

        $query
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newQuery in
                guard let self else { return }
                if newQuery.isEmpty {
                    self.suggestions = []
                } else {
                    self.completer.queryFragment = newQuery
                }
            }
            .store(in: &cancellables)
    }

    func resolveDetails(for suggestion: PlaceSuggestion) async -> CLLocationCoordinate2D? {
        guard case .mapKit(let completion) = suggestion.source else { return nil }
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let mapItem = response.mapItems.first else { return nil }
        return mapItem.placemark.coordinate
    }
}

extension PlannerPlaceSearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.map { completion in
            PlaceSuggestion(
                id: "\(completion.title)|\(completion.subtitle)",
                title: completion.title,
                subtitle: completion.subtitle,
                source: .mapKit(completion)
            )
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
```

- [ ] **Step 2: Build** — ⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/ViewModels/PlannerPlaceSearchViewModel.swift
git commit -m "feat: add PlannerPlaceSearchViewModel for stop search autocomplete"
```

---

## Task 4: `PlannerBackgroundView`

**Files:**
- Create: `BabyTown/Views/DatePlanner/PlannerBackgroundView.swift`

**Interfaces:**
- Produces: `PlannerBackgroundView` — zero-state `View`, used as `.background(PlannerBackgroundView().ignoresSafeArea())`

- [ ] **Step 1: Create `BabyTown/Views/DatePlanner/PlannerBackgroundView.swift`**

```swift
import SwiftUI

struct PlannerBackgroundView: View {
    private let pinPositions: [(CGFloat, CGFloat)] = [
        (0.15, 0.20), (0.75, 0.10), (0.50, 0.45),
        (0.90, 0.60), (0.30, 0.75), (0.65, 0.85),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BabyTownTheme.backgroundGradient

                Canvas { ctx, size in
                    // Grid lines every 60pt
                    var x: CGFloat = 0
                    while x <= size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(path, with: .color(BabyTownTheme.accent.opacity(0.03)), lineWidth: 0.5)
                        x += 60
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(path, with: .color(BabyTownTheme.accent.opacity(0.03)), lineWidth: 0.5)
                        y += 60
                    }

                    // Diagonal dashed routes
                    let diagonals: [(CGPoint, CGPoint)] = [
                        (CGPoint(x: 0, y: size.height * 0.20), CGPoint(x: size.width, y: size.height * 0.70)),
                        (CGPoint(x: 0, y: size.height * 0.50), CGPoint(x: size.width, y: size.height * 0.90)),
                        (CGPoint(x: size.width * 0.10, y: 0), CGPoint(x: size.width * 0.80, y: size.height)),
                        (CGPoint(x: size.width * 0.60, y: 0), CGPoint(x: size.width, y: size.height * 0.50)),
                    ]
                    for (from, to) in diagonals {
                        var path = Path()
                        path.move(to: from)
                        path.addLine(to: to)
                        ctx.stroke(
                            path,
                            with: .color(BabyTownTheme.accent.opacity(0.05)),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 8])
                        )
                    }
                }

                ForEach(pinPositions.indices, id: \.self) { i in
                    let (fx, fy) = pinPositions[i]
                    Image(systemName: "mappin")
                        .font(.system(size: 14))
                        .foregroundStyle(BabyTownTheme.accent.opacity(0.06))
                        .position(x: geo.size.width * fx, y: geo.size.height * fy)
                }

                Image(systemName: "location.north.line")
                    .font(.system(size: 72))
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.05))
                    .position(x: geo.size.width * 0.20, y: geo.size.height * 0.80)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    PlannerBackgroundView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

- [ ] **Step 2: Build + preview** — ⌘B, open #Preview canvas. Expected: faint grid, dashes, pin icons, compass rose visible in both Pink and Blue themes.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/DatePlanner/PlannerBackgroundView.swift
git commit -m "feat: add PlannerBackgroundView with static map-aesthetic layers"
```

---

## Task 5: `NewPlanSheet`

**Files:**
- Create: `BabyTown/Views/DatePlanner/NewPlanSheet.swift`

**Interfaces:**
- Consumes: `DatePlanStore.shared.createPlan(_:)` from Task 2
- Produces: `NewPlanSheet(onCreate: (DatePlan) -> Void)` — present as `.sheet` with `.presentationDetents([.medium])`

- [ ] **Step 1: Create `BabyTown/Views/DatePlanner/NewPlanSheet.swift`**

```swift
import SwiftUI

struct NewPlanSheet: View {
    let onCreate: (DatePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedDate = Date()
    @State private var showTime = false
    @State private var selectedTime = Date()

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                        TextField("Name this date", text: $title)
                            .font(.body)
                            .padding(12)
                            .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                            .onChange(of: title) { _, new in
                                if new.count > 40 { title = String(new.prefix(40)) }
                            }
                    }

                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(BabyTownTheme.accent)

                    Toggle(isOn: $showTime) {
                        Label("Add a time", systemImage: "clock")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                    }
                    .tint(BabyTownTheme.accent)

                    if showTime {
                        DatePicker(
                            "Time",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .tint(BabyTownTheme.accent)
                    }
                }
                .padding(20)
            }
            .navigationTitle("New date plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Plan") {
                        let userID = DataPersistenceManager.shared.loadUserEmail() ?? ""
                        let now = Date()
                        let plan = DatePlan(
                            id: UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: selectedDate,
                            time: showTime ? selectedTime : nil,
                            notes: nil,
                            coverPhotoData: nil,
                            itinerary: [],
                            createdByUserID: userID,
                            createdAt: now,
                            updatedAt: now
                        )
                        DatePlanStore.shared.createPlan(plan)
                        onCreate(plan)
                        dismiss()
                    }
                    .disabled(!canCreate)
                    .fontWeight(.semibold)
                    .foregroundStyle(canCreate ? BabyTownTheme.accent : BabyTownTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Home")
        .sheet(isPresented: .constant(true)) {
            NewPlanSheet(onCreate: { _ in })
        }
}
```

- [ ] **Step 2: Build + preview** — ⌘B, check #Preview. Expected: sheet with title field, graphical date picker, time toggle.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/DatePlanner/NewPlanSheet.swift
git commit -m "feat: add NewPlanSheet for creating date plans"
```

---

## Task 6: `PlanVaultSheet` and `NoteEditorSheet`

**Files:**
- Create: `BabyTown/Views/DatePlanner/PlanVaultSheet.swift`
- Create: `BabyTown/Views/DatePlanner/NoteEditorSheet.swift`

**Interfaces:**
- `PlanVaultSheet(onUnlockForever: () -> Void)` — presented as `.sheet` with `.presentationDetents([.medium])`
- `NoteEditorSheet(initialText: String, onSave: (String) -> Void)` — full-screen text editor

- [ ] **Step 1: Create `BabyTown/Views/DatePlanner/PlanVaultSheet.swift`**

```swift
import SwiftUI

struct PlanVaultSheet: View {
    let onUnlockForever: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.accent)

            VStack(spacing: 10) {
                Text("This date is in the vault")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Date plans are kept safe after 30 days. Unlock Forever to relive every date you planned together.")
                    .font(.subheadline)
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 12) {
                Button {
                    dismiss()
                    onUnlockForever()
                } label: {
                    Text("Unlock Forever")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(BabyTownTheme.accentGradient, in: Capsule())
                }
                .buttonStyle(.plain)

                Button("Later") { dismiss() }
                    .font(.body.weight(.medium))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }

            Spacer()
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Home")
        .sheet(isPresented: .constant(true)) {
            PlanVaultSheet(onUnlockForever: {})
        }
}
```

- [ ] **Step 2: Create `BabyTown/Views/DatePlanner/NoteEditorSheet.swift`**

```swift
import SwiftUI

struct NoteEditorSheet: View {
    let initialText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String
    @FocusState private var isFocused: Bool

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        _draftText = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftText)
                    .font(.body)
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .padding(16)
                    .focused($isFocused)

                if draftText.isEmpty {
                    Text("Add notes, vibes, or anything you're excited about")
                        .font(.body)
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draftText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(BabyTownTheme.accent)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }
}

#Preview {
    NoteEditorSheet(initialText: "", onSave: { _ in })
}
```

- [ ] **Step 3: Build + preview** — ⌘B. Preview both sheets. Expected: PlanVaultSheet shows lock icon + two buttons; NoteEditorSheet shows full-screen text editor with placeholder.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/DatePlanner/PlanVaultSheet.swift BabyTown/Views/DatePlanner/NoteEditorSheet.swift
git commit -m "feat: add PlanVaultSheet and NoteEditorSheet"
```

---

## Task 7: `ItineraryStopCard`

**Files:**
- Create: `BabyTown/Views/DatePlanner/ItineraryStopCard.swift`

**Interfaces:**
- Consumes: `ItineraryStop` from Task 1
- Produces: `ItineraryStopCard(stop: ItineraryStop, isEditing: Bool, onDelete: () -> Void)` — a row view used inside `DatePlanDetailView`

- [ ] **Step 1: Create `BabyTown/Views/DatePlanner/ItineraryStopCard.swift`**

```swift
import SwiftUI

struct ItineraryStopCard: View {
    let stop: ItineraryStop
    var isEditing: Bool = false
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Order badge
            ZStack {
                Circle()
                    .fill(BabyTownTheme.accentGradient)
                    .frame(width: 28, height: 28)
                Text("\(stop.order)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Photo or pin icon
            Group {
                if let data = stop.photoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                } else {
                    BabyTownTheme.accentSoft
                        .overlay {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 18))
                                .foregroundStyle(BabyTownTheme.accent)
                        }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.placeName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(1)

                if let note = stop.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isEditing {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 12) {
        ItineraryStopCard(
            stop: ItineraryStop(id: UUID(), order: 1, placeName: "Blue Bottle Coffee", note: "Get the New Orleans iced latte"),
            isEditing: false
        )
        ItineraryStopCard(
            stop: ItineraryStop(id: UUID(), order: 2, placeName: "Dolores Park"),
            isEditing: true
        )
    }
    .padding()
    .background(BabyTownTheme.backgroundGradient)
}
```

- [ ] **Step 2: Build + preview** — ⌘B. Preview shows numbered badge, pin icon (no photo), place name, note, drag handle in edit mode.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/DatePlanner/ItineraryStopCard.swift
git commit -m "feat: add ItineraryStopCard component"
```

---

## Task 8: `PlannerMapView` and `PlannerFullMapView`

**Files:**
- Create: `BabyTown/Views/DatePlanner/PlannerMapView.swift`

**Interfaces:**
- Consumes: `ItineraryStop` from Task 1, `BabyTownTheme.accent`
- Produces:
  - `PlannerMapView(stops: [ItineraryStop])` — non-interactive 220pt-tall map card
  - `PlannerFullMapView(stops: [ItineraryStop])` — interactive full-screen map (`.navigationDestination` or `.fullScreenCover`)

- [ ] **Step 1: Create `BabyTown/Views/DatePlanner/PlannerMapView.swift`**

```swift
import SwiftUI
import MapKit

// MARK: - Annotation model

final class PlannerStopAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let order: Int
    let photoData: Data?

    init(coordinate: CLLocationCoordinate2D, order: Int, photoData: Data?) {
        self.coordinate = coordinate
        self.order = order
        self.photoData = photoData
    }
}

// MARK: - Annotation view

final class PlannerStopAnnotationView: MKAnnotationView {
    static let reuseID = "PlannerStop"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        centerOffset = CGPoint(x: 0, y: -14)
        configure()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func configure() {
        subviews.forEach { $0.removeFromSuperview() }
        guard let stop = annotation as? PlannerStopAnnotation else { return }

        let circle = UIView(frame: bounds)
        circle.layer.cornerRadius = 14
        circle.clipsToBounds = true

        if let data = stop.photoData, let img = UIImage(data: data) {
            let iv = UIImageView(frame: bounds)
            iv.contentMode = .scaleAspectFill
            iv.image = img
            circle.addSubview(iv)
        } else {
            circle.backgroundColor = UIColor(BabyTownTheme.accent)
        }

        circle.layer.borderColor = UIColor.white.cgColor
        circle.layer.borderWidth = 2

        let label = UILabel(frame: bounds)
        label.text = "\(stop.order)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textAlignment = .center
        circle.addSubview(label)

        addSubview(circle)
    }

    override var annotation: MKAnnotation? {
        didSet { configure() }
    }
}

// MARK: - Non-interactive map card

struct PlannerMapView: UIViewRepresentable {
    let stops: [ItineraryStop]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.register(PlannerStopAnnotationView.self, forAnnotationViewWithReuseIdentifier: PlannerStopAnnotationView.reuseID)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)

        let geoStops = stops.compactMap { stop -> (ItineraryStop, CLLocationCoordinate2D)? in
            guard let lat = stop.latitude, let lon = stop.longitude else { return nil }
            return (stop, CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }

        let annotations = geoStops.map { (stop, coord) in
            PlannerStopAnnotation(coordinate: coord, order: stop.order, photoData: stop.photoData)
        }
        map.addAnnotations(annotations)

        if geoStops.count >= 2 {
            let coords = geoStops.map(\.1)
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            map.addOverlay(polyline)
        }

        if !geoStops.isEmpty {
            let coords = geoStops.map(\.1)
            let region = regionFitting(coords)
            map.setRegion(region, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func regionFitting(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor(BabyTownTheme.accent)
                r.lineWidth = 2.5
                r.lineDashPattern = [6, 4]
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is PlannerStopAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: PlannerStopAnnotationView.reuseID,
                for: annotation
            )
            view.annotation = annotation
            return view
        }
    }
}

// MARK: - Full-screen interactive map

struct PlannerFullMapView: View {
    let stops: [ItineraryStop]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PlannerInteractiveMapView(stops: stops)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(BabyTownTheme.accent)
                    }
                }
        }
    }
}

// Interactive variant for PlannerFullMapView

private struct PlannerInteractiveMapView: UIViewRepresentable {
    let stops: [ItineraryStop]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.register(PlannerStopAnnotationView.self, forAnnotationViewWithReuseIdentifier: PlannerStopAnnotationView.reuseID)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)

        let geoStops = stops.compactMap { stop -> (ItineraryStop, CLLocationCoordinate2D)? in
            guard let lat = stop.latitude, let lon = stop.longitude else { return nil }
            return (stop, CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }

        let annotations = geoStops.map { (stop, coord) in
            PlannerStopAnnotation(coordinate: coord, order: stop.order, photoData: stop.photoData)
        }
        map.addAnnotations(annotations)

        if geoStops.count >= 2 {
            let coords = geoStops.map(\.1)
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            map.addOverlay(polyline)
        }

        if !geoStops.isEmpty {
            let coords = geoStops.map(\.1)
            var minLat = coords[0].latitude, maxLat = coords[0].latitude
            var minLon = coords[0].longitude, maxLon = coords[0].longitude
            for c in coords {
                minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
                minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
            }
            let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
                longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
            )
            map.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        }
    }

    func makeCoordinator() -> PlannerMapView.Coordinator { PlannerMapView.Coordinator() }
}
```

- [ ] **Step 2: Build** — ⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/DatePlanner/PlannerMapView.swift
git commit -m "feat: add PlannerMapView and PlannerFullMapView with polyline and numbered stop pins"
```

---

## Task 9: `StopSearchSheet`

**Files:**
- Create: `BabyTown/Views/DatePlanner/StopSearchSheet.swift`

**Interfaces:**
- Consumes: `PlannerPlaceSearchViewModel` from Task 3, `Moment` from existing models, `DataPersistenceManager.shared.loadMoments()`
- Produces: `StopSearchSheet(onAdd: (ItineraryStop) -> Void, nextOrder: Int)` — `.large` detent sheet

- [ ] **Step 1: Create `BabyTown/Views/DatePlanner/StopSearchSheet.swift`**

```swift
import SwiftUI
import MapKit

struct StopSearchSheet: View {
    let onAdd: (ItineraryStop) -> Void
    let nextOrder: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchVM = PlannerPlaceSearchViewModel()
    @State private var selectedTab: SearchTab = .places
    @State private var momentQuery = ""

    private enum SearchTab { case places, moments }

    private var filteredMoments: [Moment] {
        DataPersistenceManager.shared.loadMoments()
            .filter { $0.placeName != nil && $0.latitude != nil && $0.longitude != nil }
            .filter { moment in
                guard !momentQuery.isEmpty else { return true }
                return moment.placeName?.localizedCaseInsensitiveContains(momentQuery) == true
            }
            .sorted { $0.dateTaken > $1.dateTaken }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                Divider()

                if selectedTab == .places {
                    placesTab
                } else {
                    momentsTab
                }
            }
            .navigationTitle("Add a stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton("Places", tab: .places)
            tabButton("Our Moments", tab: .moments)
        }
        .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(_ title: String, tab: SearchTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedTab == tab ? .white : BabyTownTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == tab ? AnyShapeStyle(BabyTownTheme.accentGradient) : AnyShapeStyle(Color.clear),
                             in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    // MARK: - Places tab

    private var placesTab: some View {
        VStack(spacing: 0) {
            searchBar(text: $searchVM.query, placeholder: "Search for a restaurant, park, cinema")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            if searchVM.suggestions.isEmpty && searchVM.query.isEmpty {
                ContentUnavailableView(
                    "Search for a place",
                    systemImage: "magnifyingglass",
                    description: Text("Restaurant, park, cinema and more")
                )
            } else if searchVM.suggestions.isEmpty {
                ContentUnavailableView(
                    "No results",
                    systemImage: "mappin.slash",
                    description: Text("Try a different search")
                )
            } else {
                List(searchVM.suggestions) { suggestion in
                    Button {
                        Task { await addPlaceSuggestion(suggestion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.body)
                                .foregroundStyle(BabyTownTheme.textPrimary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(BabyTownTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Our Moments tab

    private var momentsTab: some View {
        VStack(spacing: 0) {
            searchBar(text: $momentQuery, placeholder: "Search by place name")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            if filteredMoments.isEmpty {
                ContentUnavailableView(
                    "No moments with a location",
                    systemImage: "photo.on.rectangle",
                    description: Text("Moments with a saved location will appear here")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filteredMoments) { moment in
                            Button {
                                addMomentStop(moment)
                            } label: {
                                momentCell(moment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func momentCell(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if let place = moment.placeName {
                Text(place)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(1)
            }

            Text(moment.dateTaken, style: .date)
                .font(.caption2)
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
    }

    // MARK: - Shared search bar

    private func searchBar(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BabyTownTheme.textSecondary)
            TextField(placeholder, text: text)
                .font(.body)
        }
        .padding(10)
        .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func addPlaceSuggestion(_ suggestion: PlaceSuggestion) async {
        let coord = await searchVM.resolveDetails(for: suggestion)
        let stop = ItineraryStop(
            id: UUID(),
            order: nextOrder,
            placeName: suggestion.title,
            latitude: coord?.latitude,
            longitude: coord?.longitude,
            momentID: nil,
            photoData: nil,
            note: nil
        )
        await MainActor.run {
            onAdd(stop)
            dismiss()
        }
    }

    private func addMomentStop(_ moment: Moment) {
        let photoData = moment.thumbnail.jpegData(compressionQuality: 0.6)
        let stop = ItineraryStop(
            id: UUID(),
            order: nextOrder,
            placeName: moment.placeName ?? "",
            latitude: moment.latitude,
            longitude: moment.longitude,
            momentID: moment.id,
            photoData: photoData,
            note: moment.caption
        )
        onAdd(stop)
        dismiss()
    }
}
```

- [ ] **Step 2: Build** — ⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/DatePlanner/StopSearchSheet.swift
git commit -m "feat: add StopSearchSheet with Places and Our Moments tabs"
```

---

## Task 10: `DatePlanDetailView`

**Files:**
- Create: `BabyTown/Views/DatePlanner/DatePlanDetailView.swift`

**Interfaces:**
- Consumes: `DatePlan`, `ItineraryStop`, `PlannerBackgroundView`, `ItineraryStopCard`, `PlannerMapView`, `PlannerFullMapView`, `NoteEditorSheet`, `StopSearchSheet` from prior tasks
- Produces: `DatePlanDetailView(plan: Binding<DatePlan>, onPlanUpdated: (DatePlan) -> Void)`

- [ ] **Step 1: Create `BabyTown/Views/DatePlanner/DatePlanDetailView.swift`**

```swift
import SwiftUI
import PhotosUI

struct DatePlanDetailView: View {
    @Binding var plan: DatePlan
    let onPlanUpdated: (DatePlan) -> Void

    @State private var isEditing = false
    @State private var showNotesEditor = false
    @State private var showDateEditor = false
    @State private var showStopSearch = false
    @State private var showFullMap = false
    @State private var showAIToast = false
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var showDeleteStopID: UUID?

    private var geoStops: [ItineraryStop] {
        plan.itinerary.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    dateStripSection
                    notesSection
                    itinerarySection
                    if geoStops.count >= 2 {
                        mapSection
                    }
                    Spacer(minLength: 80)
                }
            }
            .background(PlannerBackgroundView().ignoresSafeArea())

            aiFAB
                .padding(20)
        }
        .sheet(isPresented: $showNotesEditor) {
            NoteEditorSheet(initialText: plan.notes ?? "") { newNotes in
                var updated = plan
                updated.notes = newNotes
                updated.updatedAt = Date()
                DatePlanStore.shared.updatePlan(updated)
                plan = updated
                onPlanUpdated(updated)
            }
        }
        .sheet(isPresented: $showDateEditor) {
            dateeditorSheet
        }
        .sheet(isPresented: $showStopSearch) {
            StopSearchSheet(onAdd: { stop in
                var updated = plan
                updated.itinerary.append(stop)
                updated.updatedAt = Date()
                DatePlanStore.shared.updatePlan(updated)
                plan = updated
                onPlanUpdated(updated)
            }, nextOrder: plan.itinerary.count + 1)
        }
        .fullScreenCover(isPresented: $showFullMap) {
            PlannerFullMapView(stops: plan.itinerary)
        }
        .onChange(of: coverPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    var updated = plan
                    updated.coverPhotoData = data
                    updated.updatedAt = Date()
                    DatePlanStore.shared.updatePlan(updated)
                    await MainActor.run {
                        plan = updated
                        onPlanUpdated(updated)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showAIToast {
                Text("Coming soon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(BabyTownTheme.textPrimary.opacity(0.85), in: Capsule())
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showAIToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showAIToast)
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let data = plan.coverPhotoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                } else {
                    BabyTownTheme.accentSoft
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "camera")
                                    .font(.system(size: 32))
                                    .foregroundStyle(BabyTownTheme.accent)
                                Text("Add cover photo")
                                    .font(.subheadline)
                                    .foregroundStyle(BabyTownTheme.accent)
                            }
                        }
                }
            }
            .frame(height: 280)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            }

            // Title
            Text(plan.title)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(height: 280)
        .overlay(alignment: .topTrailing) {
            PhotosPicker(selection: $coverPickerItem, matching: .images) {
                EmptyView()
            }
            .opacity(0)
            .frame(width: 0, height: 0)

            Button {
                isEditing.toggle()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(16)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                coverPickerItem = nil
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditing {
                PhotosPicker(selection: $coverPickerItem, matching: .images) {
                    Color.clear
                        .frame(height: 280)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Date strip

    private var dateStripSection: some View {
        Button {
            if isEditing { showDateEditor = true }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(BabyTownTheme.accent)
                    .font(.body.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.date, format: Date.FormatStyle().weekday(.wide).month(.wide).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    if let time = plan.time {
                        Text(time, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(BabyTownTheme.textSecondary)
                    }
                }

                Spacer()

                if isEditing {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
        .disabled(!isEditing)
    }

    // MARK: - Notes

    private var notesSection: some View {
        Button {
            if isEditing { showNotesEditor = true }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                let hasNotes = !(plan.notes ?? "").isEmpty
                if hasNotes {
                    Text(plan.notes ?? "")
                        .font(.body)
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Add notes, vibes, or anything you're excited about")
                        .font(.body)
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(Color(.systemBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
        .disabled(!isEditing)
    }

    // MARK: - Itinerary

    private var itinerarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ITINERARY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .kerning(1.2)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            ForEach(plan.itinerary) { stop in
                ItineraryStopCard(stop: stop, isEditing: isEditing)
                    .padding(.horizontal, 16)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if isEditing {
                            Button(role: .destructive) {
                                deleteStop(id: stop.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
            .onMove { from, to in
                var stops = plan.itinerary
                stops.move(fromOffsets: from, toOffset: to)
                for i in stops.indices { stops[i].order = i + 1 }
                var updated = plan
                updated.itinerary = stops
                updated.updatedAt = Date()
                DatePlanStore.shared.updatePlan(updated)
                plan = updated
                onPlanUpdated(updated)
            }

            if isEditing {
                Button {
                    showStopSearch = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add a stop")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        Capsule()
                            .strokeBorder(BabyTownTheme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        PlannerMapView(stops: plan.itinerary)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .contentShape(Rectangle())
            .onTapGesture { showFullMap = true }
    }

    // MARK: - AI FAB

    private var aiFAB: some View {
        Button {
            withAnimation { showAIToast = true }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(BabyTownTheme.accentGradient, in: Circle())
                .shadow(color: BabyTownTheme.accent.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date editor sheet

    private var dateeditorSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DatePicker("Date", selection: Binding(
                        get: { plan.date },
                        set: { newDate in
                            var updated = plan
                            updated.date = newDate
                            updated.updatedAt = Date()
                            DatePlanStore.shared.updatePlan(updated)
                            plan = updated
                            onPlanUpdated(updated)
                        }
                    ), in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(BabyTownTheme.accent)

                    Toggle(isOn: Binding(
                        get: { plan.time != nil },
                        set: { on in
                            var updated = plan
                            updated.time = on ? Date() : nil
                            updated.updatedAt = Date()
                            DatePlanStore.shared.updatePlan(updated)
                            plan = updated
                            onPlanUpdated(updated)
                        }
                    )) {
                        Label("Add a time", systemImage: "clock")
                            .foregroundStyle(BabyTownTheme.textPrimary)
                    }
                    .tint(BabyTownTheme.accent)

                    if plan.time != nil {
                        DatePicker("Time", selection: Binding(
                            get: { plan.time ?? Date() },
                            set: { newTime in
                                var updated = plan
                                updated.time = newTime
                                updated.updatedAt = Date()
                                DatePlanStore.shared.updatePlan(updated)
                                plan = updated
                                onPlanUpdated(updated)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .tint(BabyTownTheme.accent)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Edit date and time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDateEditor = false }
                        .foregroundStyle(BabyTownTheme.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func deleteStop(id: UUID) {
        var updated = plan
        updated.itinerary.removeAll { $0.id == id }
        for i in updated.itinerary.indices { updated.itinerary[i].order = i + 1 }
        updated.updatedAt = Date()
        DatePlanStore.shared.updatePlan(updated)
        plan = updated
        onPlanUpdated(updated)
    }
}
```

- [ ] **Step 2: Build** — ⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/DatePlanner/DatePlanDetailView.swift
git commit -m "feat: add DatePlanDetailView with hero, itinerary, map, and AI FAB"
```

---

## Task 11: `DatePlannerHubView`

**Files:**
- Create: `BabyTown/Views/DatePlanner/DatePlannerHubView.swift`

**Interfaces:**
- Consumes: `DatePlanDetailView`, `NewPlanSheet`, `PlanVaultSheet`, `DatePlanStore.shared` from prior tasks
- Produces: `DatePlannerHubView(onUnlockForever: () -> Void)` — full-screen sheet

- [ ] **Step 1: Create `BabyTown/Views/DatePlanner/DatePlannerHubView.swift`**

```swift
import SwiftUI

struct DatePlannerHubView: View {
    let onUnlockForever: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: HubTab = .plans
    @State private var plans: [DatePlan] = []
    @State private var selectedPlanID: UUID?
    @State private var showNewPlan = false
    @State private var vaultedPlan: DatePlan?

    private enum HubTab { case plans, log }

    private var isLinked: Bool {
        DataPersistenceManager.shared.isPartnerAccount()
    }

    private var selectedPlan: Binding<DatePlan>? {
        guard let id = selectedPlanID,
              let idx = plans.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { plans[idx] },
            set: { plans[idx] = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar

                Divider()

                if !isLinked {
                    notLinkedState
                } else if selectedTab == .plans {
                    plansTab
                } else {
                    logTab
                }
            }
            .background(PlannerBackgroundView().ignoresSafeArea())
            .navigationTitle("Date Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BabyTownTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewPlan = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(BabyTownTheme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showNewPlan) {
            NewPlanSheet { newPlan in
                plans.append(newPlan)
                selectedPlanID = newPlan.id
                selectedTab = .plans
                DatePlanStore.shared.setLastSelectedPlanID(newPlan.id)
            }
        }
        .sheet(item: $vaultedPlan) { _ in
            PlanVaultSheet(onUnlockForever: {
                vaultedPlan = nil
                onUnlockForever()
            })
        }
        .onAppear { loadPlans() }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Plans", tab: .plans)
            tabButton("Log", tab: .log)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func tabButton(_ title: String, tab: HubTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedTab == tab ? BabyTownTheme.accent : BabyTownTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if selectedTab == tab {
                        Rectangle()
                            .fill(BabyTownTheme.accent)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Not linked

    private var notLinkedState: some View {
        ContentUnavailableView(
            "Connect with a partner first",
            systemImage: "person.2",
            description: Text("Date plans are available once you and your partner are linked")
        )
    }

    // MARK: - Plans tab

    private var plansTab: some View {
        VStack(spacing: 0) {
            if plans.isEmpty {
                emptyPlansState
            } else {
                planSwitcher

                Divider()

                if let binding = selectedPlan {
                    DatePlanDetailView(plan: binding, onPlanUpdated: { updated in
                        if let idx = plans.firstIndex(where: { $0.id == updated.id }) {
                            plans[idx] = updated
                        }
                    })
                }
            }
        }
    }

    private var emptyPlansState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.6))

            VStack(spacing: 8) {
                Text("Plan your next date")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                Text("Create an itinerary for a date you are planning together")
                    .font(.subheadline)
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showNewPlan = true
            } label: {
                Label("New Date Plan", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(BabyTownTheme.accentGradient, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var planSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(plans) { plan in
                    Button {
                        selectedPlanID = plan.id
                        DatePlanStore.shared.setLastSelectedPlanID(plan.id)
                    } label: {
                        Text(plan.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedPlanID == plan.id ? .white : BabyTownTheme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    selectedPlanID == plan.id
                                        ? AnyShapeStyle(BabyTownTheme.accentGradient)
                                        : AnyShapeStyle(BabyTownTheme.accentSoft)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Log tab

    private var logTab: some View {
        List {
            ForEach(plans.sorted { $0.createdAt > $1.createdAt }) { plan in
                logRow(plan)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onTapGesture {
                        if plan.isVaulted {
                            vaultedPlan = plan
                        } else {
                            selectedPlanID = plan.id
                            selectedTab = .plans
                            DatePlanStore.shared.setLastSelectedPlanID(plan.id)
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func logRow(_ plan: DatePlan) -> some View {
        HStack(spacing: 12) {
            // Cover thumbnail
            ZStack {
                if plan.isVaulted {
                    Rectangle()
                        .fill(BabyTownTheme.accentSoft)
                        .overlay(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(BabyTownTheme.accent)
                        }
                } else if let data = plan.coverPhotoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .saturation(plan.isPast ? 0.4 : 1.0)
                } else {
                    BabyTownTheme.accentSoft
                        .overlay {
                            Image(systemName: "calendar")
                                .foregroundStyle(BabyTownTheme.accent.opacity(0.5))
                        }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(plan.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(plan.isPast ? BabyTownTheme.textSecondary : BabyTownTheme.textPrimary)
                        .lineLimit(1)

                    if plan.isVaulted {
                        Text("Locked")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BabyTownTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BabyTownTheme.accentSoft, in: Capsule())
                    } else if plan.isPast {
                        Text("Past")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                }

                Text(plan.date, format: Date.FormatStyle().month(.wide).day().year())
                    .font(.subheadline)
                    .foregroundStyle(BabyTownTheme.textSecondary)

                if !plan.itinerary.isEmpty {
                    Text("\(plan.itinerary.count) stop\(plan.itinerary.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(BabyTownTheme.accent)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func loadPlans() {
        plans = DatePlanStore.shared.allPlans()
        let lastID = DatePlanStore.shared.lastSelectedPlanID
        if let lastID, plans.contains(where: { $0.id == lastID }) {
            selectedPlanID = lastID
        } else {
            selectedPlanID = plans.sorted { $0.createdAt > $1.createdAt }.first?.id
        }
    }
}
```

- [ ] **Step 2: Build** — ⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/DatePlanner/DatePlannerHubView.swift
git commit -m "feat: add DatePlannerHubView with Plans and Log tabs"
```

---

## Task 12: Wire Entry Point — `StickyActionBar` and `HomeView`

**Files:**
- Modify: `BabyTown/Components/StickyActionBar.swift`
- Modify: `BabyTown/Views/HomeView.swift`

**Interfaces:**
- Consumes: `DatePlannerHubView` from Task 11
- `StickyActionBar` gains `var onPlanner: (() -> Void)?`
- `HomeView` gains `@State private var showPlanner = false`, `.fullScreenCover(isPresented: $showPlanner)`

- [ ] **Step 1: Add `onPlanner` to `StickyActionBar`**

In `BabyTown/Components/StickyActionBar.swift`, after `var onScan: (() -> Void)?`, add:

```swift
var onPlanner: (() -> Void)?
```

In the `body`, after the `if let onScan` block, add:

```swift
if let onPlanner {
    secondaryPill(title: "Planner", systemImage: "calendar.badge.plus", action: onPlanner)
}
```

- [ ] **Step 2: Wire `HomeView`**

In `BabyTown/Views/HomeView.swift`:

After `@State private var showScan = false`, add:
```swift
@State private var showPlanner = false
```

Find the `StickyActionBar(...)` call in `body` and add `onPlanner: { showPlanner = true }` alongside the existing `onScan` and `onPrompt` parameters.

After the existing `.fullScreenCover(isPresented: $showForeverPaywall)` block, add:
```swift
.fullScreenCover(isPresented: $showPlanner) {
    DatePlannerHubView(onUnlockForever: {
        showPlanner = false
        showForeverPaywall = true
    })
}
```

- [ ] **Step 3: Build** — ⌘B. Expected: Build Succeeded with no regressions.

- [ ] **Step 4: Run on simulator**

Launch the app on an iPhone 15 simulator. Tap the home StickyActionBar; confirm "Planner" pill appears after "Scan". Tap "Planner" — confirm DatePlannerHubView opens as full-screen sheet. Create a plan — confirm NewPlanSheet appears, plan is created, hub switches to Plans tab showing DatePlanDetailView. Toggle isEditing — confirm pencil icon activates cover photo picker, date strip and notes become tappable.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Components/StickyActionBar.swift BabyTown/Views/HomeView.swift
git commit -m "feat: wire Date Planner entry point into StickyActionBar and HomeView"
```

---

## Spec Coverage Self-Check

| Spec requirement | Covered by |
|---|---|
| "Planner" pill after Scan in StickyActionBar | Task 12, Step 1 |
| `calendar.badge.plus` icon, `onPlanner` closure | Task 12, Step 1 |
| `showPlanner` state + `.fullScreenCover` | Task 12, Step 2 |
| Plans/Log top tab strip | Task 11, `tabBar` |
| "+" button top-right opens `NewPlanSheet` | Task 11, toolbar |
| Plan switcher with accent-highlighted active chip | Task 11, `planSwitcher` |
| Empty state with "Plan your next date" CTA | Task 11, `emptyPlansState` |
| Log: chronological, cover thumbnail, title, date, stop count | Task 11, `logRow` |
| Past plans: subdued + "Past" pill | Task 11, `logRow` |
| Vaulted plans: blurred cover + "Locked" pill + `PlanVaultSheet` | Task 11, `logRow` + Task 6 |
| Last-selected plan persisted in UserDefaults | Task 11, `loadPlans` + `planSwitcher` |
| `NewPlanSheet`: title (40 char), graphical DatePicker, time toggle | Task 5 |
| Plan created → hub switches to Plans with new plan selected | Task 5, `onCreate` callback |
| Hero: 280pt cover, gradient, serif title, pencil toggle, photo picker | Task 10 |
| Date strip: `.ultraThinMaterial`, calendar icon, EEEE MMMM d format, time | Task 10, `dateStripSection` |
| Notes card with placeholder; taps open `NoteEditorSheet` in edit mode | Task 10, `notesSection` + Task 6 |
| Itinerary: numbered badge, 48×48 photo/pin, name, note, drag/swipe-delete | Task 7 + Task 10 |
| "Add a stop" dashed pill in edit mode → `StopSearchSheet` | Task 10, `itinerarySection` |
| Map: 220pt, 16pt corners, non-interactive, polyline, numbered pins | Task 8, `PlannerMapView` |
| Map hidden if fewer than 2 geolocated stops | Task 10, `geoStops.count >= 2` |
| Tap map → `PlannerFullMapView` | Task 10, `mapSection` |
| AI FAB: 48pt circle, `accentGradient`, sparkle icon, "Coming soon" toast | Task 10, `aiFAB` |
| `StopSearchSheet`: Places tab with `PlannerPlaceSearchViewModel` | Task 9 |
| Places: empty state "Search for a restaurant, park, cinema" | Task 9, `placesTab` |
| Our Moments: 2-col grid, thumbnail + place + date, filter by query | Task 9, `momentsTab` |
| Moment stop: photoData JPEG 0.6, placeName, lat/lon, caption as note | Task 9, `addMomentStop` |
| `PlannerBackgroundView`: gradient, grid, dashes, pins, compass | Task 4 |
| Vault rule: `isVaulted` computed on `DatePlan`, no stored field | Task 1 |
| `PlanVaultSheet`: lock icon, copy, "Unlock Forever" → paywall, "Later" | Task 6 |
| `DatePlanStore`: JSON in Documents, UserDefaults last-selected, CRUD, sync stubs | Task 2 |
| Prelude solo-user gate: "connect with a partner" empty state | Task 11, `notLinkedState` |
| No dashes in any user-facing string | Verified across all tasks |
