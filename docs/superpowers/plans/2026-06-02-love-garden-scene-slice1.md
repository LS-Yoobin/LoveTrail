# Love Garden Scene (Slice 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone, code-drawn Love Garden SpriteKit scene that grows blooms from the local user's existing moments and letters, with a kindness/resting-season model and tap-to-surface-memory, reachable via a temporary entry route for verification.

**Architecture:** Pure garden logic (act→element mapping, deterministic UUID→position, season/rest math) lives in a new local Swift package `GardenCore`, unit-tested with `swift test` (no XCTest target surgery in the app project). The SpriteKit `LoveGardenScene` + SwiftUI `LoveGardenView` live in the app target under `BabyTown/Game/Garden/` (auto-bundled by Xcode's file-system synced group — no `pbxproj` edits for source files). The app converts its real `Moment`/`UserLetter` values into `GardenCore` inputs and renders the returned elements. `GardenState` (season + last-activity only) persists via the existing `DataPersistenceManager`. The cat room scene is never touched.

**Tech Stack:** Swift, SpriteKit, SwiftUI, Swift Package Manager (local package), JSON `Codable` persistence (existing `DataPersistenceManager` pattern).

**Context for the engineer:**
- This is an iOS app. Single Xcode target `BabyTown`, scheme `BabyTown`. No existing test target — that is intentional; pure logic is tested in the `GardenCore` package via `swift test`.
- The app uses Xcode **file-system synchronized groups**: any `.swift` file placed under `BabyTown/` is automatically compiled into the app target. You do NOT edit `project.pbxproj` to add source files.
- Adding the `GardenCore` **local package dependency** (Task 6) is the one place the app project file changes; do it in Xcode's UI as described, then verify with `xcodebuild`.
- Existing patterns to mirror: `BabyTown/Game/PetRoomScene.swift` (`SKScene` subclass: `init(skin:size:)` → `super.init(size:)`, `required init?(coder:)` = `fatalError`, `didMove(to:)`), `BabyTown/Views/PetRoomView.swift` (`SpriteView(scene:)` inside a `GeometryReader`), `BabyTown/Services/DataPersistenceManager.swift` (`@MainActor`, `JSONEncoder`/`Decoder`, `documentsDirectory.appendingPathComponent(...)`, tolerant `loadX()` returning a default).
- **Trust `xcodebuild` over the editor's SourceKit diagnostics** (project memory). **Watch the 16384px SpriteKit texture limit** — Slice 1 draws procedurally so this is not hit, but keep it in mind.
- **Build command (app):**
  ```
  xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  ```
- **Logic test command (package):** run from the package directory: `cd GardenCore && swift test`.

---

## File Structure

**New — `GardenCore` local Swift package (pure logic + tests):**
- Create: `GardenCore/Package.swift` — package manifest, one library product `GardenCore`.
- Create: `GardenCore/Sources/GardenCore/GardenModels.swift` — `GardenActKind`, `GardenActInput`, `GardenElementKind`, `GardenElement`, `GardenPoint`, `GardenSeason`.
- Create: `GardenCore/Sources/GardenCore/GardenComposer.swift` — act→element mapping + deterministic positioning.
- Create: `GardenCore/Sources/GardenCore/GardenSeasonResolver.swift` — season/rest + revival math.
- Create: `GardenCore/Sources/GardenCore/GardenState.swift` — `Codable` persisted state (season + last activity).
- Create: `GardenCore/Tests/GardenCoreTests/GardenComposerTests.swift`
- Create: `GardenCore/Tests/GardenCoreTests/GardenSeasonResolverTests.swift`

**New — app target (auto-bundled synced group):**
- Create: `BabyTown/Game/Garden/GardenActMapper.swift` — converts `[Moment]` + `[UserLetter]` → `[GardenActInput]`.
- Create: `BabyTown/Game/Garden/LoveGardenScene.swift` — `SKScene`: renders elements, ambience, growth, resting palette, tap reporting.
- Create: `BabyTown/Views/LoveGardenView.swift` — SwiftUI wrapper hosting the scene + tap-to-remember overlay.

**Modified — app target:**
- Modify: `BabyTown.xcodeproj` (Task 6, via Xcode UI) — add local package dependency on `GardenCore`.
- Modify: `BabyTown/Services/DataPersistenceManager.swift` — add `gardenStateFileURL`, `saveGardenState(_:)`, `loadGardenState()`.
- Modify: `BabyTown/ContentView.swift` — add a temporary `.loveGarden` debug route (removed when the cat-room door lands in a later slice).

---

## Task 1: Scaffold the `GardenCore` package

**Files:**
- Create: `GardenCore/Package.swift`
- Create: `GardenCore/Sources/GardenCore/GardenCore.swift`
- Create: `GardenCore/Tests/GardenCoreTests/SmokeTests.swift`

- [ ] **Step 1: Create the package manifest**

`GardenCore/Package.swift`:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GardenCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "GardenCore", targets: ["GardenCore"]),
    ],
    targets: [
        .target(name: "GardenCore"),
        .testTarget(name: "GardenCoreTests", dependencies: ["GardenCore"]),
    ]
)
```

- [ ] **Step 2: Add a placeholder source so the target compiles**

`GardenCore/Sources/GardenCore/GardenCore.swift`:
```swift
import Foundation

