# Flower Achievement Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing two-case garden tap sheets (`GardenMemoryCard` / `LegendBloomCard`) with a single large `FlowerAchievementSheet` that highlights the tapped bloom and shows all 10 bloom types as an unlockable achievement collection grid.

**Architecture:** Five sequential tasks: (1) widen `LoveGardenScene` node builders to `internal static`; (2) build the `BloomCatalogEntry` data model and `BloomCatalogBuilder`; (3) create `BloomSnapshotScene` and `BloomImageRenderer`; (4) implement `FlowerAchievementSheet`; (5) update `LoveGardenView` to collapse tap presentation to one case and wire the new sheet.

**Tech Stack:** SwiftUI, SpriteKit, GardenCore (local Swift package at `GardenCore/`), `@MainActor` async rendering

## Global Constraints

- No hex/RGB hardcoded colors — use `SKColor`/`UIColor` or `BabyTownTheme.*` tokens
- No user-facing strings with ` - ` (space dash space)
- `BloomCatalogBuilder` must be pure: no side effects, no persistence reads, derives everything from `[GardenElement]`
- `BloomImageRenderer` must be `@MainActor` (SpriteKit rendering requires main thread)
- The app name "BabyTown" never appears in user-facing copy

---

### Task 1: Widen `LoveGardenScene` node builders to `internal static`

**Files:**
- Modify: `BabyTown/Game/Garden/LoveGardenScene.swift`

**Interfaces:**
- Produces: `LoveGardenScene.makeFlower(chapter:shape:season:cycle:isLegend:) -> SKNode` — `internal static`
- Produces: `LoveGardenScene.makeTree() -> SKNode` — `internal static`

These two methods currently have no instance state — they accept all inputs as parameters and call only other private helpers (`addPetals`, `addFlowerCenter`, `addRadialPetals`) which also have no instance state. Making them `static` is safe.

- [ ] **Step 1: Change `makeFlower`, `makeTree`, and their private helpers to `static`**

In `BabyTown/Game/Garden/LoveGardenScene.swift`, apply these modifier changes:

```swift
// makeFlower: private func → internal static func
internal static func makeFlower(
    chapter: BloomChapter,
    shape: BloomShape,
    season: GardenSeason,
    cycle: Int,
    isLegend: Bool
) -> SKNode { /* body unchanged */ }

// addPetals: private func → private static func
private static func addPetals(
    to head: SKNode,
    shape: BloomShape,
    color: SKColor,
    isLegend: Bool
) { /* body unchanged */ }

// addRadialPetals: private func → private static func
private static func addRadialPetals(
    to head: SKNode,
    count: Int,
    size: CGSize,
    color: SKColor,
    offsetY: CGFloat
) { /* body unchanged */ }

// addFlowerCenter: private func → private static func
private static func addFlowerCenter(
    to head: SKNode,
    chapter: BloomChapter,
    shape: BloomShape
) { /* body unchanged */ }

// makeTree: private func → internal static func
internal static func makeTree() -> SKNode { /* body unchanged */ }
```

- [ ] **Step 2: Update the `makeNode(for:)` call site**

`makeNode(for:)` is still an instance method and accesses `self.season`. Update its body to call the static methods via `Self.`:

```swift
private func makeNode(for element: GardenElement) -> SKNode {
    switch element.kind {
    case .flower, .placeFlower, .birthdayFlower, .anniversaryFlower:
        return Self.makeFlower(
            chapter: element.chapter,
            shape: element.shape,
            season: season,
            cycle: element.cycle,
            isLegend: element.isLegend
        )
    case .tree:
        return Self.makeTree()
    }
}
```

- [ ] **Step 3: Build the project**

