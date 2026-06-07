import XCTest
@testable import GardenCore

final class BloomChapterResolverTests: XCTestCase {
    func testBasicMilestonePaletteNeverUsesBlack() {
        XCTAssertEqual(BloomChapterResolver.chapter(forBasicMilestone: 10), .yellow)
        XCTAssertEqual(BloomChapterResolver.chapter(forBasicMilestone: 20), .red)
        XCTAssertEqual(BloomChapterResolver.chapter(forBasicMilestone: 30), .blue)
        XCTAssertEqual(BloomChapterResolver.chapter(forBasicMilestone: 40), .purple)
        XCTAssertEqual(BloomChapterResolver.chapter(forBasicMilestone: 50), .white)
    }

    func testLegendShapesOnlyAtFiftyAndHundred() {
        XCTAssertEqual(
            BloomChapterResolver.shape(for: .milestone50, isLegend: true, milestone: 50),
            .tulip3
        )
        XCTAssertEqual(
            BloomChapterResolver.shape(for: .milestone100, isLegend: true, milestone: 100),
            .lotus8
        )
    }

    func testLegendIDsStable() {
        let a = BloomChapterResolver.legendID(milestone: 50)
        let b = BloomChapterResolver.legendID(milestone: 50)
        XCTAssertEqual(a, b)
        XCTAssertEqual(BloomChapterResolver.legendMilestone(for: a), 50)
    }

    func testLegendLore() {
        let lore = BloomChapterResolver.legendLore(milestone: 100)
        XCTAssertEqual(lore?.displayName, "Eclipse Shrine")
    }
}

final class GardenComposerLegendTests: XCTestCase {
    func testNoLegendsBelowFifty() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(unlockedMomentCount: 49, now: Date())
        )
        let elements = GardenComposer().compose(acts: acts)
        XCTAssertFalse(elements.contains { $0.isLegend })
    }

    func testLegendAtFifty() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(unlockedMomentCount: 50, now: Date())
        )
        let legends = GardenComposer().compose(acts: acts).filter(\.isLegend)
        XCTAssertEqual(legends.count, 1)
        XCTAssertEqual(legends.first?.shape, .tulip3)
        XCTAssertEqual(legends.first?.chapter, .purple)
    }

    func testTwoLegendsAtHundred() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(unlockedMomentCount: 100, now: Date())
        )
        let legends = GardenComposer().compose(acts: acts).filter(\.isLegend)
        XCTAssertEqual(legends.count, 2)
        let milestones = legends.compactMap { BloomChapterResolver.legendMilestone(for: $0.sourceID) }
        XCTAssertEqual(Set(milestones), Set([50, 100]))
    }

    func testBasicMilestoneAssignsSoftChapter() {
        let act = GardenActInput(
            id: GardenMilestoneBloomComposer.basicMilestoneID(threshold: 40),
            date: Date(),
            kind: .basicMilestone
        )
        let flower = GardenComposer().compose(acts: [act]).first
        XCTAssertEqual(flower?.chapter, .purple)
        XCTAssertFalse(flower?.isLegend ?? true)
    }

    func testLegendPositionsFixed() {
        let acts = GardenMilestoneBloomComposer().acts(
            from: GardenBloomScheduleInput(unlockedMomentCount: 100, now: Date())
        )
        let elements = GardenComposer().compose(acts: acts)
        let fifty = elements.first { BloomChapterResolver.legendMilestone(for: $0.sourceID) == 50 }
        XCTAssertEqual(fifty?.position, BloomChapterResolver.legendPosition(milestone: 50))
    }
}
