# BabyTown Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add six on-device notifications (pet-misses-you, litter-box reminder, milestone congrats, pet-needs, anniversary reminders) plus a 6 AM/6 PM litter schedule change, and lay dormant local stubs for the future partner-driven notifications.

**Architecture:** Pure, unit-tested decision logic lives in the `GardenCore` Swift package (`NotificationPlanner`, `LitterSchedule`, quiet-hours). The app's `NotificationManager.refresh()` rebuilds a `NotificationSnapshot` from persisted state (`DataPersistenceManager`), runs the planner, and translates the result into `UNNotificationRequest`s. `refresh()` is called on app launch, on `scenePhase` → background, and after relevant in-app actions (pet care, moment saved, special date changed). Milestones and partner stubs fire immediately on their event.

**Tech Stack:** Swift, SwiftUI, `UserNotifications`, SwiftPM (`GardenCore`), XCTest.

---

## File Structure

**GardenCore (pure logic + XCTest):**
- Create `GardenCore/Sources/GardenCore/NotificationQuietHours.swift` — quiet-hours clamp.
- Create `GardenCore/Sources/GardenCore/LitterSchedule.swift` — pure litter-use-event counter.
- Create `GardenCore/Sources/GardenCore/NotificationPlanner.swift` — snapshot types + planning.
- Create `GardenCore/Tests/GardenCoreTests/NotificationQuietHoursTests.swift`
- Create `GardenCore/Tests/GardenCoreTests/LitterScheduleTests.swift`
- Create `GardenCore/Tests/GardenCoreTests/NotificationPlannerTests.swift`

**App (integration; no app test target — verify via build + simulator):**
- Modify `BabyTown/Models/Pet.swift` — add `lastPetInteractionAt`.
- Modify `BabyTown/ViewModels/PetViewModel.swift` — use `LitterSchedule` ([6,18]); set `lastPetInteractionAt`; call `refresh`.
- Modify `BabyTown/Services/NotificationManager.swift` — `refresh`, snapshot builder, trigger mapping, partner stubs.
- Modify `BabyTown/Services/DataPersistenceManager.swift` — celebrated-milestones persistence.
- Modify `BabyTown/ViewModels/HomeViewModel.swift` — milestone firing + `refresh`.
- Modify `BabyTown/ContentView.swift` — `scenePhase` → `refresh`.
- Modify `BabyTown/Components/SettingsSheet.swift` — debug actions to fire partner stubs.

**Build/test commands:**
- Package tests: `swift test --package-path GardenCore`
- App build: `xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build` (trust xcodebuild over SourceKit per project memory).

---

## Task 1: Quiet-hours clamp (GardenCore)

**Files:**
- Create: `GardenCore/Sources/GardenCore/NotificationQuietHours.swift`
- Test: `GardenCore/Tests/GardenCoreTests/NotificationQuietHoursTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import GardenCore

final class NotificationQuietHoursTests: XCTestCase {
    private func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d; comps.hour = h; comps.minute = mi
        return calendar().date(from: comps)!
    }

    func testInsideWindowUnchanged() {
        let d = date(2026, 6, 3, 14, 30)
        XCTAssertEqual(NotificationQuietHours.clamp(d, calendar: calendar()), d)
    }

    func testBeforeWindowMovesTo9AmSameDay() {
        let d = date(2026, 6, 3, 6, 0)
        XCTAssertEqual(NotificationQuietHours.clamp(d, calendar: calendar()), date(2026, 6, 3, 9, 0))
    }

    func testAtOrAfterEndMovesTo9AmNextDay() {
        let d = date(2026, 6, 3, 22, 15)
        XCTAssertEqual(NotificationQuietHours.clamp(d, calendar: calendar()), date(2026, 6, 4, 9, 0))
    }

    func testExactlyEndHourMovesToNextDay() {
        let d = date(2026, 6, 3, 21, 0)
        XCTAssertEqual(NotificationQuietHours.clamp(d, calendar: calendar()), date(2026, 6, 4, 9, 0))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path GardenCore --filter NotificationQuietHoursTests`
Expected: FAIL — `cannot find 'NotificationQuietHours' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// Keeps computed notification fire-times inside a friendly daytime window so
/// nothing buzzes overnight. Fixed-time scheduled notifications (e.g. 8 AM
/// morning) are not routed through this.
public enum NotificationQuietHours {
    public static let startHour = 9   // 9:00 AM inclusive
    public static let endHour = 21    // 9:00 PM exclusive

    /// Returns `date` if it lands inside [9:00, 21:00); otherwise the next
    /// 9:00 AM (same day if before the window, next day if at/after it).
    public static func clamp(_ date: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: date)
        if hour >= startHour && hour < endHour { return date }
        let base = hour < startHour
            ? date
            : (calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: base) ?? date
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path GardenCore --filter NotificationQuietHoursTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add GardenCore/Sources/GardenCore/NotificationQuietHours.swift GardenCore/Tests/GardenCoreTests/NotificationQuietHoursTests.swift
git commit -m "feat(notifications): quiet-hours clamp helper in GardenCore"
```

---

