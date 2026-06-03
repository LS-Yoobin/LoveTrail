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
