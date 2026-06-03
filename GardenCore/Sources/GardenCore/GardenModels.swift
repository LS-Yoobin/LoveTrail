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

/// A grown garden element, ready to render. Position is derived (not stored) so
/// memories are never duplicated; the scene maps `position` into screen space.
public struct GardenElement: Equatable, Sendable {
    public let sourceID: UUID
    public let kind: GardenElementKind
    public let date: Date
    public let position: GardenPoint

    public init(sourceID: UUID, kind: GardenElementKind, date: Date, position: GardenPoint) {
        self.sourceID = sourceID
        self.kind = kind
        self.date = date
        self.position = position
    }
}

/// The garden's mood. `resting` is the kind dormancy state (calm palette) the
/// garden enters after a quiet stretch — it never wilts or loses progress.
public enum GardenSeason: String, Codable, Equatable, Sendable {
    case blooming
    case resting
}