## Task 2: Litter-use schedule pure helper (GardenCore)

Extracts the litter-use-event counting currently inlined in `PetViewModel` into a pure, tested helper parameterized by use-hours, so the schedule change to 6 AM/6 PM is data-driven and the same logic is reusable by `NotificationManager`.

**Files:**
- Create: `GardenCore/Sources/GardenCore/LitterSchedule.swift`
- Test: `GardenCore/Tests/GardenCoreTests/LitterScheduleTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import GardenCore

final class LitterScheduleTests: XCTestCase {
    private func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d; comps.hour = h
        return calendar().date(from: comps)!
    }

    func testNoEventsWhenCleanedAfterNow() {
        let cleaned = date(2026, 6, 3, 12)
        let now = date(2026, 6, 3, 11)
        XCTAssertEqual(LitterSchedule.useEventsSinceLastClean(cleanedAt: cleaned, now: now, calendar: calendar()), 0)
    }

    func testSixAmEventCountsAfterCleanAtMidnight() {
        // Cleaned 5 AM, now 7 AM → the 6 AM use happened.
        let cleaned = date(2026, 6, 3, 5)
        let now = date(2026, 6, 3, 7)
        XCTAssertEqual(LitterSchedule.useEventsSinceLastClean(cleanedAt: cleaned, now: now, calendar: calendar()), 1)
    }

    func testEveningUseAtSixPm() {
        // Cleaned 1 PM, now 7 PM → only the 6 PM use happened (not 6 AM, before clean).
        let cleaned = date(2026, 6, 3, 13)
        let now = date(2026, 6, 3, 19)
        XCTAssertEqual(LitterSchedule.useEventsSinceLastClean(cleanedAt: cleaned, now: now, calendar: calendar()), 1)
    }

    func testTwoDaysFourEvents() {
        // Cleaned 6/3 5 AM, now 6/4 7 AM → 6AM,6PM (6/3) + 6AM (6/4) = 3.
        let cleaned = date(2026, 6, 3, 5)
        let now = date(2026, 6, 4, 7)
        XCTAssertEqual(LitterSchedule.useEventsSinceLastClean(cleanedAt: cleaned, now: now, calendar: calendar()), 3)
    }

    func testDefaultUseHoursAreSixAndEighteen() {
        XCTAssertEqual(LitterSchedule.defaultUseHours, [6, 18])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path GardenCore --filter LitterScheduleTests`
Expected: FAIL — `cannot find 'LitterSchedule' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// Pure counter for scheduled litter-box "use" events between a clean and now.
/// The cat uses the box at fixed hours each day; an uncleaned box is dirty once
/// at least one use event has elapsed since the last clean.
public enum LitterSchedule {
    /// The cat uses the litter box at 6 AM and 6 PM (local Pacific time).
    public static let defaultUseHours = [6, 18]

    public static func useEventsSinceLastClean(
        cleanedAt: Date,
        now: Date,
        useHours: [Int] = defaultUseHours,
        calendar: Calendar
    ) -> Int {
        guard now > cleanedAt else { return 0 }
        let startDay = calendar.startOfDay(for: cleanedAt)
        let endDay = calendar.startOfDay(for: now)

        var uses = 0
        var day = startDay
        while day <= endDay {
            for hour in useHours {
                guard let event = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
                if event > cleanedAt, event <= now { uses += 1 }
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return uses
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path GardenCore --filter LitterScheduleTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add GardenCore/Sources/GardenCore/LitterSchedule.swift GardenCore/Tests/GardenCoreTests/LitterScheduleTests.swift
git commit -m "feat(notifications): pure litter-use schedule helper (6AM/6PM)"
```

---

## Task 3: NotificationPlanner — snapshot types + time-based planning (GardenCore)

