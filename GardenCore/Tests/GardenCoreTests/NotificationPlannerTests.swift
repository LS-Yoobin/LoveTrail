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
        let needs = plan.first { $0.id == "pet_needs" }!
        // Assert the title too: it is distinctive to the combined branch, so this
        // pins branch selection (the body alone would also pass the hunger branch).
        XCTAssertEqual(needs.title, "Mochi needs you")
        XCTAssertEqual(needs.body, "Mochi is hungry and thirsty")
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
