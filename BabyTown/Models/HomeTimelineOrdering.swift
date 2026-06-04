import Foundation

/// Sort rules for the home "Our Adventures" feed (newest memories first, birthdays
/// anchored just above founding moments, birthdays ordered latest-to-oldest).
enum HomeTimelineOrdering {

    struct SortableItem {
        let date: Date
        let stableKey: String
        let isProcessing: Bool
        let isBirthday: Bool
    }

    /// Newest-first for regular items and processing rows; birthdays are placed after
    /// all other rows, ordered latest-to-oldest (younger birth dates above older).
    static func sorted<Item>(
        _ items: [Item],
        sortable: (Item) -> SortableItem
    ) -> [Item] {
        let keys = items.map { sortable($0) }
        let indexed = zip(items, keys).map { ($0, $1) }

        let processing = indexed.filter(\.1.isProcessing)
        let nonProcessing = indexed.filter { !$1.isProcessing }
        let regular = nonProcessing.filter { !$1.isBirthday }
        let birthdays = nonProcessing.filter(\.1.isBirthday)

        func compareNewestFirst(_ lhs: SortableItem, _ rhs: SortableItem) -> Bool {
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            return lhs.stableKey < rhs.stableKey
        }

        func compareOldestFirst(_ lhs: SortableItem, _ rhs: SortableItem) -> Bool {
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }
            return lhs.stableKey < rhs.stableKey
        }

        let sortedProcessing = processing.sorted { compareNewestFirst($0.1, $1.1) }.map(\.0)
        let sortedRegular = regular.sorted { compareNewestFirst($0.1, $1.1) }.map(\.0)
        let sortedBirthdays = birthdays.sorted { compareNewestFirst($0.1, $1.1) }.map(\.0)

        return sortedProcessing + sortedRegular + sortedBirthdays
    }
}
