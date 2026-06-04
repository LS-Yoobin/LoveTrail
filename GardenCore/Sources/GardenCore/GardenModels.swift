import Foundation

/// The kind of loving act a garden element grew from.
public enum GardenActKind: String, Codable, Equatable, Sendable {
    case moment   // a captured moment with no distinct place
    case place    // a moment tied to a named place / country
    case letter   // a written love letter
}

/// A minimal, UI-free description of one loving act. The app converts its real
/// `Moment` / `UserLetter` values into these so GardenCore stays pure.
public struct GardenActInput: Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let kind: GardenActKind

    public init(id: UUID, date: Date, kind: GardenActKind) {
        self.id = id
        self.date = date
        self.kind = kind
    }
}

/// The visual archetype an act becomes in the garden.
public enum GardenElementKind: String, Codable, Equatable, Sendable {
    case flower
    case placeFlower
    case tree
}

/// A normalized garden position in the unit square (0...1, origin bottom-left).
public struct GardenPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Chapter color for a bloom, derived from how many moments existed when it grew.
public enum BloomChapter: String, Codable, Equatable, Sendable {
    case white, yellow, red, blue, purple, black
}

/// Procedural petal layout for a bloom.
public enum BloomShape: String, Codable, Equatable, Sendable {
    case classic6
    case daisy12
    case tulip3
    case lotus8
    case place5
}

/// Display copy shown when a bloom is tapped.
public struct BloomLore: Equatable, Sendable {
    public let displayName: String
    public let subtitle: String

    public init(displayName: String, subtitle: String) {
        self.displayName = displayName
        self.subtitle = subtitle
    }
}

/// A grown garden element, ready to render. Position is derived (not stored) so
/// memories are never duplicated; the scene maps `position` into screen space.
public struct GardenElement: Equatable, Sendable {
    public let sourceID: UUID
    public let kind: GardenElementKind
    public let date: Date
    public let position: GardenPoint
    public let chapter: BloomChapter
    public let shape: BloomShape
    /// Shrine bloom at 10 / 50 / 100 total moments (not tied to a single memory).
    public let isLegend: Bool
    /// 0 = first color cycle (moments 1–49); 1 = richer second cycle (50–99).
    public let cycle: Int

    public init(
        sourceID: UUID,
        kind: GardenElementKind,
        date: Date,
        position: GardenPoint,
        chapter: BloomChapter = .white,
        shape: BloomShape = .classic6,
        isLegend: Bool = false,
        cycle: Int = 0
    ) {
        self.sourceID = sourceID
        self.kind = kind
        self.date = date
        self.position = position
        self.chapter = chapter
        self.shape = shape
        self.isLegend = isLegend
        self.cycle = cycle
    }
}

/// The garden's mood. `resting` is the kind dormancy state (calm palette) the
/// garden enters after a quiet stretch — it never wilts or loses progress.
public enum GardenSeason: String, Codable, Equatable, Sendable {
    case blooming
    case resting
}