**Files:**
- Create: `GardenCore/Sources/GardenCore/NotificationPlanner.swift`
- Test: `GardenCore/Tests/GardenCoreTests/NotificationPlannerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import GardenCore

final class NotificationPlannerTests: XCTestCase {
    private let planner = NotificationPlanner()
    private func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d; comps.hour = h; comps.minute = mi
        return calendar().date(from: comps)!
    }
    private func base(adopted: Bool = true) -> NotificationSnapshot {
        NotificationSnapshot(
            isPetAdopted: adopted,
            petName: "Mochi",
            userNickname: "Sam",
            lastPetInteractionAt: nil,
            litterIsDirty: false,
            hunger: nil,
            thirst: nil,
            specialDates: []
        )
    }

    func testNoPetMeansNoPetNotifications() {
        var s = base(adopted: false)
        s.litterIsDirty = true
        let plan = planner.plan(snapshot: s, now: date(2026, 6, 3, 12), calendar: calendar())
        XCTAssertTrue(plan.allSatisfy { $0.id != "pet_misses_you" && $0.id != "litter_box_noon" && $0.id != "pet_needs" })
    }

    func testPetMissesYouFiresSevenDaysAfterInteraction() {
        var s = base()
        s.lastPetInteractionAt = date(2026, 6, 1, 12)   // +7d = 6/8 12:00, inside window
        let plan = planner.plan(snapshot: s, now: date(2026, 6, 1, 13), calendar: calendar())
        let miss = plan.first { $0.id == "pet_misses_you" }!
        guard case let .interval(seconds) = miss.trigger else { return XCTFail() }
        let fire = date(2026, 6, 1, 13).addingTimeInterval(seconds)
        XCTAssertEqual(fire, date(2026, 6, 8, 12))
        XCTAssertEqual(miss.body, "Hi Sam, Mochi misses you 🐾")
    }

    func testPetMissesYouNoNicknameDropsName() {
        var s = base(); s.userNickname = nil
        s.lastPetInteractionAt = date(2026, 6, 1, 12)
        let plan = planner.plan(snapshot: s, now: date(2026, 6, 1, 13), calendar: calendar())
        XCTAssertEqual(plan.first { $0.id == "pet_misses_you" }!.body, "Mochi misses you 🐾")
    }

    func testLitterNoonOnlyWhenDirty() {
        var s = base(); s.litterIsDirty = true
        let plan = planner.plan(snapshot: s, now: date(2026, 6, 3, 9), calendar: calendar())
        let litter = plan.first { $0.id == "litter_box_noon" }!
        guard case let .calendarDaily(hour, minute) = litter.trigger else { return XCTFail() }
        XCTAssertEqual(hour, 12); XCTAssertEqual(minute, 0)
    }

    func testPetNeedsHungerCrossingClampedIntoWindow() {
        var s = base()
        // hunger 60, gate 50, decay 10/h → crosses in 1h. now 8 PM → raw fire 9 PM → clamp to next 9 AM.
        s.hunger = PetNeedSnapshot(level: 60, decayPerHour: 10, gate: 50)
        let now = date(2026, 6, 3, 20)
        let plan = planner.plan(snapshot: s, now: now, calendar: calendar())
        let needs = plan.first { $0.id == "pet_needs" }!
        guard case let .interval(seconds) = needs.trigger else { return XCTFail() }
        XCTAssertEqual(now.addingTimeInterval(seconds), date(2026, 6, 4, 9))
    }

    func testPetNeedsCombinedWhenBothAlreadyLow() {
        var s = base()
        s.hunger = PetNeedSnapshot(level: 40, decayPerHour: 10, gate: 50)
        s.thirst = PetNeedSnapshot(level: 30, decayPerHour: 10, gate: 50)
        let plan = planner.plan(snapshot: s, now: date(2026, 6, 3, 12), calendar: calendar())
        XCTAssertEqual(plan.first { $0.id == "pet_needs" }!.body, "Mochi is hungry and thirsty")
    }

    func testSpecialDatesProduceAnnualTriggers() {
        var s = base()
        s.specialDates = [PlannerSpecialDate(id: "abc", title: "Anniversary", date: date(2025, 9, 14, 0))]
        let plan = planner.plan(snapshot: s, now: date(2026, 6, 3, 12), calendar: calendar())
        let sd = plan.first { $0.id == "special_date_abc" }!
        guard case let .calendarAnnual(month, day, hour, minute) = sd.trigger else { return XCTFail() }
        XCTAssertEqual([month, day, hour, minute], [9, 14, 9, 0])
        XCTAssertEqual(sd.title, "Anniversary 💞")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path GardenCore --filter NotificationPlannerTests`
