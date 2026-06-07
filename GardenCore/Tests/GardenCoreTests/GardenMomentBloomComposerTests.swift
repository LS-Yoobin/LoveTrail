import XCTest
@testable import GardenCore

/// Legacy per-day composer kept for reference; milestone growth replaced it in the app.
final class GardenMomentBloomComposerTests: XCTestCase {
    private func id(_ s: String) -> UUID { UUID(uuidString: s)! }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))!
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
}
