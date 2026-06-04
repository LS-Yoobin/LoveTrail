import XCTest
@testable import GardenCore

final class ImportantDatesComposerTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .init(identifier: .gregorian),
                       year: y, month: m, day: d).date!
    }

    func testFoundationalAndSpecialAreMergedAndSortedAscending() {
        let special = [
            SpecialDateInput(id: UUID(), title: "Anniversary", date: date(2025, 6, 1)),
            SpecialDateInput(id: UUID(), title: "Trip", date: date(2024, 1, 1)),
        ]
        let items = ImportantDatesComposer().compose(
            firstMet: date(2024, 2, 14),
            official: date(2024, 6, 1),
            special: special
        )
        XCTAssertEqual(items.map(\.title),
                       ["Trip", "When we first met", "When we became official", "Anniversary"])
    }

    func testMissingFoundationalDatesAreOmitted() {
        let items = ImportantDatesComposer().compose(
            firstMet: nil, official: date(2024, 6, 1), special: [])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].kind, .official)
    }

    func testEmptyInputsProduceEmptyList() {
        XCTAssertTrue(ImportantDatesComposer().compose(
            firstMet: nil, official: nil, special: []).isEmpty)
    }

    func testFoundationalItemsCarryFixedIdsAndKinds() {
        let items = ImportantDatesComposer().compose(
            firstMet: date(2024, 2, 14), official: date(2024, 6, 1), special: [])
        XCTAssertEqual(items.first { $0.kind == .firstMet }?.id, "firstMet")
        XCTAssertEqual(items.first { $0.kind == .official }?.id, "official")
    }

    func testSpecialItemKeepsItsUUIDStringAsId() {
        let uid = UUID()
        let items = ImportantDatesComposer().compose(
            firstMet: nil, official: nil,
            special: [SpecialDateInput(id: uid, title: "X", date: date(2025, 1, 1))])
        XCTAssertEqual(items[0].id, uid.uuidString)
        XCTAssertEqual(items[0].kind, .special)
    }

    func testBirthdaysAreOrderedLatestToOldestAmongChronologicalList() {
        let items = ImportantDatesComposer().compose(
            firstMet: date(2020, 1, 1),
            official: nil,
            special: [
                SpecialDateInput(id: UUID(), title: "Partner's Birthday", date: date(1992, 3, 4), isBirthday: true),
                SpecialDateInput(id: UUID(), title: "My Birthday", date: date(1998, 7, 15), isBirthday: true),
                SpecialDateInput(id: UUID(), title: "Anniversary", date: date(2024, 6, 1)),
            ]
        )
        XCTAssertEqual(items.map(\.title), [
            "My Birthday",
            "Partner's Birthday",
            "When we first met",
            "Anniversary",
        ])
    }
}