Expected: FAIL — `cannot find 'NotificationPlanner' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

public struct PetNeedSnapshot: Equatable {
    public var level: Double          // current 0–100 at snapshot `now`
    public var decayPerHour: Double
    public var gate: Double           // "low" threshold (PetEconomy.feedThirstGate)
    public init(level: Double, decayPerHour: Double, gate: Double) {
        self.level = level; self.decayPerHour = decayPerHour; self.gate = gate
    }
}

public struct PlannerSpecialDate: Equatable {
    public var id: String
    public var title: String
    public var date: Date
    public init(id: String, title: String, date: Date) {
        self.id = id; self.title = title; self.date = date
    }
}

public struct NotificationSnapshot {
    public var isPetAdopted: Bool
    public var petName: String?
    public var userNickname: String?
    public var lastPetInteractionAt: Date?
    public var litterIsDirty: Bool
    public var hunger: PetNeedSnapshot?
    public var thirst: PetNeedSnapshot?
    public var specialDates: [PlannerSpecialDate]
    public init(isPetAdopted: Bool, petName: String?, userNickname: String?,
                lastPetInteractionAt: Date?, litterIsDirty: Bool,
                hunger: PetNeedSnapshot?, thirst: PetNeedSnapshot?,
                specialDates: [PlannerSpecialDate]) {
        self.isPetAdopted = isPetAdopted; self.petName = petName
        self.userNickname = userNickname; self.lastPetInteractionAt = lastPetInteractionAt
        self.litterIsDirty = litterIsDirty; self.hunger = hunger; self.thirst = thirst
        self.specialDates = specialDates
    }
}

public enum PlannedTrigger: Equatable {
    case interval(TimeInterval)                                   // one-shot, seconds from now
    case calendarDaily(hour: Int, minute: Int)                   // repeats daily
    case calendarAnnual(month: Int, day: Int, hour: Int, minute: Int)  // repeats yearly
}

public struct PlannedNotification: Equatable {
    public var id: String
    public var title: String
    public var body: String
    public var trigger: PlannedTrigger
}

public struct NotificationPlanner {
    public init() {}

    public func plan(snapshot s: NotificationSnapshot, now: Date, calendar: Calendar) -> [PlannedNotification] {
        var out: [PlannedNotification] = []
        if s.isPetAdopted {
            out.append(petMissesYou(s, now: now, calendar: calendar))
            if s.litterIsDirty { out.append(litterNoon(s)) }
            if let needs = petNeeds(s, now: now, calendar: calendar) { out.append(needs) }
        }
        out.append(contentsOf: specialDates(s, calendar: calendar))
        return out
    }

    private func petMissesYou(_ s: NotificationSnapshot, now: Date, calendar: Calendar) -> PlannedNotification {
        let name = s.petName ?? "Someone"
        let candidate = (s.lastPetInteractionAt ?? now).addingTimeInterval(7 * 86_400)
        let target = max(candidate, now)
        let fire = NotificationQuietHours.clamp(target, calendar: calendar)
        let body: String
        if let nick = s.userNickname, !nick.isEmpty {
            body = "Hi \(nick), \(name) misses you 🐾"
        } else {
            body = "\(name) misses you 🐾"
        }
        return PlannedNotification(id: "pet_misses_you", title: "\(name) misses you",
                                   body: body, trigger: .interval(max(1, fire.timeIntervalSince(now))))
    }

    private func litterNoon(_ s: NotificationSnapshot) -> PlannedNotification {
        let name = s.petName ?? "Your pet"
        return PlannedNotification(id: "litter_box_noon", title: "Litter box needs you",
                                   body: "\(name)'s litter box could use a cleanup 🧹",
                                   trigger: .calendarDaily(hour: 12, minute: 0))
    }

    private func petNeeds(_ s: NotificationSnapshot, now: Date, calendar: Calendar) -> PlannedNotification? {
        func hoursToGate(_ need: PetNeedSnapshot?) -> Double? {
            guard let need, need.decayPerHour > 0 else { return nil }
            let remaining = need.level - need.gate
            return remaining <= 0 ? 0 : remaining / need.decayPerHour
        }
        let h = hoursToGate(s.hunger)
        let t = hoursToGate(s.thirst)
        guard let soonest = [h, t].compactMap({ $0 }).min() else { return nil }
        let fire = NotificationQuietHours.clamp(now.addingTimeInterval(soonest * 3600), calendar: calendar)
        let name = s.petName ?? "Your pet"
        let title: String
        let body: String
        if h == 0 && t == 0 {
            title = "\(name) needs you"; body = "\(name) is hungry and thirsty"
        } else if (h ?? .infinity) <= (t ?? .infinity) {
            title = "\(name) is getting hungry 🍽️"; body = "Time to refill the food bowl"
        } else {
            title = "\(name) is thirsty 💧"; body = "Time to refill the water bowl"
        }
        return PlannedNotification(id: "pet_needs", title: title, body: body,
                                   trigger: .interval(max(1, fire.timeIntervalSince(now))))
    }

    private func specialDates(_ s: NotificationSnapshot, calendar: Calendar) -> [PlannedNotification] {
        s.specialDates.map { sd in
            let comps = calendar.dateComponents([.month, .day], from: sd.date)
            return PlannedNotification(
                id: "special_date_\(sd.id)",
                title: "\(sd.title) 💞",
                body: "Today's the day — \(sd.title).",
                trigger: .calendarAnnual(month: comps.month ?? 1, day: comps.day ?? 1, hour: 9, minute: 0))
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path GardenCore --filter NotificationPlannerTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add GardenCore/Sources/GardenCore/NotificationPlanner.swift GardenCore/Tests/GardenCoreTests/NotificationPlannerTests.swift
git commit -m "feat(notifications): NotificationPlanner time-based planning in GardenCore"
```

---

## Task 4: Milestone crossing logic (GardenCore)

**Files:**
- Modify: `GardenCore/Sources/GardenCore/NotificationPlanner.swift` (append)
- Test: `GardenCore/Tests/GardenCoreTests/NotificationPlannerTests.swift` (append a new class)

- [ ] **Step 1: Write the failing test**

Append to `NotificationPlannerTests.swift`:

```swift
final class MomentMilestoneTests: XCTestCase {
    private let planner = NotificationPlanner()

    func testThresholdsAreTheAgreedSet() {
        XCTAssertEqual(NotificationPlanner.momentMilestones, [10, 50, 100, 250, 500, 1000])
    }

    func testCrossingOneThreshold() {
        XCTAssertEqual(planner.crossedMilestones(oldCount: 9, newCount: 10, alreadyCelebrated: []), [10])
    }

    func testNoCrossingReturnsEmpty() {
        XCTAssertEqual(planner.crossedMilestones(oldCount: 11, newCount: 12, alreadyCelebrated: []), [])
    }

    func testBulkCrossingReturnsAllCrossed() {
        XCTAssertEqual(planner.crossedMilestones(oldCount: 5, newCount: 300, alreadyCelebrated: []), [10, 50, 100, 250])
    }

    func testAlreadyCelebratedExcluded() {
        XCTAssertEqual(planner.crossedMilestones(oldCount: 5, newCount: 60, alreadyCelebrated: [10]), [50])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path GardenCore --filter MomentMilestoneTests`