Product → Build (`⌘B`). Expected: zero errors. If the compiler complains about `self` usage inside any of the newly-static methods, that would indicate an undiscovered instance-state dependency — investigate before proceeding.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Game/Garden/LoveGardenScene.swift
git commit -m "feat: widen LoveGardenScene.makeFlower and makeTree to internal static"
```

---

### Task 2: `BloomCatalogEntry` model and `BloomCatalogBuilder`

**Files:**
- Create: `BabyTown/Models/BloomCatalogEntry.swift`

**Interfaces:**
- Consumes: `GardenElement`, `BloomChapter`, `BloomShape`, `GardenElementKind` from `GardenCore`
- Produces: `BloomCatalogEntry` — `Identifiable` struct with `cacheKey: String`
- Produces: `BloomCatalogBuilder.build(from: [GardenElement]) -> [BloomCatalogEntry]` — always returns exactly 10 entries

**`cacheKey` format:** `"\(chapter.rawValue)-\(shape.rawValue)-\(isLegend)"` for blooms, `"tree"` for the Love Tree. This key is used by `BloomImageRenderer` to cache rendered images (Task 3) and by `FlowerAchievementSheet` to match a tapped `GardenElement` to its catalog entry (Task 4).

**isEarned logic per entry type:**
- Basic milestone bouquets (entries 1–5): check if any element with matching `chapter` + `shape == .daisy12` + `!isLegend` exists. Each chapter maps to one threshold via `BloomChapterResolver.chapter(forBasicMilestone:)` — the catalog just checks by chapter color regardless of threshold number.
- Shrine entries (Twilight / Eclipse): check by `chapter` + `shape` + `isLegend == true`
- Birthday / Anniversary: check by `element.kind`
- Love Tree: check by `element.kind == .tree`

- [ ] **Step 1: Create `BabyTown/Models/BloomCatalogEntry.swift`**

```swift
import GardenCore

struct BloomCatalogEntry: Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    let unlockCondition: String
    let isEarned: Bool
    let chapter: BloomChapter?
    let shape: BloomShape?
    let isLegend: Bool

    var isTree: Bool { chapter == nil && shape == nil }

    var cacheKey: String {
        guard let chapter, let shape else { return "tree" }
        return "\(chapter.rawValue)-\(shape.rawValue)-\(isLegend)"
    }
}

enum BloomCatalogBuilder {
    static func build(from elements: [GardenElement]) -> [BloomCatalogEntry] {
        let hasBloom = { (chapter: BloomChapter, shape: BloomShape, isLegend: Bool) -> Bool in
            elements.contains {
                $0.chapter == chapter && $0.shape == shape && $0.isLegend == isLegend
            }
        }
        return [
            BloomCatalogEntry(
                id: "white-daisy12",
                displayName: "First Bouquet",
                subtitle: "10 memories planted together",
                unlockCondition: "Reach 10 moments",
                isEarned: hasBloom(.white, .daisy12, false),
                chapter: .white, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "yellow-daisy12",
                displayName: "Sunbeam Bouquet",
                subtitle: "20 memories planted together",
                unlockCondition: "Reach 20 moments",
                isEarned: hasBloom(.yellow, .daisy12, false),
                chapter: .yellow, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "red-daisy12",
                displayName: "Ember Bouquet",
                subtitle: "30 memories planted together",
                unlockCondition: "Reach 30 moments",
                isEarned: hasBloom(.red, .daisy12, false),
                chapter: .red, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "blue-daisy12",
                displayName: "Horizon Bouquet",
                subtitle: "40 memories planted together",
                unlockCondition: "Reach 40 moments",
                isEarned: hasBloom(.blue, .daisy12, false),
                chapter: .blue, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "purple-daisy12",
                displayName: "Twilight Bouquet",
                subtitle: "50 memories planted together",
                unlockCondition: "Reach 50 moments",
                isEarned: hasBloom(.purple, .daisy12, false),
                chapter: .purple, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "purple-tulip3-true",
                displayName: "Twilight Shrine",
                subtitle: "Fifty memories in — your garden is truly thriving",
                unlockCondition: "50 memories together",
                isEarned: hasBloom(.purple, .tulip3, true),
                chapter: .purple, shape: .tulip3, isLegend: true
            ),
            BloomCatalogEntry(
                id: "black-lotus8-true",
                displayName: "Eclipse Shrine",
                subtitle: "One hundred blooms of us. Legendary",
                unlockCondition: "100 memories together",
                isEarned: hasBloom(.black, .lotus8, true),
                chapter: .black, shape: .lotus8, isLegend: true
            ),
            BloomCatalogEntry(
                id: "birthday-daisy12",
                displayName: "Birthday Bloom",
                subtitle: "Another candle, another flower",
                unlockCondition: "Add a birthday",
                isEarned: elements.contains { $0.kind == .birthdayFlower },
                chapter: .birthday, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "anniversary-lotus8",
                displayName: "Anniversary Bloom",
                subtitle: "Another year of us, planted in the garden",
                unlockCondition: "Add your anniversary",
                isEarned: elements.contains { $0.kind == .anniversaryFlower },
                chapter: .anniversary, shape: .lotus8, isLegend: false
            ),
            BloomCatalogEntry(
                id: "tree",
                displayName: "Love Tree",
                subtitle: "A love letter, rooted forever",
                unlockCondition: "Write a love letter",
                isEarned: elements.contains { $0.kind == .tree },
                chapter: nil, shape: nil, isLegend: false
            ),
        ]
    }
}
```

- [ ] **Step 2: Build the project**

Product → Build (`⌘B`). Expected: zero errors.

- [ ] **Step 3: Sanity-check the builder output**

Add a temporary `assert` somewhere reachable during launch (e.g. top of `LoveGardenView.buildGarden`) and remove it after:

```swift
// Temporary — remove after verifying
let _check = BloomCatalogBuilder.build(from: [])
assert(_check.count == 10)
assert(_check.allSatisfy { !$0.isEarned })
```

Run the app, confirm no assertion fires, then delete those two lines.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Models/BloomCatalogEntry.swift
git commit -m "feat: add BloomCatalogEntry model and BloomCatalogBuilder"
```

