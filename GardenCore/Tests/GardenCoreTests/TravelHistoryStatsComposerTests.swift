import XCTest
@testable import GardenCore

final class TravelHistoryStatsComposerTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .init(identifier: .gregorian),
                       year: y, month: m, day: d).date!
    }

    private func moment(_ y: Int, _ m: Int, _ d: Int,
                        place: String? = nil,
                        country: String? = nil,
                        lat: Double = 37.77,
                        lon: Double = -122.42,
                        userSet: Bool = false) -> TravelMemoryInput {
        TravelMemoryInput(
            dateTaken: date(y, m, d),
            placeName: place,
            country: country,
            latitude: lat,
            longitude: lon,
            isPlaceNameUserSet: userSet
        )
    }

    func testEmptyInputsProduceZeros() {
        let stats = TravelHistoryStatsComposer().compose(moments: [], prompts: [])
        XCTAssertEqual(stats, TravelHistoryStats(countries: 0, cities: 0, places: 0))
    }

    func testCountriesAreDistinctAndCaseInsensitive() {
        let moments = [
            moment(2024, 1, 1, country: "USA"),
            moment(2024, 2, 1, country: "usa"),
            moment(2024, 3, 1, country: "Japan"),
        ]
        let stats = TravelHistoryStatsComposer().compose(moments: moments, prompts: [])
        XCTAssertEqual(stats.countries, 2)
    }

    func testPlacesCountUniqueDayAndPlaceClusters() {
        let moments = [
            moment(2024, 6, 1, place: "Blue Bottle", lat: 37.1, lon: -122.1),
            moment(2024, 6, 1, place: "Blue Bottle", lat: 37.2, lon: -122.2),
            moment(2024, 6, 2, place: "Blue Bottle", lat: 37.3, lon: -122.3),
        ]
        let stats = TravelHistoryStatsComposer().compose(moments: moments, prompts: [])
        XCTAssertEqual(stats.places, 2)
    }

    func testMomentsWithoutLocationAreExcludedFromPlaces() {
        let moments = [
            TravelMemoryInput(
                dateTaken: date(2024, 1, 1),
                placeName: "Somewhere",
                country: "USA",
                latitude: nil,
                longitude: nil,
                isPlaceNameUserSet: false
            )
        ]
        let stats = TravelHistoryStatsComposer().compose(moments: moments, prompts: [])
        XCTAssertEqual(stats.places, 0)
        XCTAssertEqual(stats.countries, 1)
    }

    func testCitiesExtractedFromCityStatePattern() {
        let moments = [
            moment(2024, 1, 1, place: "San Francisco, CA", userSet: false),
            moment(2024, 2, 1, place: "Castro Valley, CA", userSet: false),
            moment(2024, 3, 1, place: "Blue Bottle Coffee", userSet: true),
        ]
        let stats = TravelHistoryStatsComposer().compose(moments: moments, prompts: [])
        XCTAssertEqual(stats.cities, 2)
    }

    func testCityExtractionHelper() {
        XCTAssertEqual(TravelHistoryStatsComposer.city(from: "San Francisco, CA"), "San Francisco")
        XCTAssertEqual(TravelHistoryStatsComposer.city(from: "Portland, Oregon"), "Portland")
        XCTAssertNil(TravelHistoryStatsComposer.city(from: "Blue Bottle Coffee"))
        XCTAssertNil(TravelHistoryStatsComposer.city(from: nil))
    }

    func testPromptMemoriesIncludedInStats() {
        let prompts = [
            moment(2024, 5, 1, place: "Oakland, CA", country: "USA", lat: 37.8, lon: -122.2)
        ]
        let stats = TravelHistoryStatsComposer().compose(moments: [], prompts: prompts)
        XCTAssertEqual(stats.countries, 1)
        XCTAssertEqual(stats.cities, 1)
        XCTAssertEqual(stats.places, 1)
    }
}