/// Namespace marker for the GardenCore module. Real types live in sibling files.
public enum GardenCore {
    public static let version = "1"
}
```

- [ ] **Step 3: Add a smoke test**

`GardenCore/Tests/GardenCoreTests/SmokeTests.swift`:
```swift
import XCTest
@testable import GardenCore

final class SmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(GardenCore.version, "1")
    }
}
```

- [ ] **Step 4: Run the test suite to verify the package builds and tests run**

Run: `cd GardenCore && swift test`
Expected: PASS — `Executed 1 test, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add GardenCore
git commit -m "feat(garden): scaffold GardenCore local package"
```

---

## Task 2: Garden value types + act→element mapping

**Files:**
- Create: `GardenCore/Sources/GardenCore/GardenModels.swift`
- Create: `GardenCore/Sources/GardenCore/GardenComposer.swift`
- Create: `GardenCore/Tests/GardenCoreTests/GardenComposerTests.swift`

- [ ] **Step 1: Write the failing mapping test**

`GardenCore/Tests/GardenCoreTests/GardenComposerTests.swift`:
```swift
import XCTest
@testable import GardenCore

final class GardenComposerTests: XCTestCase {
    private func id(_ s: String) -> UUID { UUID(uuidString: s)! }

    func testMomentMapsToFlower() {
        let acts = [GardenActInput(id: id("00000000-0000-0000-0000-000000000001"),
                                   date: Date(), kind: .moment)]
        let elements = GardenComposer().compose(acts: acts)
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].kind, .flower)
        XCTAssertEqual(elements[0].sourceID, acts[0].id)
    }

    func testPlaceMapsToPlaceFlower() {
        let acts = [GardenActInput(id: id("00000000-0000-0000-0000-000000000002"),
                                   date: Date(), kind: .place)]
        XCTAssertEqual(GardenComposer().compose(acts: acts)[0].kind, .placeFlower)
    }

    func testLetterMapsToTree() {
        let acts = [GardenActInput(id: id("00000000-0000-0000-0000-000000000003"),
                                   date: Date(), kind: .letter)]
        XCTAssertEqual(GardenComposer().compose(acts: acts)[0].kind, .tree)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd GardenCore && swift test`
Expected: FAIL — `GardenActInput` / `GardenComposer` not found.

- [ ] **Step 3: Add the model types**

`GardenCore/Sources/GardenCore/GardenModels.swift`:
```swift
import Foundation

/// The kind of loving act a garden element grew from.
public enum GardenActKind: String, Codable, Equatable, Sendable {
    case moment   // a captured moment with no distinct place
    case place    // a moment tied to a named place / country
    case letter   // a written love letter
}

/// A minimal, UI-free description of one loving act. The app converts its real
/// `Moment` / `UserLetter` values into these so GardenCore stays pure.
public struct GardenActInput: Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let kind: GardenActKind

    public init(id: UUID, date: Date, kind: GardenActKind) {
        self.id = id
        self.date = date
        self.kind = kind
    }
}

/// The visual archetype an act becomes in the garden.
public enum GardenElementKind: String, Codable, Equatable, Sendable {
    case flower
    case placeFlower
    case tree
}

/// A normalized garden position in the unit square (0...1, origin bottom-left).
public struct GardenPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A grown garden element, ready to render. Position is derived (not stored) so
/// memories are never duplicated; the scene maps `position` into screen space.
public struct GardenElement: Equatable, Sendable {
    public let sourceID: UUID
    public let kind: GardenElementKind
    public let date: Date
    public let position: GardenPoint

    public init(sourceID: UUID, kind: GardenElementKind, date: Date, position: GardenPoint) {
        self.sourceID = sourceID
        self.kind = kind
        self.date = date
        self.position = position
    }
}
```

- [ ] **Step 4: Add the composer (mapping only; positioning stubbed to (0,0) for now)**

`GardenCore/Sources/GardenCore/GardenComposer.swift`:
```swift
import Foundation

/// Turns loving acts into renderable garden elements. Pure and deterministic:
/// the same acts always produce the same elements (positioning added in Task 3).
public struct GardenComposer {
    public init() {}

    public func compose(acts: [GardenActInput]) -> [GardenElement] {
        acts.map { act in
            GardenElement(
                sourceID: act.id,
                kind: Self.elementKind(for: act.kind),
                date: act.date,
                position: GardenPoint(x: 0, y: 0)
            )
        }
    }

    static func elementKind(for actKind: GardenActKind) -> GardenElementKind {
        switch actKind {
        case .moment: return .flower
        case .place:  return .placeFlower
        case .letter: return .tree
        }
    }
}
```

- [ ] **Step 5: Run to verify the mapping tests pass**

Run: `cd GardenCore && swift test`
Expected: PASS — 3 mapping tests + smoke test, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add GardenCore
git commit -m "feat(garden): act->element mapping in GardenComposer"
```

---

## Task 3: Deterministic UUID → position

**Files:**
- Modify: `GardenCore/Sources/GardenCore/GardenComposer.swift`
- Modify: `GardenCore/Tests/GardenCoreTests/GardenComposerTests.swift`

Swift's built-in `Hasher` is randomly seeded per process, so it CANNOT be used for cross-launch-stable positions. We hash the UUID's raw bytes with a fixed FNV-1a so positions are identical every run.

