import XCTest
@testable import GardenCore

final class GardenStateTests: XCTestCase {
    private func days(_ n: Double) -> TimeInterval { n * 86_400 }

    func testRegisteringActAfterRestRevives() {
        let now = Date()
        let state = GardenState(lastActivity: now.addingTimeInterval(-days(30)))
        let result = state.registering(actAt: now)
        XCTAssertTrue(result.didRevive, "garden was resting and should revive")
        XCTAssertEqual(result.state.lastActivity, now)
        XCTAssertEqual(result.state.season(now: now), .blooming)
    }

    func testRegisteringActWhileBloomingDoesNotRevive() {
        let now = Date()
        let state = GardenState(lastActivity: now.addingTimeInterval(-days(2)))
        let result = state.registering(actAt: now)
        XCTAssertFalse(result.didRevive)
        XCTAssertEqual(result.state.lastActivity, now)
    }

    func testFirstEverActDoesNotCountAsRevival() {
        let now = Date()
        let state = GardenState(lastActivity: nil)
        let result = state.registering(actAt: now)
        XCTAssertFalse(result.didRevive, "a brand-new garden isn't 'reviving'")
        XCTAssertEqual(result.state.lastActivity, now)
    }

    func testCodableRoundTrips() throws {
        let original = GardenState(lastActivity: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GardenState.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
