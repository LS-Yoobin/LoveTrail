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

    func testPositionIsStableAcrossRuns() {
        let act = GardenActInput(id: id("00000000-0000-0000-0000-0000000000AA"),
                                 date: Date(), kind: .moment)
        let a = GardenComposer().compose(acts: [act])[0].position
        let b = GardenComposer().compose(acts: [act])[0].position
        XCTAssertEqual(a, b)
        // Hard-coded expectation locks determinism across processes.
        XCTAssertEqual(a.x, 0.3909990739638449, accuracy: 0.000001)
        XCTAssertEqual(a.y, 0.26078983464296673, accuracy: 0.000001)
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
        let acts = (0..<50).map { _ in
            GardenActInput(id: UUID(), date: Date(), kind: .moment)
        }
        for p in GardenComposer().compose(acts: acts).map(\.position) {
            XCTAssertTrue((0.05...0.95).contains(p.x), "x out of range: \(p.x)")
            XCTAssertTrue((0.08...0.42).contains(p.y), "y out of range: \(p.y)")
        }
    }
}