- [ ] **Step 1: Add failing determinism tests**

Append to `GardenComposerTests.swift` (inside the class):
```swift
    func testPositionIsStableAcrossRuns() {
        let act = GardenActInput(id: id("00000000-0000-0000-0000-0000000000AA"),
                                 date: Date(), kind: .moment)
        let a = GardenComposer().compose(acts: [act])[0].position
        let b = GardenComposer().compose(acts: [act])[0].position
        XCTAssertEqual(a, b)
        // Hard-coded expectation locks determinism across processes.
        XCTAssertEqual(a.x, 0.6627902418680846, accuracy: 0.000001)
        XCTAssertEqual(a.y, 0.2918646464282206, accuracy: 0.000001)
    }

    func testDifferentIDsGetDifferentPositions() {
        let a = GardenActInput(id: id("00000000-0000-0000-0000-0000000000AA"),
                               date: Date(), kind: .moment)
        let b = GardenActInput(id: id("00000000-0000-0000-0000-0000000000BB"),
                               date: Date(), kind: .moment)
        let positions = GardenComposer().compose(acts: [a, b]).map(\.position)
        XCTAssertNotEqual(positions[0], positions[1])
    }

    func testPositionsAreWithinPlantingBand() {
        // y is constrained to a lower "ground" band so blooms sit on the floor.
        let acts = (0..<50).map {
            GardenActInput(id: UUID(), date: Date(), kind: .moment)
        }
        for p in GardenComposer().compose(acts: acts).map(\.position) {
            XCTAssertTrue((0.05...0.95).contains(p.x), "x out of range: \(p.x)")
            XCTAssertTrue((0.08...0.42).contains(p.y), "y out of range: \(p.y)")
        }
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `cd GardenCore && swift test`
Expected: FAIL — positions are (0,0); accuracy + band assertions fail.

- [ ] **Step 3: Implement deterministic positioning**

Replace the body of `GardenComposer` in `GardenComposer.swift`:
```swift
import Foundation

/// Turns loving acts into renderable garden elements. Pure and deterministic:
/// the same acts always produce the same elements, including stable positions
/// seeded by each act's UUID (so the garden never reshuffles across launches).
public struct GardenComposer {
    public init() {}

    public func compose(acts: [GardenActInput]) -> [GardenElement] {
        acts.map { act in
            GardenElement(
                sourceID: act.id,
                kind: Self.elementKind(for: act.kind),
                date: act.date,
                position: Self.position(for: act.id)
            )
        }
    }

    static func elementKind(for actKind: GardenActKind) -> GardenElementKind {
        switch actKind {
        case .moment: return .flower
        case .place:  return .placeFlower
        case .letter: return .tree
        }
    }

    /// Deterministic position in the planting band, seeded by the act's UUID.
    /// x spans 0.05...0.95, y is constrained to a low ground band 0.08...0.42.
    static func position(for id: UUID) -> GardenPoint {
        let h = fnv1a(id)
        let xBits = UInt32(truncatingIfNeeded: h)
        let yBits = UInt32(truncatingIfNeeded: h >> 32)
        let xUnit = Double(xBits) / Double(UInt32.max)
        let yUnit = Double(yBits) / Double(UInt32.max)
        let x = 0.05 + xUnit * 0.90
        let y = 0.08 + yUnit * 0.34
        return GardenPoint(x: x, y: y)
    }

    /// Fixed FNV-1a over the UUID's 16 raw bytes (NOT Swift's randomized Hasher),
    /// so the value is identical across processes and launches.
    static func fnv1a(_ id: UUID) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        let b = id.uuid
        let bytes = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7,
                     b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15]
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}
```

- [ ] **Step 4: Run and confirm the determinism values**

Run: `cd GardenCore && swift test`
Expected: PASS. If `testPositionIsStableAcrossRuns` fails ONLY on the hard-coded `accuracy` expectation (not on the a==b equality), the algorithm is still deterministic — read the actual printed values and update the two literals to match, then re-run. The cross-run equality and band assertions must pass as written.

- [ ] **Step 5: Commit**

```bash
git add GardenCore
git commit -m "feat(garden): deterministic UUID-seeded bloom positions"
```

---

## Task 4: Season / resting-state resolver

**Files:**
- Create: `GardenCore/Sources/GardenCore/GardenSeasonResolver.swift`
- Create: `GardenCore/Tests/GardenCoreTests/GardenSeasonResolverTests.swift`
- Modify: `GardenCore/Sources/GardenCore/GardenModels.swift`

- [ ] **Step 1: Add the `GardenSeason` type**

Append to `GardenModels.swift`:
```swift
/// The garden's mood. `resting` is the kind dormancy state (calm palette) the
/// garden enters after a quiet stretch — it never wilts or loses progress.
public enum GardenSeason: String, Codable, Equatable, Sendable {
    case blooming
    case resting
}
```

- [ ] **Step 2: Write failing resolver tests**

`GardenCore/Tests/GardenCoreTests/GardenSeasonResolverTests.swift`:
```swift
import XCTest
@testable import GardenCore

final class GardenSeasonResolverTests: XCTestCase {
    private let resolver = GardenSeasonResolver()
    private func days(_ n: Double) -> TimeInterval { n * 86_400 }

