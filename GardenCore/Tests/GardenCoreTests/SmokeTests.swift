import XCTest
@testable import GardenCore

final class SmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(GardenCore.version, "1")
    }
}
