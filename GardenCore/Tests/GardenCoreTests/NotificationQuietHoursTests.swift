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
