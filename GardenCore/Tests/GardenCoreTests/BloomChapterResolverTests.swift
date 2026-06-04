import XCTest
@testable import GardenCore

final class BloomChapterResolverTests: XCTestCase {
    func testChapterBands() {
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 1), .white)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 9), .white)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 10), .yellow)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 19), .yellow)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 20), .red)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 30), .blue)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 40), .purple)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 50), .white)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 99), .purple)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 100), .black)
        XCTAssertEqual(BloomChapterResolver.chapter(forMomentOrdinal: 250), .black)
    }

    func testCycleBands() {
        XCTAssertEqual(BloomChapterResolver.cycle(forMomentOrdinal: 1), 0)
        XCTAssertEqual(BloomChapterResolver.cycle(forMomentOrdinal: 49), 0)
        XCTAssertEqual(BloomChapterResolver.cycle(forMomentOrdinal: 50), 1)
        XCTAssertEqual(BloomChapterResolver.cycle(forMomentOrdinal: 99), 1)
        XCTAssertEqual(BloomChapterResolver.cycle(forMomentOrdinal: 100), 0)
    }

    func testLegendShapes() {
        XCTAssertEqual(
            BloomChapterResolver.shape(for: .moment, isLegend: true, milestone: 10),
            .daisy12
        )
        XCTAssertEqual(
            BloomChapterResolver.shape(for: .moment, isLegend: true, milestone: 50),
            .tulip3
        )
        XCTAssertEqual(
            BloomChapterResolver.shape(for: .moment, isLegend: true, milestone: 100),
            .lotus8
        )
        XCTAssertEqual(
            BloomChapterResolver.shape(for: .place, isLegend: false, milestone: nil),
            .place5
        )
    }

    func testLegendIDsStable() {
        let a = BloomChapterResolver.legendID(milestone: 10)
        let b = BloomChapterResolver.legendID(milestone: 10)
        XCTAssertEqual(a, b)
        XCTAssertEqual(BloomChapterResolver.legendMilestone(for: a), 10)
    }

    func testLegendLore() {
        let lore = BloomChapterResolver.legendLore(milestone: 100)
        XCTAssertEqual(lore?.displayName, "Eclipse Shrine")
    }
}

final class GardenComposerLegendTests: XCTestCase {
    private func id(_ s: String) -> UUID { UUID(uuidString: s)! }

    func testNoLegendsBelowTen() {
        let acts = [GardenActInput(id: id("00000000-0000-0000-0000-000000000001"),
                                   date: Date(), kind: .moment)]
        let elements = GardenComposer().compose(acts: acts, totalMomentCount: 9)
        XCTAssertFalse(elements.contains { $0.isLegend })
    }

    func testLegendAtTen() {
        let elements = GardenComposer().compose(acts: [], totalMomentCount: 10)
        XCTAssertEqual(elements.filter(\.isLegend).count, 1)
        XCTAssertEqual(elements.first?.shape, .daisy12)
        XCTAssertEqual(elements.first?.chapter, .yellow)
    }

    func testThreeLegendsAtHundred() {
        let elements = GardenComposer().compose(acts: [], totalMomentCount: 100)
        XCTAssertEqual(elements.filter(\.isLegend).count, 3)
        let milestones = elements.filter(\.isLegend).compactMap { BloomChapterResolver.legendMilestone(for: $0.sourceID) }
        XCTAssertEqual(Set(milestones), Set([10, 50, 100]))
    }

    func testOrdinalAssignsChapter() {
        let act = GardenActInput(id: id("00000000-0000-0000-0000-000000000001"),
                                 date: Date(), kind: .moment)
        let elements = GardenComposer().compose(
            acts: [act],
            momentOrdinalByActID: [act.id: 25],
            totalMomentCount: 25
        )
        let flower = elements.first { !$0.isLegend }
        XCTAssertEqual(flower?.chapter, .red)
        XCTAssertEqual(flower?.cycle, 0)
    }

    func testLegendPositionsFixed() {
        let elements = GardenComposer().compose(acts: [], totalMomentCount: 100)
        let ten = elements.first { BloomChapterResolver.legendMilestone(for: $0.sourceID) == 10 }
        XCTAssertEqual(ten?.position, BloomChapterResolver.legendPosition(milestone: 10))
    }
}
