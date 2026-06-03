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

    func testSpanningTwoDaysThreeEvents() {
        // Cleaned 6/3 5 AM, now 6/4 7 AM → 6AM,6PM (6/3) + 6AM (6/4) = 3.
        let cleaned = date(2026, 6, 3, 5)
        let now = date(2026, 6, 4, 7)
        XCTAssertEqual(LitterSchedule.useEventsSinceLastClean(cleanedAt: cleaned, now: now, calendar: calendar()), 3)
    }

    func testDefaultUseHoursAreSixAndEighteen() {
        XCTAssertEqual(LitterSchedule.defaultUseHours, [6, 18])
    }
}
