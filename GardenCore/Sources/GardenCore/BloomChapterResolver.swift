import Foundation

/// Maps moment ordinals to bloom chapters, shapes, and tap lore.
public enum BloomChapterResolver {
    public static let legendMilestones = [10, 50, 100]

    public static func chapter(forMomentOrdinal n: Int) -> BloomChapter {
        guard n >= 1 else { return .white }
        if n >= 100 { return .black }
        switch n / 10 % 5 {
        case 0: return .white
        case 1: return .yellow
        case 2: return .red
        case 3: return .blue
        case 4: return .purple
        default: return .white
        }
    }

    /// 0 for moments 1–49; 1 for 50–99 (richer petals in the renderer).
    public static func cycle(forMomentOrdinal n: Int) -> Int {
        guard n >= 1, n < 100 else { return 0 }
        return (n / 10) / 5
    }

    public static func shape(
        for actKind: GardenActKind,
        isLegend: Bool,
        milestone: Int?
    ) -> BloomShape {
        if isLegend, let milestone {
            switch milestone {
            case 10: return .daisy12
            case 50: return .tulip3
            case 100: return .lotus8
            default: return .classic6
            }
        }
        switch actKind {
        case .place: return .place5
        case .moment, .letter: return .classic6
        }
    }

    public static func legendID(milestone: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012x", milestone))!
    }

    public static func legendPosition(milestone: Int) -> GardenPoint {
        switch milestone {
        case 10: return GardenPoint(x: 0.15, y: 0.22)
        case 50: return GardenPoint(x: 0.50, y: 0.22)
        case 100: return GardenPoint(x: 0.85, y: 0.22)
        default: return GardenPoint(x: 0.5, y: 0.22)
        }
    }

    public static func legendChapter(milestone: Int) -> BloomChapter {
        switch milestone {
        case 10: return .yellow
        case 50: return .purple
        case 100: return .black
        default: return .white
        }
    }

    public static func lore(for element: GardenElement) -> BloomLore? {
        if element.isLegend {
            return legendLore(milestone: legendMilestone(for: element.sourceID))
        }
        guard element.kind == .flower || element.kind == .placeFlower else { return nil }
        return chapterLore(chapter: element.chapter, cycle: element.cycle)
    }

    public static func legendMilestone(for sourceID: UUID) -> Int? {
        let suffix = sourceID.uuidString.suffix(12)
        guard let value = Int(suffix, radix: 16), legendMilestones.contains(value) else { return nil }
        return value
    }

    public static func legendLore(milestone: Int?) -> BloomLore? {
        switch milestone {
        case 10:
            return BloomLore(
                displayName: "Sunbeam Shrine",
                subtitle: "Ten memories in—your garden officially has a heartbeat."
            )
        case 50:
            return BloomLore(
                displayName: "Twilight Shrine",
                subtitle: "Fifty days of ‘remember this’—your field is thriving."
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

    public static func chapterLore(chapter: BloomChapter, cycle: Int) -> BloomLore {
        switch (chapter, cycle) {
        case (.white, 0):
            return BloomLore(
                displayName: "First Light",
                subtitle: "The shy hello—your story just started."
            )
        case (.white, _):
            return BloomLore(
                displayName: "Golden Hour",
                subtitle: "You’ve built a rhythm. Keep going."
            )
        case (.yellow, 0):
            return BloomLore(
                displayName: "Sunbeam",
                subtitle: "Ordinary days that somehow glow."
            )
        case (.yellow, _):
            return BloomLore(
                displayName: "Sunbeam",
                subtitle: "Brighter every day—you’re really in your groove."
            )
        case (.red, 0):
            return BloomLore(
                displayName: "Ember Heart",
                subtitle: "The little sparks that feel like fireworks."
            )
        case (.red, _):
            return BloomLore(
                displayName: "Ember Heart",
                subtitle: "Still sparking—your story runs hot."
            )
        case (.blue, 0):
            return BloomLore(
                displayName: "Horizon",
                subtitle: "Room to grow—trust, plans, wide-open sky."
            )
        case (.blue, _):
            return BloomLore(
                displayName: "Horizon",
                subtitle: "Further out now—the view keeps getting wider."
            )
        case (.purple, 0):
            return BloomLore(
                displayName: "Twilight Bond",
                subtitle: "Soft closeness—the ‘just us’ kind of quiet."
            )
        case (.purple, _):
            return BloomLore(
                displayName: "Twilight Bond",
                subtitle: "Deeper shade of us—the comfortable kind of close."
            )
        case (.black, _):
            return BloomLore(
                displayName: "Eclipse Bloom",
                subtitle: "A whole season of love—rare, deep, unforgettable."
            )
        }
    }

    public static func milestoneBloomName(count: Int) -> String {
        switch count {
        case 10: return "Sunbeam Shrine"
        case 50: return "Twilight Shrine"
        case 100: return "Eclipse Shrine"
        case 250: return "Starfield Bloom"
        case 500: return "Constellation Bloom"
        case 1000: return "Galaxy Bloom"
        default: return "Garden Milestone"
        }
    }
}
