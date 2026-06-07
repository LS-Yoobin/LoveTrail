import XCTest
@testable import GardenCore

final class GardenMemoryClusterCounterTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .init(identifier: .gregorian),
                       year: y, month: m, day: d).date!
    }

    private func memory(_ y: Int, _ m: Int, _ d: Int,
                        place: String = "Cafe",
                        lat: Double = 37.77,
                        lon: Double = -122.42) -> TravelMemoryInput {
        TravelMemoryInput(
            dateTaken: date(y, m, d),
            placeName: place,
            country: "USA",
            latitude: lat,
            longitude: lon,
            isPlaceNameUserSet: false
        )
    }

    func testMultiplePhotosSamePlaceCountAsOne() {
        let moments = [
            memory(2024, 6, 1, place: "Blue Bottle"),
            memory(2024, 6, 1, place: "Blue Bottle"),
            memory(2024, 6, 2, place: "Blue Bottle"),
        ]
        XCTAssertEqual(GardenMemoryClusterCounter().count(moments: moments), 2)
    }

    func testFortyNineDistinctPlacesStayBelowFiftyMilestone() {
        let moments = (1...49).map { day in
            memory(2024, 1, min(day, 28), place: "Place \(day)", lat: 37.0 + Double(day) * 0.01, lon: -122.0)
        }
        XCTAssertEqual(GardenMemoryClusterCounter().count(moments: moments), 49)
    }
}