Expected: FAIL — `momentMilestones`/`crossedMilestones` not found.

- [ ] **Step 3: Write minimal implementation**

Append inside `NotificationPlanner` (before its closing brace):

```swift
    public static let momentMilestones = [10, 50, 100, 250, 500, 1000]

    /// Milestones strictly above `oldCount`, at or below `newCount`, not yet
    /// celebrated. Caller fires the max (one banner per batch) and records all
    /// returned values as celebrated so the skipped lower ones never re-fire.
    public func crossedMilestones(oldCount: Int, newCount: Int, alreadyCelebrated: Set<Int>) -> [Int] {
        guard newCount > oldCount else { return [] }
        return Self.momentMilestones.filter { $0 > oldCount && $0 <= newCount && !alreadyCelebrated.contains($0) }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path GardenCore --filter MomentMilestoneTests`
Expected: PASS (5 tests). Also run the full package: `swift test --package-path GardenCore` → all green.

- [ ] **Step 5: Commit**

```bash
git add GardenCore/Sources/GardenCore/NotificationPlanner.swift GardenCore/Tests/GardenCoreTests/NotificationPlannerTests.swift
git commit -m "feat(notifications): moment-milestone crossing logic"
```

---

## Task 5: Add `lastPetInteractionAt` to pet state (App)

**Files:**
- Modify: `BabyTown/Models/Pet.swift`

- [ ] **Step 1: Add the coding key**

In `PetState.CodingKeys` (around line 102), change:

```swift
        case lastPetAt, lastPlayAt, lastPlantWaterAt, customPetNames
```
to:
```swift
        case lastPetAt, lastPlayAt, lastPlantWaterAt, customPetNames, lastPetInteractionAt
```

- [ ] **Step 2: Add the stored property**

After `var lastPlayAt: Date?` (line 123), add:

```swift
    /// Most recent time the user touched the pet/pet-room (room opened or any
    /// care action). Drives the 7-day "pet misses you" notification timer.
    var lastPetInteractionAt: Date?
```

- [ ] **Step 3: Initialize in `init`**

After `self.lastPlayAt = nil` (line 150), add:

```swift
        self.lastPetInteractionAt = nil
```

- [ ] **Step 4: Encode**

After `try c.encodeIfPresent(lastPlayAt, forKey: .lastPlayAt)` (line 170), add:

```swift
        try c.encodeIfPresent(lastPetInteractionAt, forKey: .lastPetInteractionAt)
```

- [ ] **Step 5: Decode**

In `init(from:)`, locate where `lastPlayAt` is decoded and add directly after it:

```swift
        lastPetInteractionAt = try c.decodeIfPresent(Date.self, forKey: .lastPetInteractionAt)
```

(If `lastPlayAt` is not explicitly decoded in `init(from:)`, add the line alongside the other `decodeIfPresent` calls. Decoding tolerates the missing key for older saves — returns `nil`.)

- [ ] **Step 6: Build to verify it compiles**

Run: `xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add BabyTown/Models/Pet.swift
git commit -m "feat(notifications): persist lastPetInteractionAt on pet state"
```

---

## Task 6: NotificationManager — refresh, snapshot builder, trigger mapping, stubs (App)

**Files:**
- Modify: `BabyTown/Services/NotificationManager.swift`

- [ ] **Step 1: Add imports + GardenCore usage**

At the top of `NotificationManager.swift`, after `import UIKit`, add:

```swift
import GardenCore
```

- [ ] **Step 2: Add the Pacific calendar + planner + refresh entry point**

Add these members inside `NotificationManager` (after `scheduleDailyNotification()`):

```swift
    private let planner = NotificationPlanner()

    private var pacificCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return c
    }

    /// Identifiers this manager owns and re-creates on every refresh. The two
    /// fixed daily notifications are intentionally excluded.
    private var refreshOwnedPrefixes: [String] {
        ["pet_misses_you", "litter_box_noon", "pet_needs", "special_date_"]
    }

    /// Rebuilds all state-conditional notifications from persisted state.
    /// Safe to call from any thread; hops to the notification center directly.
    func refresh(now: Date = Date()) {
        let snapshot = Self.buildSnapshot(now: now)
        let planned = planner.plan(snapshot: snapshot, now: now, calendar: pacificCalendar)
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            // Remove previously-owned requests so removed conditions disappear.
            let toRemove = pending
                .map(\.identifier)
                .filter { id in self.refreshOwnedPrefixes.contains { id.hasPrefix($0) } }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
            for item in planned {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default
                let trigger = Self.makeTrigger(item.trigger)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }

    private static func makeTrigger(_ trigger: PlannedTrigger) -> UNNotificationTrigger {
        switch trigger {
        case let .interval(seconds):
            return UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        case let .calendarDaily(hour, minute):
            var comps = DateComponents(); comps.hour = hour; comps.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        case let .calendarAnnual(month, day, hour, minute):
            var comps = DateComponents()
            comps.month = month; comps.day = day; comps.hour = hour; comps.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }
    }
```

