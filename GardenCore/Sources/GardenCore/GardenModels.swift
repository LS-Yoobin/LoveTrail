import Foundation

/// The kind of loving act a garden element grew from.
public enum GardenActKind: String, Codable, Equatable, Sendable {
    case basicMilestone // every 10 unlocked moments
    case milestone50
    case milestone100
    case birthday
    case anniversary
    case letter
    // Legacy values kept for tolerant decoding of older builds.
    case moment
    case place
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
    case birthdayFlower
    case anniversaryFlower
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
    case white, yellow, red, blue, purple, black, birthday, anniversary
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
    /// Large shrine bloom at 50 / 100 moment milestones.
    public let isLegend: Bool
    /// Reserved for richer petal rendering on milestone bouquets.
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
