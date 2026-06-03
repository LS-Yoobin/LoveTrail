import XCTest
@testable import GardenCore

final class GardenSeasonResolverTests: XCTestCase {
    private let resolver = GardenSeasonResolver()
    private func days(_ n: Double) -> TimeInterval { n * 86_400 }

    func testRecentActivityIsBlooming() {
        let now = Date()
        let last = now.addingTimeInterval(-days(3))
        XCTAssertEqual(resolver.season(lastActivity: last, now: now), .blooming)
    }

    func testQuietStretchEntersResting() {
        let now = Date()
        let last = now.addingTimeInterval(-days(20))
        XCTAssertEqual(resolver.season(lastActivity: last, now: now), .resting)
    }

    func testNoActivityYetIsBlooming() {
        // A brand-new garden with no acts shows as gently blooming, never resting.
        XCTAssertEqual(resolver.season(lastActivity: nil, now: Date()), .blooming)
    }

    func testThresholdBoundaryIsResting() {
        let now = Date()
        let last = now.addingTimeInterval(-days(14))
        XCTAssertEqual(resolver.season(lastActivity: last, now: now), .resting)
    }
}