- [ ] **Step 3: Add the snapshot builder (rebuilds from persisted state)**

Add this static method inside `NotificationManager`:

```swift
    /// Assembles a `NotificationSnapshot` purely from persisted state so it can
    /// run with no live view models (e.g. on `scenePhase` background).
    static func buildSnapshot(now: Date) -> NotificationSnapshot {
        let dp = DataPersistenceManager.shared
        let state = dp.loadPetState()
        let isAdopted = state.adoptedSkin != nil

        // Pet name (custom name overrides the skin default).
        let petName: String? = state.adoptedSkin.map { skin in
            state.customPetNames[skin.rawValue] ?? skin.petName
        }

        // Litter dirty: events since clean (6AM/6PM) and not a self-cleaning box.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        var litterDirty = false
        if let skin = state.adoptedSkin {
            let equipped = state.roomLayout(for: skin).equippedItemID(for: .litterBox)
            let isAuto = PetShopCatalog.isAutoLitter(equippedItemID: equipped)
            let events = LitterSchedule.useEventsSinceLastClean(
                cleanedAt: state.litter.asOf, now: now, calendar: calendar)
            litterDirty = !isAuto && events > 0
        }

        // Needs measured at `now`.
        let hunger = isAdopted ? PetNeedSnapshot(
            level: state.hunger.current(decayPerHour: PetEconomy.hungerDecayPerHour, now: now),
            decayPerHour: PetEconomy.hungerDecayPerHour, gate: PetEconomy.feedThirstGate) : nil
        let thirst = isAdopted ? PetNeedSnapshot(
            level: state.thirst.current(decayPerHour: PetEconomy.thirstDecayPerHour, now: now),
            decayPerHour: PetEconomy.thirstDecayPerHour, gate: PetEconomy.feedThirstGate) : nil

        let specialDates = dp.loadCoupleProfile().specialDates.map {
            PlannerSpecialDate(id: $0.id.uuidString, title: $0.title, date: $0.date)
        }

        return NotificationSnapshot(
            isPetAdopted: isAdopted,
            petName: petName,
            userNickname: dp.loadUserNickname(),
            lastPetInteractionAt: state.lastPetInteractionAt,
            litterIsDirty: litterDirty,
            hunger: hunger,
            thirst: thirst,
            specialDates: specialDates
        )
    }
```

- [ ] **Step 4: Add milestone firing + partner-event stubs**

Add inside `NotificationManager`:

```swift
    /// Fires an immediate local banner for a freshly-crossed moment milestone.
    func fireMilestone(_ count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Milestone unlocked! 🎉"
        content.body = "You've saved \(count) moments together. Here's to many more 💞"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "milestone_\(count)", content: content, trigger: trigger))
    }

    /// Partner-driven events. DORMANT: no backend exists to drive these yet.
    /// This is the single hook a future server/APNs delivery path will call,
    /// and the debug actions in SettingsSheet call it for local verification.
    enum PartnerEvent {
        case joined(partnerName: String?)
        case loveLetterReceived(title: String, sentAt: Date)
        case partnerAddedMoment
        case partnerAddedSpecialDate
    }

    func handlePartnerEvent(_ event: PartnerEvent) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        let id: String
        switch event {
        case let .joined(partnerName):
            id = "partner_joined"
            content.title = "BabyTown"
            content.body = "\(partnerName ?? "Your partner") just joined your BabyTown 💞"
        case let .loveLetterReceived(title, sentAt):
            id = "partner_love_letter"
            let f = DateFormatter()
            f.doesRelativeDateFormatting = true
            f.dateStyle = .medium; f.timeStyle = .short
            content.title = title
            content.body = "Sent \(f.string(from: sentAt))"
        case .partnerAddedMoment:
            id = "partner_added_moment"
            content.title = "BabyTown"
            content.body = "A new moment was saved — check it out!"
        case .partnerAddedSpecialDate:
            id = "partner_added_date"
            content.title = "BabyTown"
            content.body = "A new important date was added — take a look!"
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
```

- [ ] **Step 5: Call refresh after authorization is granted**

In `requestAuthorization`, inside the `if success {` block after `self?.scheduleDailyNotification()`, add:

```swift
                    self?.refresh()
```

- [ ] **Step 6: Build to verify it compiles**

Run: `xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED. (If `state.roomLayout(for:)` is not accessible, confirm it exists on `PetState`; the snapshot reads the same layout `PetViewModel.activeRoomLayout` uses.)

- [ ] **Step 7: Commit**

```bash
git add BabyTown/Services/NotificationManager.swift
git commit -m "feat(notifications): refresh, snapshot builder, milestones, partner stubs"
```

---

## Task 7: Wire PetViewModel — interaction timestamp, refresh, 6AM/6PM litter (App)

**Files:**
- Modify: `BabyTown/ViewModels/PetViewModel.swift`

- [ ] **Step 1: Replace inline litter-use counting with the GardenCore helper**

Add `import GardenCore` at the top if not present. Replace the body of `litterUseEventsSinceLastClean(now:)` (lines ~320-345) with:

```swift
    private func litterUseEventsSinceLastClean(now: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return LitterSchedule.useEventsSinceLastClean(
            cleanedAt: state.litter.asOf, now: now, calendar: calendar)
    }
