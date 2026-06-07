import XCTest
@testable import GardenCore

final class GardenComposerTests: XCTestCase {
    private func id(_ s: String) -> UUID { UUID(uuidString: s)! }

    func testBasicMilestoneMapsToFlower() {
        let acts = [
            GardenActInput(
                id: GardenMilestoneBloomComposer.basicMilestoneID(threshold: 10),
                date: Date(),
                kind: .basicMilestone
            )
        ]
        let elements = GardenComposer().compose(acts: acts)
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].kind, .flower)
        XCTAssertEqual(elements[0].shape, .daisy12)
    }

    func testBirthdayMapsToBirthdayFlower() {
        let acts = [GardenActInput(id: id("00000000-0000-0000-0000-000000000002"),
                                   date: Date(), kind: .birthday)]
        XCTAssertEqual(GardenComposer().compose(acts: acts)[0].kind, .birthdayFlower)
    }

    func testAnniversaryMapsToAnniversaryFlower() {
        let acts = [GardenActInput(id: id("00000000-0000-0000-0000-000000000003"),
                                   date: Date(), kind: .anniversary)]
        XCTAssertEqual(GardenComposer().compose(acts: acts)[0].kind, .anniversaryFlower)
    }

    func testLetterMapsToTree() {
        let acts = [GardenActInput(id: id("00000000-0000-0000-0000-000000000004"),
                                   date: Date(), kind: .letter)]
        XCTAssertEqual(GardenComposer().compose(acts: acts)[0].kind, .tree)
    }

    func testBasicMilestonePositionIsStableAcrossRuns() {
        let act = GardenActInput(
            id: GardenMilestoneBloomComposer.basicMilestoneID(threshold: 20),
            date: Date(),
            kind: .basicMilestone
        )
        let a = GardenComposer().compose(acts: [act])[0].position
        let b = GardenComposer().compose(acts: [act])[0].position
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, GardenComposer.positionForBasicMilestone(threshold: 20))
    }

    func testBasicMilestonePositionsAreSpreadAcrossHill() {
        let thresholds = [10, 20, 30, 40, 50]
        let positions = thresholds.map {
            GardenComposer.positionForBasicMilestone(threshold: $0)
        }

        for pos in positions {
            XCTAssertTrue((0.05...0.95).contains(pos.x))
            XCTAssertTrue((0.08...0.42).contains(pos.y))
        }

        for i in 0..<positions.count {
            for j in (i + 1)..<positions.count {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                let distance = (dx * dx + dy * dy).squareRoot()
                XCTAssertGreaterThan(distance, 0.05, "thresholds \(thresholds[i]) and \(thresholds[j]) overlap")
            }
        }

        let xs = positions.map(\.x)
        XCTAssertLessThan(xs.min()!, 0.40, "expected a bloom on the left side of the hill")
        XCTAssertGreaterThan(xs.max()!, 0.60, "expected a bloom on the right side of the hill")
    }

    func testDifferentMilestoneThresholdsGetDifferentPositions() {
        let ten = GardenActInput(
            id: GardenMilestoneBloomComposer.basicMilestoneID(threshold: 10),
            date: Date(),
            kind: .basicMilestone
        )
        let twenty = GardenActInput(
            id: GardenMilestoneBloomComposer.basicMilestoneID(threshold: 20),
            date: Date(),
            kind: .basicMilestone
        )
        let positions = GardenComposer().compose(acts: [ten, twenty]).map(\.position)
        XCTAssertNotEqual(positions[0], positions[1])
    }

    func testPositionsAreWithinPlantingBand() {
        let acts = (0..<20).map { index in
            GardenActInput(
                id: GardenMilestoneBloomComposer.basicMilestoneID(threshold: (index + 1) * 10),
                date: Date(),
                kind: .basicMilestone
            )
        }
        for p in GardenComposer().compose(acts: acts).map(\.position) {
            XCTAssertTrue((0.05...0.95).contains(p.x), "x out of range: \(p.x)")
            XCTAssertTrue((0.08...0.42).contains(p.y), "y out of range: \(p.y)")
        }
    }
}