    func testRecentActivityIsBlooming() {
        let now = Date()
        let last = now.addingTimeInterval(-days(3))
        XCTAssertEqual(resolver.season(lastActivity: last, now: now), .blooming)
    }

    func testQuietStretchEntersResting() {
        let now = Date()
        let last = now.addingTimeInterval(-days(20))
        XCTAssertEqual(resolver.season(lastActivity: last, now: now), .resting)
    }

    func testNoActivityYetIsBlooming() {
        // A brand-new garden with no acts shows as gently blooming, never resting.
        XCTAssertEqual(resolver.season(lastActivity: nil, now: Date()), .blooming)
    }

    func testThresholdBoundaryIsResting() {
        let now = Date()
        let last = now.addingTimeInterval(-days(14))
        XCTAssertEqual(resolver.season(lastActivity: last, now: now), .resting)
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `cd GardenCore && swift test`
Expected: FAIL — `GardenSeasonResolver` not found.

- [ ] **Step 4: Implement the resolver**

`GardenCore/Sources/GardenCore/GardenSeasonResolver.swift`:
```swift
import Foundation

/// Decides whether the garden is blooming or gently resting. Pure function of
/// the last-activity timestamp — never punishing, never lossy.
public struct GardenSeasonResolver {
    /// A garden with no activity for this long enters its calm resting season.
    public let restingThreshold: TimeInterval

    public init(restingThreshold: TimeInterval = 14 * 86_400) {
        self.restingThreshold = restingThreshold
    }

    public func season(lastActivity: Date?, now: Date = Date()) -> GardenSeason {
        guard let lastActivity else { return .blooming }
        let elapsed = now.timeIntervalSince(lastActivity)
        return elapsed >= restingThreshold ? .resting : .blooming
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `cd GardenCore && swift test`
Expected: PASS — all resolver tests green.

- [ ] **Step 6: Commit**

```bash
git add GardenCore
git commit -m "feat(garden): season/resting resolver"
```

---

## Task 5: `GardenState` + warm revival logic

**Files:**
- Create: `GardenCore/Sources/GardenCore/GardenState.swift`
- Create: `GardenCore/Tests/GardenCoreTests/GardenStateTests.swift`

- [ ] **Step 1: Write failing state/revival tests**

`GardenCore/Tests/GardenCoreTests/GardenStateTests.swift`:
```swift
import XCTest
@testable import GardenCore

final class GardenStateTests: XCTestCase {
    private func days(_ n: Double) -> TimeInterval { n * 86_400 }

    func testRegisteringActAfterRestRevives() {
        let now = Date()
        var state = GardenState(lastActivity: now.addingTimeInterval(-days(30)))
        let result = state.registering(actAt: now)
        XCTAssertTrue(result.didRevive, "garden was resting and should revive")
        XCTAssertEqual(result.state.lastActivity, now)
        XCTAssertEqual(result.state.season(now: now), .blooming)
    }

    func testRegisteringActWhileBloomingDoesNotRevive() {
        let now = Date()
        var state = GardenState(lastActivity: now.addingTimeInterval(-days(2)))
        let result = state.registering(actAt: now)
        XCTAssertFalse(result.didRevive)
        XCTAssertEqual(result.state.lastActivity, now)
    }

    func testFirstEverActDoesNotCountAsRevival() {
        let now = Date()
        var state = GardenState(lastActivity: nil)
        let result = state.registering(actAt: now)
        XCTAssertFalse(result.didRevive, "a brand-new garden isn't 'reviving'")
        XCTAssertEqual(result.state.lastActivity, now)
    }

    func testCodableRoundTrips() throws {
        let original = GardenState(lastActivity: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GardenState.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd GardenCore && swift test`
Expected: FAIL — `GardenState` not found.

- [ ] **Step 3: Implement `GardenState`**

`GardenCore/Sources/GardenCore/GardenState.swift`:
```swift
import Foundation

/// The only persisted garden state: when the garden was last tended. Bloom
/// positions are derived from act UUIDs (see GardenComposer), so memories are
/// never duplicated here. Shaped to migrate to a per-couple backend record later.
public struct GardenState: Codable, Equatable, Sendable {
    public var lastActivity: Date?

    public init(lastActivity: Date? = nil) {
        self.lastActivity = lastActivity
    }

    /// Tolerant decode: a missing field defaults rather than failing, so the
    /// format can grow safely (mirrors `PetState`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastActivity = try c.decodeIfPresent(Date.self, forKey: .lastActivity)
    }

    public func season(resolver: GardenSeasonResolver = GardenSeasonResolver(),
                       now: Date = Date()) -> GardenSeason {
        resolver.season(lastActivity: lastActivity, now: now)
    }

    /// Records a new loving act. Returns the updated state and whether this act
    /// revived a resting garden (so the UI can show the warm welcome-back line).
    public func registering(actAt date: Date,
                            resolver: GardenSeasonResolver = GardenSeasonResolver())
    -> (state: GardenState, didRevive: Bool) {
        let wasResting = lastActivity != nil
            && resolver.season(lastActivity: lastActivity, now: date) == .resting
        var copy = self
        copy.lastActivity = date
        return (copy, wasResting)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd GardenCore && swift test`
Expected: PASS — all GardenState tests green.

- [ ] **Step 5: Commit**

```bash
git add GardenCore
git commit -m "feat(garden): GardenState persistence + warm revival logic"
```

---

## Task 6: Wire `GardenCore` into the app + persist `GardenState`

**Files:**
- Modify: `BabyTown.xcodeproj` (via Xcode UI)
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

- [ ] **Step 1: Add the local package dependency (Xcode UI)**

In Xcode: File → Add Package Dependencies… → "Add Local…" → select the `GardenCore` folder at the repo root → add the `GardenCore` library product to the **BabyTown** target. This edits `BabyTown.xcodeproj/project.pbxproj` (the one supported project change in this plan).

- [ ] **Step 2: Add a tolerant load/save for `GardenState` in DataPersistenceManager**

In `BabyTown/Services/DataPersistenceManager.swift`, add the import at the top of the file (just below `import UIKit`):
```swift
import GardenCore
```

Add the file URL next to the other `…FileURL` computed properties (after `petStateFileURL`):
```swift
    private var gardenStateFileURL: URL {
        documentsDirectory.appendingPathComponent("garden_state.json")
    }
```

Add the load/save methods next to `savePetState`/`loadPetState`:
```swift
    func saveGardenState(_ state: GardenState) {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: gardenStateFileURL)
    }

    /// Tolerant load — returns a fresh, blooming garden when nothing is stored.
    func loadGardenState() -> GardenState {
        guard fileManager.fileExists(atPath: gardenStateFileURL.path),
              let data = try? Data(contentsOf: gardenStateFileURL),
              let state = try? decoder.decode(GardenState.self, from: data) else {
            return GardenState()
        }
        return state
    }
```

- [ ] **Step 3: Build the app to verify the package links and compiles**

Run:
```
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add BabyTown.xcodeproj BabyTown/Services/DataPersistenceManager.swift
git commit -m "feat(garden): link GardenCore + persist GardenState via DPM"
```

---

## Task 7: App adapter — real moments/letters → `GardenActInput`

**Files:**
- Create: `BabyTown/Game/Garden/GardenActMapper.swift`

This file lives in the app target (it needs `Moment`/`UserLetter`), so its logic is verified by `xcodebuild` compiling + the simulator render in later tasks (the pure mapping rules themselves are already covered by `GardenComposerTests`).

- [ ] **Step 1: Implement the adapter**

`BabyTown/Game/Garden/GardenActMapper.swift`:
```swift
import Foundation
import GardenCore

/// Converts the app's real relationship data (`Moment`, `UserLetter`) into the
/// UI-free `GardenActInput` values GardenCore understands. A moment with a
/// non-empty place becomes a `.place` act; a plain moment becomes `.moment`;
/// every letter becomes `.letter`.
enum GardenActMapper {
    static func acts(moments: [Moment], letters: [UserLetter]) -> [GardenActInput] {
        var result: [GardenActInput] = []

        for moment in moments {
            let hasPlace = (moment.placeName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            result.append(GardenActInput(
                id: moment.id,
                date: moment.dateTaken,
                kind: hasPlace ? .place : .moment
            ))
        }

        for letter in letters {
            result.append(GardenActInput(
                id: letter.id,
                date: letter.sortDate,
                kind: .letter
            ))
        }

        return result
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Game/Garden/GardenActMapper.swift
git commit -m "feat(garden): map Moment/UserLetter to GardenActInput"
```

---

## Task 8: `LoveGardenScene` — render blooms procedurally

**Files:**
- Create: `BabyTown/Game/Garden/LoveGardenScene.swift`

Mirror `PetRoomScene`'s init pattern. Render each element as a procedural node at its normalized position. No animation yet (added in Task 9).

- [ ] **Step 1: Implement the scene skeleton + procedural drawing**

`BabyTown/Game/Garden/LoveGardenScene.swift`:
```swift
import SpriteKit
import GardenCore

/// The Love Garden scene. Renders garden elements (grown from the couple's
/// moments and letters) as procedural blooms — no art assets required. Sibling
/// to `PetRoomScene`; the cat room is never touched.
final class LoveGardenScene: SKScene {

    /// Reports the source act id of a tapped bloom so the SwiftUI layer can
    /// surface that memory.
    var onTapElement: ((UUID) -> Void)?

    private let elements: [GardenElement]
    private let season: GardenSeason
    private var elementNodes: [UUID: SKNode] = [:]

    init(size: CGSize, elements: [GardenElement], season: GardenSeason) {
        self.elements = elements
        self.season = season
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = Self.skyColor(for: season)
        drawGround()
        for element in elements {
            let node = makeNode(for: element)
            node.position = screenPosition(for: element.position)
            node.zPosition = node.position.y   // lower on screen draws in front
            node.name = element.sourceID.uuidString
            addChild(node)
            elementNodes[element.sourceID] = node
        }
    }

    // MARK: Layout

    private func screenPosition(for p: GardenPoint) -> CGPoint {
        CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
    }

    private func drawGround() {
        let ground = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width,
                                              height: size.height * 0.45))
        ground.fillColor = Self.groundColor(for: season)
        ground.strokeColor = .clear
        ground.zPosition = -1
        addChild(ground)
    }

    // MARK: Procedural elements

    private func makeNode(for element: GardenElement) -> SKNode {
        switch element.kind {
        case .flower:      return makeFlower(petalColor: Self.flowerPalette(season))
        case .placeFlower: return makeFlower(petalColor: Self.placePalette(season))
        case .tree:        return makeTree()
        }
    }

    private func makeFlower(petalColor: SKColor) -> SKNode {
        let container = SKNode()

        let stem = SKShapeNode(rect: CGRect(x: -2, y: 0, width: 4, height: 46))
        stem.fillColor = SKColor(red: 0.36, green: 0.55, blue: 0.32, alpha: 1)
        stem.strokeColor = .clear
        container.addChild(stem)

        let head = SKNode()
        head.position = CGPoint(x: 0, y: 50)
        for i in 0..<6 {
            let petal = SKShapeNode(ellipseOf: CGSize(width: 12, height: 22))
            petal.fillColor = petalColor
            petal.strokeColor = .clear
            petal.zRotation = CGFloat(i) * (.pi / 3)
            petal.position = CGPoint(x: 0, y: 12)
            let holder = SKNode()
            holder.zRotation = CGFloat(i) * (.pi / 3)
            holder.addChild(petal)
            head.addChild(holder)
        }
        let center = SKShapeNode(circleOfRadius: 7)
        center.fillColor = SKColor(red: 0.98, green: 0.85, blue: 0.45, alpha: 1)
        center.strokeColor = .clear
        head.addChild(center)
        container.addChild(head)
        return container
    }

    private func makeTree() -> SKNode {
        let container = SKNode()
        let trunk = SKShapeNode(rect: CGRect(x: -5, y: 0, width: 10, height: 70))
        trunk.fillColor = SKColor(red: 0.45, green: 0.33, blue: 0.24, alpha: 1)
        trunk.strokeColor = .clear
        container.addChild(trunk)

        let canopy = SKShapeNode(circleOfRadius: 34)
        canopy.position = CGPoint(x: 0, y: 86)
        canopy.fillColor = SKColor(red: 0.34, green: 0.56, blue: 0.34, alpha: 1)
        canopy.strokeColor = .clear
        container.addChild(canopy)
        return container
    }

    // MARK: Palette (season-aware; resting is calmer / cooler)

    static func skyColor(for season: GardenSeason) -> SKColor {
        switch season {
        case .blooming: return SKColor(red: 0.78, green: 0.90, blue: 0.98, alpha: 1)
        case .resting:  return SKColor(red: 0.83, green: 0.86, blue: 0.92, alpha: 1)
        }
    }
    static func groundColor(for season: GardenSeason) -> SKColor {
        switch season {
        case .blooming: return SKColor(red: 0.66, green: 0.80, blue: 0.55, alpha: 1)
        case .resting:  return SKColor(red: 0.74, green: 0.78, blue: 0.74, alpha: 1)
        }
    }
    static func flowerPalette(_ season: GardenSeason) -> SKColor {
        switch season {
        case .blooming: return SKColor(red: 0.93, green: 0.45, blue: 0.62, alpha: 1)
        case .resting:  return SKColor(red: 0.74, green: 0.66, blue: 0.78, alpha: 1)
        }
    }
    static func placePalette(_ season: GardenSeason) -> SKColor {
        switch season {
        case .blooming: return SKColor(red: 0.55, green: 0.62, blue: 0.95, alpha: 1)
        case .resting:  return SKColor(red: 0.62, green: 0.66, blue: 0.80, alpha: 1)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Game/Garden/LoveGardenScene.swift
git commit -m "feat(garden): procedural LoveGardenScene rendering"
```

---

## Task 9: Living layer — sway, growth, ambient particles

**Files:**
- Modify: `BabyTown/Game/Garden/LoveGardenScene.swift`

- [ ] **Step 1: Add ambient sway + sprout→bloom growth in `didMove`**

In `LoveGardenScene.swift`, replace the `for element in elements { … }` loop inside `didMove(to:)` with:
```swift
        for (index, element) in elements.enumerated() {
            let node = makeNode(for: element)
            node.position = screenPosition(for: element.position)
            node.zPosition = node.position.y
            node.name = element.sourceID.uuidString
            addChild(node)
            elementNodes[element.sourceID] = node

            animateGrowth(node, delay: Double(index) * 0.03)
            addSway(to: node, seed: element.position.x)
        }
        addAmbientParticles()
```

- [ ] **Step 2: Add the animation + particle helpers**

Add these methods to `LoveGardenScene`:
```swift
    /// Sprout → bloom: pop up from nothing with a gentle overshoot.
    private func animateGrowth(_ node: SKNode, delay: TimeInterval) {
        node.setScale(0)
        let grow = SKAction.sequence([
            .wait(forDuration: delay),
            .scale(to: 1.08, duration: 0.28),
            .scale(to: 1.0, duration: 0.12),
        ])
        grow.timingMode = .easeOut
        node.run(grow)
    }

    /// Gentle, endless sway. The seed offsets each bloom's phase so the field
    /// doesn't move in lockstep.
    private func addSway(to node: SKNode, seed: Double) {
        let amplitude: CGFloat = 0.05
        let phase = SKAction.sequence([
            .rotate(toAngle: amplitude, duration: 1.6),
            .rotate(toAngle: -amplitude, duration: 1.6),
        ])
        phase.timingMode = .easeInEaseOut
        let sway = SKAction.repeatForever(phase)
        node.run(.sequence([.wait(forDuration: seed.truncatingRemainder(dividingBy: 1.0) * 1.6), sway]))
    }

    /// Drifting pollen by day, fireflies feel at dusk. Pure code (no art).
    private func addAmbientParticles() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.softDot()
        emitter.position = CGPoint(x: size.width / 2, y: size.height)
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        emitter.particleBirthRate = 6
        emitter.particleLifetime = 14
        emitter.particleSpeed = 18
        emitter.particleSpeedRange = 10
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 6
        emitter.particleAlpha = 0.55
        emitter.particleAlphaRange = 0.3
        emitter.particleScale = 0.18
        emitter.particleScaleRange = 0.12
        emitter.particleColor = (season == .resting)
            ? SKColor.white
            : SKColor(red: 1.0, green: 0.95, blue: 0.7, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.zPosition = 5000
        addChild(emitter)
    }

    /// A small soft circle texture used for particles, generated in code.
    static func softDot() -> SKTexture {
        let d: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor)
            c.fillEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
        }
        return SKTexture(image: image)
    }
```

Add `import UIKit` at the top of the file (needed for `UIGraphicsImageRenderer`):
```swift
import UIKit
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Game/Garden/LoveGardenScene.swift
git commit -m "feat(garden): sway, sprout->bloom growth, ambient particles"
```

---

## Task 10: Tap-to-remember reporting

**Files:**
- Modify: `BabyTown/Game/Garden/LoveGardenScene.swift`

- [ ] **Step 1: Add touch handling that reports the tapped element**

Add to `LoveGardenScene`:
```swift
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        // Walk up from the hit node to find the element container we named.
        var node: SKNode? = atPoint(location)
        while let current = node {
            if let name = current.name, let id = UUID(uuidString: name) {
                let bump = SKAction.sequence([.scale(to: 1.18, duration: 0.08),
                                              .scale(to: 1.0, duration: 0.12)])
                current.run(bump)
                onTapElement?(id)
                return
            }
            node = current.parent
        }
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Game/Garden/LoveGardenScene.swift
git commit -m "feat(garden): report tapped bloom for tap-to-remember"
```

---

## Task 11: `LoveGardenView` — host scene, revival banner, memory overlay

**Files:**
- Create: `BabyTown/Views/LoveGardenView.swift`

Mirror `PetRoomView`'s `SpriteView(scene:)`-inside-`GeometryReader` pattern. Compose the garden on appear, register today's activity (driving the warm revival line), and show a memory card when a bloom is tapped.

- [ ] **Step 1: Implement the view**

`BabyTown/Views/LoveGardenView.swift`:
```swift
import SwiftUI
import SpriteKit
import GardenCore

/// SwiftUI host for the Love Garden scene. Loads the couple's moments + letters,
/// grows the garden, shows the warm "welcome back" line when a resting garden is
/// revived, and surfaces a memory card when a bloom is tapped.
struct LoveGardenView: View {
    @State private var scene: LoveGardenScene?
    @State private var moments: [Moment] = []
    @State private var tappedMoment: Moment?
    @State private var revivalMessage: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    Color(red: 0.78, green: 0.90, blue: 0.98).ignoresSafeArea()
                }

                if let revivalMessage {
                    VStack {
                        Text(revivalMessage)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 12)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear { buildGarden(size: geo.size) }
            .sheet(item: $tappedMoment) { moment in
                GardenMemoryCard(moment: moment)
                    .presentationDetents([.medium])
            }
        }
    }

    private func buildGarden(size: CGSize) {
        guard scene == nil else { return }
        let dpm = DataPersistenceManager.shared
        let loadedMoments = dpm.loadMoments()
        let letters = dpm.loadUserLetters()
        moments = loadedMoments

        let acts = GardenActMapper.acts(moments: loadedMoments, letters: letters)
        let elements = GardenComposer().compose(acts: acts)

        // Register today's visit; reflect & persist any warm revival.
        let now = Date()
        let stored = dpm.loadGardenState()
        let storedSeason = stored.season(now: now)
        let result = stored.registering(actAt: now)
        dpm.saveGardenState(result.state)
        if result.didRevive {
            withAnimation { revivalMessage = "Welcome back — your garden missed you 🌱" }
        }

        let newScene = LoveGardenScene(size: size, elements: elements, season: storedSeason)
        newScene.onTapElement = { id in
            tappedMoment = moments.first { $0.id == id }
        }
        scene = newScene
    }
}

/// Minimal memory card shown when a bloom is tapped (Slice 1).
private struct GardenMemoryCard: View {
    let moment: Moment

    var body: some View {
        VStack(spacing: 14) {
            Image(uiImage: moment.thumbnail)
                .resizable().scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if let place = moment.placeName, !place.isEmpty {
                Label(place, systemImage: "mappin.and.ellipse").font(.subheadline)
            }
            if let caption = moment.caption, !caption.isEmpty {
                Text(caption).font(.body).multilineTextAlignment(.center)
            }
            Text(moment.dateTaken, style: .date).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}
```

Note on the revival check: `registering(actAt:)` returns `didRevive == true` only when the stored garden was resting *before* this visit, so the welcome-back line shows exactly once per quiet stretch. We pass `storedSeason` (computed *before* registering) to the scene so the palette still reads the season the user is arriving into.

- [ ] **Step 2: Build to verify it compiles**

Run:
```
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/LoveGardenView.swift
git commit -m "feat(garden): LoveGardenView host + revival banner + memory card"
```

---

## Task 12: Temporary entry route + simulator verification

**Files:**
- Modify: `BabyTown/ContentView.swift`

This route is a Slice-1-only verification hook; it is replaced by the cat-room door in a later slice.

- [ ] **Step 1: Add a `.loveGarden` case to the Screen enum**

In `BabyTown/ContentView.swift`, change:
```swift
    enum Screen {
        case launch, welcome, storyOnboarding, nickname, firstMemories, howItWorks, photoAccess, home, selectPhotos
    }
```
to:
```swift
    enum Screen {
        case launch, welcome, storyOnboarding, nickname, firstMemories, howItWorks, photoAccess, home, selectPhotos
        case loveGarden   // TEMP (Slice 1): direct route to verify the garden; remove when the cat-room door lands.
    }
```

- [ ] **Step 2: Route the launch screen straight to the garden (temporary)**

Still in `ContentView.swift`, find the `init()` body block:
```swift
        // Always start with launch screen
        _screen = State(initialValue: .launch)
```
and change it to:
```swift
        // Always start with launch screen
        _screen = State(initialValue: .launch)
        // TEMP (Slice 1): jump straight to the Love Garden for verification.
        _targetScreen = State(initialValue: .loveGarden)
```
Place this line AFTER the existing `if hasCompletedOnboarding { … } else { … }` block so it overrides `targetScreen` for verification. (Delete this single line — and the enum case and the body case below — to restore normal flow.)

- [ ] **Step 3: Render the garden for the new case**

In `ContentView.swift`'s `body`, locate where screens are switched/rendered (the `switch screen` or equivalent that maps `.home`, `.selectPhotos`, etc. to views). Add a branch:
```swift
            case .loveGarden:
                LoveGardenView()
```
If the body uses `if screen == … ` checks rather than a `switch`, add the analogous:
```swift
            if screen == .loveGarden {
                LoveGardenView()
            }
```
Match the surrounding style exactly. The launch screen transitions to `targetScreen` after its animation; with the temp override that target is `.loveGarden`.

- [ ] **Step 4: Build, install, and launch in the simulator**

Run:
```
xcodebuild -project BabyTown.xcodeproj -scheme BabyTown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

Then install + launch on the booted simulator (read the built `.app` path from the build output's `TARGET_BUILD_DIR`, or use the standard DerivedData path), e.g.:
```
xcrun simctl install booted "$(xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null | awk -F' = ' '/ TARGET_BUILD_DIR /{print $2}')/BabyTown.app"
xcrun simctl launch booted <APP_BUNDLE_ID>
```
(Find `<APP_BUNDLE_ID>` via `PRODUCT_BUNDLE_IDENTIFIER` in `-showBuildSettings`.)

- [ ] **Step 5: Verify visually (screenshot)**

Run: `xcrun simctl io booted screenshot /tmp/garden.png` and open it.
Confirm: a sky + ground garden renders; blooms appear (one per existing moment/letter; place-moments are a different color; letters are trees); blooms sway and drifted up from a grow-in; ambient particles drift. Tapping a bloom presents the memory card. If you have no moments/letters yet in this simulator, the garden shows empty ground + sky + particles — that is correct for Slice 1 (capture a moment in the app first to see blooms, or note this as expected).

- [ ] **Step 6: Commit**

```bash
git add BabyTown/ContentView.swift
git commit -m "chore(garden): temporary entry route to verify Love Garden (Slice 1)"
```

---

## Self-Review (completed during planning)

**Spec coverage (§15.1):**
- Standalone code-drawn scene, sibling to room → Tasks 8–9 (`LoveGardenScene`); room untouched. ✓
- Reads existing moments/letters, no duplication → Tasks 6–7 (`GardenActMapper`, DPM loads). ✓
- Moment→flower, place→placeFlower, letter→tree → Tasks 2, 7. ✓
- Deterministic UUID-seeded positions, stable across launches → Task 3. ✓
- `GardenState` Codable + tolerant decode, season + last-activity only → Tasks 5–6. ✓
- Kindness/resting + warm revival, never lossy → Tasks 4, 5, 11. ✓
- Tap-to-remember overlay reusing moment display → Tasks 10–11. ✓
- Verify via temporary entry route in simulator → Task 12. ✓
- Out of scope (door, Us page, coins, gating, co-bloom) → not present. ✓
- "Love notes" caveat (no note store) → only moments + letters mapped (Task 7). ✓

**Placeholder scan:** No TBD/TODO-as-work; every code step shows complete code; commands have expected output. The one hard-coded determinism literal in Task 3 has an explicit recovery instruction. ✓

**Type consistency:** `GardenActInput(id:date:kind:)`, `GardenActKind{.moment,.place,.letter}`, `GardenElementKind{.flower,.placeFlower,.tree}`, `GardenComposer().compose(acts:)`, `GardenSeasonResolver().season(lastActivity:now:)`, `GardenState.registering(actAt:)` / `.season(now:)`, `LoveGardenScene(size:elements:season:)` + `onTapElement`, `GardenActMapper.acts(moments:letters:)`, `DataPersistenceManager.saveGardenState/loadGardenState` — names match across all tasks. ✓