```

This switches the schedule to 6 AM/6 PM via `LitterSchedule.defaultUseHours`.

- [ ] **Step 2: Add a helper to record interaction + refresh**

Add this method to `PetViewModel`:

```swift
    /// Records that the user touched the pet/pet-room and reschedules
    /// state-conditional notifications. Call on room appear + every care action.
    func registerPetInteraction() {
        state.lastPetInteractionAt = Date()   // persists via didSet
        NotificationManager.shared.refresh()
    }
```

- [ ] **Step 3: Call it from care actions**

At the end of `award(_:)` (the shared path all care actions funnel through — locate the `func award` near line 188), add `NotificationManager.shared.refresh()` and set the interaction timestamp. Concretely, in each public care action (`pet`, `fillWater`, `feed`, `cleanLitter`, and play completion) the simplest single insertion is at the top of `award(_:)`:

```swift
    private func award(_ task: PetEconomy.CareTask) -> CareResult {
        state.lastPetInteractionAt = Date()
        defer { NotificationManager.shared.refresh() }
        // ... existing award body unchanged ...
    }
```

(If `award` does not wrap every care action, also call `registerPetInteraction()` at the end of any care method that bypasses `award`, e.g. `beginPlaySession()`.)

- [ ] **Step 4: Call refresh on pet-room appear**

Find where the pet room view appears (the SwiftUI view hosting `PetRoomScene` — search for `PetViewModel` usage in a `.onAppear`). Add to that `.onAppear`:

```swift
                petViewModel.registerPetInteraction()
```

If no single `.onAppear` exists, add one to the pet-room container view that calls `petViewModel.registerPetInteraction()`.

- [ ] **Step 5: Build to verify it compiles**

Run: `xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add BabyTown/ViewModels/PetViewModel.swift BabyTown/Game/PetRoomScene.swift
git commit -m "feat(notifications): 6AM/6PM litter + pet-interaction timestamp + refresh hooks"
```

---

## Task 8: Milestone firing + celebrated-set persistence (App)

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`
- Modify: `BabyTown/ViewModels/HomeViewModel.swift`

- [ ] **Step 1: Add celebrated-milestones persistence**

In `DataPersistenceManager.swift`, add a key near the other `private let ...Key` declarations:

```swift
    private let celebratedMomentMilestonesKey = "celebratedMomentMilestones"
```

Add these methods (UserDefaults-backed, mirroring existing patterns):

```swift
    func loadCelebratedMomentMilestones() -> Set<Int> {
        let arr = userDefaults.array(forKey: celebratedMomentMilestonesKey) as? [Int] ?? []
        return Set(arr)
    }

    func saveCelebratedMomentMilestones(_ set: Set<Int>) {
        userDefaults.set(Array(set), forKey: celebratedMomentMilestonesKey)
    }
```

(If `DataPersistenceManager` uses a differently-named `UserDefaults` property, match it — confirm with the `userNicknameKey` usage near line 337.)

- [ ] **Step 2: Fire milestones when moment count grows**

In `HomeViewModel.swift`, add `import GardenCore` if absent. The `moments` property has a `didSet` (line ~112) that calls `saveMoments`. Add milestone handling. First add a stored property to track the previous count:

```swift
    private var lastKnownMomentCount = DataPersistenceManager.shared.loadMoments().count
```

Then add a method:

```swift
    private func handleMomentCountChange() {
        let newCount = moments.count
        defer {
            lastKnownMomentCount = newCount
            NotificationManager.shared.refresh()
        }
        guard newCount > lastKnownMomentCount else { return }
        let dp = DataPersistenceManager.shared
        var celebrated = dp.loadCelebratedMomentMilestones()
        let crossed = NotificationPlanner().crossedMilestones(
            oldCount: lastKnownMomentCount, newCount: newCount, alreadyCelebrated: celebrated)
        guard let top = crossed.max() else { return }
        celebrated.formUnion(crossed)         // record all crossed; fire only the top
        dp.saveCelebratedMomentMilestones(celebrated)
        NotificationManager.shared.fireMilestone(top)
    }
```

In the `moments` `didSet`, after the existing `saveMoments(moments)` call, add:

```swift
            handleMomentCountChange()
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Services/DataPersistenceManager.swift BabyTown/ViewModels/HomeViewModel.swift
git commit -m "feat(notifications): fire moment-milestone banners (fire-once, highest-per-batch)"
```

---

## Task 9: Lifecycle + special-date refresh hooks (App)

**Files:**
- Modify: `BabyTown/ContentView.swift`
- Modify: `BabyTown/Services/DataPersistenceManager.swift` (refresh on couple-profile save)

