import Foundation

/// The only persisted garden state: when the garden was last tended. Bloom
/// positions are derived from act UUIDs (see GardenComposer), so memories are
/// never duplicated here. Shaped to migrate to a per-couple backend record later.
public struct GardenState: Codable, Equatable, Sendable {
    public var lastActivity: Date?

    public init(lastActivity: Date? = nil) {
        self.lastActivity = lastActivity
    }

    /// Tolerant decode: a missing field defaults rather than failing, so the
    /// format can grow safely (mirrors `PetState`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastActivity = try c.decodeIfPresent(Date.self, forKey: .lastActivity)
    }

    public func season(resolver: GardenSeasonResolver = GardenSeasonResolver(),
                       now: Date = Date()) -> GardenSeason {
        resolver.season(lastActivity: lastActivity, now: now)
    }

    /// Records a new loving act. Returns the updated state and whether this act
    /// revived a resting garden (so the UI can show the warm welcome-back line).
    public func registering(actAt date: Date,
                            resolver: GardenSeasonResolver = GardenSeasonResolver())
    -> (state: GardenState, didRevive: Bool) {
        let wasResting = lastActivity != nil
            && resolver.season(lastActivity: lastActivity, now: date) == .resting
        var copy = self
        copy.lastActivity = date
        return (copy, wasResting)
    }
}
