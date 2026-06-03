import XCTest
@testable import GardenCore

final class GardenMomentBloomComposerTests: XCTestCase {
    private func id(_ s: String) -> UUID { UUID(uuidString: s)! }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testOneFlowerPerCalendarDay() {
        let moments = [
            GardenMomentInput(id: id("00000000-0000-0000-0000-000000000001"),
                              dateTaken: date(2024, 6, 1), hasDistinctPlace: false),
            GardenMomentInput(id: id("00000000-0000-0000-0000-000000000002"),
                              dateTaken: date(2024, 6, 2), hasDistinctPlace: true),
        ]
        let acts = GardenMomentBloomComposer().acts(from: moments)
        XCTAssertEqual(acts.count, 2)
        XCTAssertEqual(acts.first { $0.id == id("00000000-0000-0000-0000-000000000001") }?.kind, .moment)
        XCTAssertEqual(acts.first { $0.id == id("00000000-0000-0000-0000-000000000002") }?.kind, .place)
    }

    func testNoMomentsMeansNoBlooms() {
        XCTAssertTrue(GardenMomentBloomComposer().acts(from: []).isEmpty)
    }

    func testTwoMomentsSameDayYieldOneFlower() {
        let day = date(2024, 7, 4)
        let earlier = GardenMomentInput(id: id("00000000-0000-0000-0000-000000000010"),
                                        dateTaken: day, hasDistinctPlace: false)
        let later = GardenMomentInput(id: id("00000000-0000-0000-0000-000000000011"),
                                      dateTaken: day.addingTimeInterval(3600), hasDistinctPlace: true)
        let acts = GardenMomentBloomComposer().acts(from: [earlier, later])
        XCTAssertEqual(acts.count, 1)
        XCTAssertEqual(acts[0].id, later.id)
        XCTAssertEqual(acts[0].kind, .place)
    }

    func testComposeProducesOneFlowerPerDayAct() {
        let moments = [
            GardenMomentInput(id: id("00000000-0000-0000-0000-0000000000AA"),
                              dateTaken: date(2024, 1, 1), hasDistinctPlace: false),
        ]
        let acts = GardenMomentBloomComposer().acts(from: moments)
        let elements = GardenComposer().compose(acts: acts)
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].kind, .flower)
    }
}