---

### Task 3: `BloomSnapshotScene` and `BloomImageRenderer`

**Files:**
- Create: `BabyTown/Game/Garden/BloomSnapshotScene.swift`
- Create: `BabyTown/Services/BloomImageRenderer.swift`

**Interfaces:**
- Consumes: `LoveGardenScene.makeFlower(chapter:shape:season:cycle:isLegend:)` and `LoveGardenScene.makeTree()` (Task 1)
- Consumes: `BloomCatalogEntry` (Task 2)
- Produces: `BloomImageRenderer.shared` — `@MainActor` singleton
- Produces: `BloomImageRenderer.shared.render(entry: BloomCatalogEntry) async -> UIImage?`

`BloomImageRenderer` follows the same double-dispatch `waitForRenderPass` pattern as the existing `GardenSnapshotRenderer` in `BabyTown/Services/GardenSnapshotRenderer.swift`. Read that file for reference — the pattern is identical.

- [ ] **Step 1: Create `BabyTown/Game/Garden/BloomSnapshotScene.swift`**

```swift
import SpriteKit
import GardenCore

final class BloomSnapshotScene: SKScene {
    private let entry: BloomCatalogEntry

    init(entry: BloomCatalogEntry) {
        self.entry = entry
        super.init(size: CGSize(width: 100, height: 130))
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        let node: SKNode
        if entry.isTree {
            node = LoveGardenScene.makeTree()
        } else {
            node = LoveGardenScene.makeFlower(
                chapter: entry.chapter!,
                shape: entry.shape!,
                season: .blooming,
                cycle: 0,
                isLegend: entry.isLegend
            )
        }
        node.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        addChild(node)
    }
}
```

- [ ] **Step 2: Create `BabyTown/Services/BloomImageRenderer.swift`**

```swift
import SpriteKit
import UIKit

@MainActor
final class BloomImageRenderer {
    static let shared = BloomImageRenderer()

    private var cache: [String: UIImage] = [:]

    func render(entry: BloomCatalogEntry) async -> UIImage? {
        if let cached = cache[entry.cacheKey] { return cached }

        let size = CGSize(width: 100, height: 130)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.allowsTransparency = true

        let scene = BloomSnapshotScene(entry: entry)
        scene.isPaused = true
        view.presentScene(scene)

        await waitForRenderPass()
        if let image = snapshot(from: view, scene: scene) {
            cache[entry.cacheKey] = image
            return image
        }
        await waitForRenderPass()
        let image = snapshot(from: view, scene: scene)
        if let image { cache[entry.cacheKey] = image }
        return image
    }

    private func snapshot(from view: SKView, scene: BloomSnapshotScene) -> UIImage? {
        guard let texture = view.texture(from: scene) else { return nil }
        return UIImage(cgImage: texture.cgImage())
    }

    private func waitForRenderPass() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build the project**

Product → Build (`⌘B`). Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Game/Garden/BloomSnapshotScene.swift BabyTown/Services/BloomImageRenderer.swift
git commit -m "feat: add BloomSnapshotScene and BloomImageRenderer"
```

---

### Task 4: `FlowerAchievementSheet`

**Files:**
- Create: `BabyTown/Views/FlowerAchievementSheet.swift`

