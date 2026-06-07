import XCTest
@testable import GardenCore

final class GardenMilestoneBloomComposerTests: XCTestCase {
    private func id(_ s: String) -> UUID { UUID(uuidString: s)! }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testFortyNineMomentsYieldFourBasicBouquetsOnly() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(unlockedMomentCount: 49, now: date(2026, 6, 6))
        )
        XCTAssertEqual(acts.filter { $0.kind == .basicMilestone }.count, 4)
        XCTAssertFalse(acts.contains { $0.kind == .milestone50 })
        XCTAssertFalse(acts.contains { $0.kind == .milestone100 })
    }

    func testFiftyMomentsYieldFiveBasicBouquetsAndShrine() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(unlockedMomentCount: 50, now: date(2026, 6, 6))
        )
        XCTAssertEqual(acts.filter { $0.kind == .basicMilestone }.count, 5)
        XCTAssertEqual(acts.filter { $0.kind == .milestone50 }.count, 1)
    }

    func testFiftyMomentsAddsShrineBloom() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(unlockedMomentCount: 50, now: date(2026, 6, 6))
        )
        XCTAssertEqual(acts.filter { $0.kind == .basicMilestone }.count, 5)
        XCTAssertEqual(acts.filter { $0.kind == .milestone50 }.count, 1)
    }

    func testBirthdayProducesAnnualBloomAfterAnchor() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(
                unlockedMomentCount: 5,
                birthdays: [
                    GardenBirthdayInput(
                        personID: id("00000000-0000-0000-0000-0000000000AA"),
                        date: date(1998, 3, 15),
                        title: "My Birthday"
                    )
                ],
                relationshipAnchor: date(2025, 6, 1),
                now: date(2026, 6, 6)
            )
        )
        XCTAssertEqual(acts.filter { $0.kind == .birthday }.count, 1)
    }

    func testAnniversaryStartsYearAfterAnchor() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(
                unlockedMomentCount: 5,
                anniversaryDate: date(2024, 9, 14),
                relationshipAnchor: date(2024, 9, 14),
                now: date(2026, 6, 6)
            )
        )
        XCTAssertEqual(acts.filter { $0.kind == .anniversary }.count, 1)
    }

    func testComposeProducesSparseGardenForFortyNineMoments() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(unlockedMomentCount: 49, now: date(2026, 6, 6))
        )
        let elements = GardenComposer().compose(acts: acts)
        XCTAssertEqual(elements.count, 4)
        XCTAssertFalse(elements.contains { $0.chapter == .black })
    }
}
