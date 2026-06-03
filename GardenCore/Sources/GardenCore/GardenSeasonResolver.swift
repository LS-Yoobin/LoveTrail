import Foundation

/// Decides whether the garden is blooming or gently resting. Pure function of
/// the last-activity timestamp — never punishing, never lossy.
public struct GardenSeasonResolver {
    /// A garden with no activity for this long enters its calm resting season.
    public let restingThreshold: TimeInterval

    public init(restingThreshold: TimeInterval = 14 * 86_400) {
        self.restingThreshold = restingThreshold
    }

    public func season(lastActivity: Date?, now: Date = Date()) -> GardenSeason {
        guard let lastActivity else { return .blooming }
        let elapsed = now.timeIntervalSince(lastActivity)
        return elapsed >= restingThreshold ? .resting : .blooming
    }
}