**Interfaces:**
- Consumes: `BloomCatalogEntry`, `BloomCatalogBuilder.build(from:)` (Task 2)
- Consumes: `BloomImageRenderer.shared.render(entry:)` (Task 3)
- Consumes: `GardenElement` from GardenCore
- Produces: `FlowerSourceContext` struct — also consumed by Task 5
- Produces: `FlowerAchievementSheet(tappedElement:gardenElements:sourceContext:)` — presented with `.presentationDetents([.large])`

The `tappedEntry` is found by computing the same `cacheKey` format used in `BloomCatalogEntry` from the tapped `GardenElement`. This key uniquely identifies each of the 10 bloom types.

- [ ] **Step 1: Create `BabyTown/Views/FlowerAchievementSheet.swift`**

```swift
import SwiftUI
import GardenCore

struct FlowerSourceContext {
    let placeName: String?
    let date: Date
}

struct FlowerAchievementSheet: View {
    let tappedElement: GardenElement
    let gardenElements: [GardenElement]
    let sourceContext: FlowerSourceContext?

    @State private var images: [String: UIImage] = [:]

    private var catalog: [BloomCatalogEntry] {
        BloomCatalogBuilder.build(from: gardenElements)
    }

    private var tappedEntry: BloomCatalogEntry? {
        catalog.first { $0.cacheKey == elementCacheKey(tappedElement) }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 4)
                    Text("Garden Blooms")
                        .font(.title2.weight(.semibold))
                }
                .padding(.top, 12)

                if let entry = tappedEntry {
                    heroCard(entry: entry)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Collection")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(catalog) { entry in
                            gridCell(entry: entry, isActive: entry.id == tappedEntry?.id)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
        }
        .task { await loadImages() }
    }

    @ViewBuilder
    private func heroCard(entry: BloomCatalogEntry) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                bloomImageView(for: entry)
                    .frame(width: 140, height: 160)
                if entry.isLegend {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(.yellow)
                        .padding(6)
                }
            }

            Text(entry.displayName)
                .font(.title3.weight(.semibold))

            Text(entry.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let ctx = sourceContext {
                earnedCaption(ctx)
            }
        }
        .padding(20)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow, lineWidth: 2))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func earnedCaption(_ ctx: FlowerSourceContext) -> some View {
        if let place = ctx.placeName {
            (Text("Earned · \(place) · ") + Text(ctx.date, style: .date))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            (Text("Earned · ") + Text(ctx.date, style: .date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func gridCell(entry: BloomCatalogEntry, isActive: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                bloomImageView(for: entry)
                    .frame(width: 70, height: 80)
                    .saturation(entry.isEarned ? 1.0 : 0.0)

                if entry.isEarned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .green)
                        .offset(x: 4, y: 4)
                } else {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color(.systemGray3))
                        .offset(x: 4, y: 4)
                }
            }

            Text(entry.displayName)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)

            if !entry.isEarned {
                Text(entry.unlockCondition)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.yellow : Color(.systemGray5), lineWidth: isActive ? 2 : 1)
        )
    }

    @ViewBuilder
    private func bloomImageView(for entry: BloomCatalogEntry) -> some View {
        if let image = images[entry.cacheKey] {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .transition(.opacity)
        } else {
            ProgressView()
        }
    }

    private func loadImages() async {
        let renderer = BloomImageRenderer.shared
        for entry in catalog {
            guard images[entry.cacheKey] == nil else { continue }
            if let image = await renderer.render(entry: entry) {
                withAnimation(.easeIn(duration: 0.2)) {
                    images[entry.cacheKey] = image
                }
            }
        }
    }

    private func elementCacheKey(_ element: GardenElement) -> String {
        guard element.kind != .tree else { return "tree" }
        return "\(element.chapter.rawValue)-\(element.shape.rawValue)-\(element.isLegend)"
    }
}
```

- [ ] **Step 2: Build the project**

