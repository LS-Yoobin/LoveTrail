import Foundation

/// Maps bloom milestones to chapters, shapes, and tap lore.
public enum BloomChapterResolver {
    public static let legendMilestones = [50, 100]

    /// Soft palette for every-10-moment bouquets. Never returns black.
    public static func chapter(forBasicMilestone threshold: Int) -> BloomChapter {
        guard threshold >= GardenMilestoneBloomComposer.basicMomentInterval else { return .white }
        switch (threshold / GardenMilestoneBloomComposer.basicMomentInterval) % 5 {
        case 0: return .white
        case 1: return .yellow
        case 2: return .red
        case 3: return .blue
        case 4: return .purple
        default: return .white
        }
    }

    public static func shape(
        for actKind: GardenActKind,
        isLegend: Bool,
        milestone: Int?
    ) -> BloomShape {
        if isLegend, let milestone {
            switch milestone {
            case 50: return .tulip3
            case 100: return .lotus8
            default: return .classic6
            }
        }
        switch actKind {
        case .birthday: return .daisy12
        case .anniversary: return .lotus8
        case .milestone50: return .tulip3
        case .milestone100: return .lotus8
        case .basicMilestone, .moment, .place: return .classic6
        case .letter: return .classic6
        }
    }

    public static func legendID(milestone: Int) -> UUID {
        GardenMilestoneBloomComposer.milestoneID(milestone)
    }

    public static func legendPosition(milestone: Int) -> GardenPoint {
        switch milestone {
        case 50: return GardenPoint(x: 0.34, y: 0.24)
        case 100: return GardenPoint(x: 0.66, y: 0.24)
        default: return GardenPoint(x: 0.5, y: 0.24)
        }
    }

    public static func legendChapter(milestone: Int) -> BloomChapter {
        switch milestone {
        case 50: return .purple
        case 100: return .black
        default: return .white
        }
    }

    public static func lore(for element: GardenElement) -> BloomLore? {
        if element.isLegend {
            return legendLore(milestone: legendMilestone(for: element.sourceID))
        }
        switch element.kind {
        case .flower, .birthdayFlower, .anniversaryFlower, .placeFlower:
            return lore(for: element.sourceID, kind: element.kind, chapter: element.chapter)
        case .tree:
            return nil
        }
    }

    public static func legendMilestone(for sourceID: UUID) -> Int? {
        GardenMilestoneBloomComposer.milestoneCount(for: sourceID)
    }

    public static func lore(for sourceID: UUID, kind: GardenElementKind, chapter: BloomChapter) -> BloomLore? {
        if let threshold = GardenMilestoneBloomComposer.basicMilestoneThreshold(for: sourceID) {
            return basicMilestoneLore(threshold: threshold, chapter: chapter)
        }
        switch kind {
        case .birthdayFlower:
            return BloomLore(
                displayName: "Birthday Bloom",
                subtitle: "Another candle, another flower—celebrate them."
            )
        case .anniversaryFlower:
            return BloomLore(
                displayName: "Anniversary Bloom",
                subtitle: "Another year of us, planted in the garden."
            )
        default:
            return nil
        }
    }

    public static func legendLore(milestone: Int?) -> BloomLore? {
        switch milestone {
        case 50:
            return BloomLore(
                displayName: "Twilight Shrine",
                subtitle: "Fifty memories in—your garden is truly thriving."
            )
        case 100:
            return BloomLore(
                displayName: "Eclipse Shrine",
                subtitle: "One hundred blooms of us. Legendary."
            )
        default:
            return nil
        }
    }

    public static func basicMilestoneLore(threshold: Int, chapter: BloomChapter) -> BloomLore {
        let name: String
        switch chapter {
        case .white: name = "First Bouquet"
        case .yellow: name = "Sunbeam Bouquet"
        case .red: name = "Ember Bouquet"
        case .blue: name = "Horizon Bouquet"
        case .purple: name = "Twilight Bouquet"
        default: name = "Memory Bouquet"
        }
        return BloomLore(
            displayName: name,
            subtitle: "\(threshold) memories planted together."
        )
    }

    public static func milestoneBloomName(count: Int) -> String {
        switch count {
        case 50: return "Twilight Shrine"
        case 100: return "Eclipse Shrine"
        case 250: return "Starfield Bloom"
        case 500: return "Constellation Bloom"
        case 1000: return "Galaxy Bloom"
        default: return "Garden Milestone"
        }
    }
}