- [ ] **Step 1: Refresh on app background**

In `ContentView.swift`, add `@Environment(\.scenePhase) private var scenePhase` to the view's properties, and attach to the root `ZStack` in `body`:

```swift
        .onChange(of: scenePhase) { phase in
            if phase == .background { NotificationManager.shared.refresh() }
        }
```

Also add an initial refresh when the app reaches its main screen — in the existing transition to `targetScreen`, or attach `.onAppear { NotificationManager.shared.refresh() }` to the root `ZStack`.

- [ ] **Step 2: Refresh when special dates change**

In `DataPersistenceManager.saveCoupleProfile(_:)` (line ~222), after the profile is written to disk, add:

```swift
        NotificationManager.shared.refresh()
```

This keeps anniversary triggers in sync whenever a special date is added/edited/removed (all of which save the couple profile).

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/ContentView.swift BabyTown/Services/DataPersistenceManager.swift
git commit -m "feat(notifications): refresh on background, launch, and special-date changes"
```

---

## Task 10: Debug actions to fire partner-event stubs (App)

**Files:**
- Modify: `BabyTown/Components/SettingsSheet.swift`

- [ ] **Step 1: Add a debug section that fires each partner stub**

In `SettingsSheet.swift`, add a section (wrap in `#if DEBUG` so it ships only in debug builds):

```swift
#if DEBUG
            Section("Debug · Partner notifications") {
                Button("Test: partner joined") {
                    NotificationManager.shared.handlePartnerEvent(.joined(partnerName: "Alex"))
                }
                Button("Test: love letter received") {
                    NotificationManager.shared.handlePartnerEvent(
                        .loveLetterReceived(title: "Thinking of you", sentAt: Date()))
                }
                Button("Test: partner added a moment") {
                    NotificationManager.shared.handlePartnerEvent(.partnerAddedMoment)
                }
                Button("Test: partner added a date") {
                    NotificationManager.shared.handlePartnerEvent(.partnerAddedSpecialDate)
                }
            }
#endif
```

(Match the surrounding container — if `SettingsSheet` uses a `Form`/`List` of `Section`s, drop this in; if it uses a custom layout, add four buttons in the existing debug area.)

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Components/SettingsSheet.swift
git commit -m "feat(notifications): debug actions to fire dormant partner stubs"
```

---

## Task 11: Full verification

- [ ] **Step 1: Run the whole GardenCore suite**

Run: `swift test --package-path GardenCore`
Expected: all tests pass (quiet-hours, litter schedule, planner, milestones).

- [ ] **Step 2: Build the app**

Run: `xcodebuild -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual simulator checks (per project "verify UI in simulator" memory)**

Verify in the simulator:
- Settings → debug section fires each of the 4 partner banners with correct copy (love letter shows title + "Sent …" timestamp).
- Adopt a pet, then add moments to cross 10 → milestone banner appears once; cross to 50 → fires; re-crossing does not re-fire.
- With a dirty litter box equipped (non-auto), confirm a `litter_box_noon` pending request exists (inspect via `getPendingNotificationRequests` debug print or a temporary log in `refresh`).
- With no pet adopted, confirm `pet_misses_you` / `litter_box_noon` / `pet_needs` are absent from pending requests.
- Confirm the existing 8 AM morning + 9 PM polaroid notifications still schedule (unchanged).

- [ ] **Step 4: Final commit (if any verification fixes were needed)**

```bash
git add -A
git commit -m "test(notifications): verification fixes"
```

---

## Self-Review Notes (coverage check)

- Spec §"Pet misses you" → Task 3 (planner) + Task 5/7 (timestamp, hooks). ✅
- Spec §"Litter-box reminder 12PM" → Task 3 (planner) + Task 6 (snapshot dirty calc). ✅
- Spec §"Litter schedule 6AM/6PM" → Task 2 + Task 7 Step 1. ✅
- Spec §"Milestone congrats 10/50/100/250/500/1000" → Task 4 + Task 8. ✅
- Spec §"Pet needs" → Task 3 (planner) + Task 6 (need projection). ✅
- Spec §"Anniversary reminders" → Task 3 (planner) + Task 6 + Task 9 (date-change refresh). ✅
- Spec §"Reschedule-on-lifecycle" → Task 6 (`refresh`) + Task 9 (background/launch). ✅
- Spec §"Dormant partner stubs + local test path" → Task 6 (`handlePartnerEvent`) + Task 10 (debug). ✅
- Spec §"Foreground delivery" → already present in `AppDelegate.willPresent` returning `[.banner, .sound]`; no change needed (note: this currently also presents the daily ones in-foreground — acceptable per spec).
- Spec §"Quiet hours" → Task 1, applied in Task 3 for computed triggers. ✅
- Type consistency: `NotificationSnapshot`, `PetNeedSnapshot`, `PlannerSpecialDate`, `PlannedTrigger`, `PlannedNotification`, `crossedMilestones`, `fireMilestone`, `handlePartnerEvent`, `registerPetInteraction`, `buildSnapshot`, `refresh` are defined once and referenced consistently. ✅