Product → Build (`⌘B`). Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/FlowerAchievementSheet.swift
git commit -m "feat: add FlowerAchievementSheet with hero card and achievement grid"
```

---

### Task 5: Update `LoveGardenView` — collapse tap presentation, wire new sheet

**Files:**
- Modify: `BabyTown/Views/LoveGardenView.swift`

**Interfaces:**
- Consumes: `FlowerAchievementSheet(tappedElement:gardenElements:sourceContext:)` (Task 4)
- Consumes: `FlowerSourceContext` (Task 4)
- Produces: updated `LoveGardenView` where tapping any bloom or tree opens `FlowerAchievementSheet`

**Note:** `GardenMemoryCard` and `LegendBloomCard` are defined at the bottom of `LoveGardenView.swift` and are only referenced from within the same file — confirmed by grepping the project. They can be deleted in full.

- [ ] **Step 1: Replace `GardenTapPresentation` with a single case**

In `LoveGardenView.swift`, find the `private enum GardenTapPresentation` block and replace it entirely:

```swift
// BEFORE
private enum GardenTapPresentation: Identifiable {
    case moment(Moment, BloomLore)
    case legend(BloomLore)

    var id: String {
        switch self {
        case .moment(let moment, _): return "moment-\(moment.id.uuidString)"
        case .legend(let lore): return "legend-\(lore.displayName)"
        }
    }
}

// AFTER
private enum GardenTapPresentation: Identifiable {
    case flower(GardenElement, [GardenElement], FlowerSourceContext?)

    var id: String {
        switch self {
        case .flower(let element, _, _): return "flower-\(element.sourceID.uuidString)"
        }
    }
}
```

- [ ] **Step 2: Update `handleBloomTap`**

```swift
// BEFORE
private func handleBloomTap(id: UUID) {
    guard let element = gardenElements.first(where: { $0.sourceID == id }),
          let lore = BloomChapterResolver.lore(for: element) else { return }
    if element.isLegend || element.kind != .flower {
        tapPresentation = .legend(lore)
    } else if let moment = moments.first(where: { $0.id == id }) {
        tapPresentation = .moment(moment, lore)
    } else {
        tapPresentation = .legend(lore)
    }
}

// AFTER
private func handleBloomTap(id: UUID) {
    guard let element = gardenElements.first(where: { $0.sourceID == id }) else { return }
    var sourceContext: FlowerSourceContext?
    if let moment = moments.first(where: { $0.id == id }) {
        sourceContext = FlowerSourceContext(placeName: moment.placeName, date: moment.dateTaken)
    }
    tapPresentation = .flower(element, gardenElements, sourceContext)
}
```

- [ ] **Step 3: Update the `.sheet` modifier in `body`**

```swift
// BEFORE
.sheet(item: $tapPresentation) { presentation in
    switch presentation {
    case .moment(let moment, let lore):
        GardenMemoryCard(moment: moment, lore: lore)
            .presentationDetents([.medium])
    case .legend(let lore):
        LegendBloomCard(lore: lore)
            .presentationDetents([.height(220)])
    }
}

// AFTER
.sheet(item: $tapPresentation) { presentation in
    switch presentation {
    case .flower(let element, let elements, let context):
        FlowerAchievementSheet(
            tappedElement: element,
            gardenElements: elements,
            sourceContext: context
        )
        .presentationDetents([.large])
    }
}
```

- [ ] **Step 4: Delete `GardenMemoryCard` and `LegendBloomCard`**

Remove the entire `GardenMemoryCard` struct (currently around lines 102–135 of `LoveGardenView.swift`) and the entire `LegendBloomCard` struct (currently around lines 137–157). Also remove the now-unused `BloomChapterResolver` reference if the compiler warns; the `GardenCore` import stays since `GardenElement` is still used.

- [ ] **Step 5: Build the project**

Product → Build (`⌘B`). Expected: zero errors and zero warnings about unused variables or unreachable cases.

- [ ] **Step 6: Run the app and verify end-to-end**

1. Navigate to the Love Garden view
2. Tap any flower
3. Confirm the large sheet opens titled "Garden Blooms"
4. Confirm the tapped bloom appears in the hero card with a gold border
5. Confirm bloom images load progressively (ProgressView → crossfade to image)
6. Confirm the 2-column grid shows all 10 bloom types
7. Earned blooms: full color, green checkmark badge
8. Locked blooms: greyscale, lock icon, unlock condition text below name
9. Tapped bloom's grid card also shows a gold border
10. For a moment-sourced bloom: "Earned · [place] · [date]" caption appears under subtitle
11. For a shrine (isLegend): gold sparkle badge appears in the top-right of the hero image
12. Tap a tree: sheet opens with "Love Tree" as the hero entry

- [ ] **Step 7: Commit**

```bash
git add BabyTown/Views/LoveGardenView.swift
git commit -m "feat: replace garden tap sheets with FlowerAchievementSheet"
```
