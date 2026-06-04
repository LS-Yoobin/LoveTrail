import Foundation

/// A UI-free description of one user-authored special date. The app maps its
/// `SpecialDate` model into this so GardenCore stays Foundation-only.
public struct SpecialDateInput: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let date: Date
    public let isBirthday: Bool
    public init(id: UUID, title: String, date: Date, isBirthday: Bool = false) {
        self.id = id
        self.title = title
        self.date = date
        self.isBirthday = isBirthday
    }
}

/// One row in the merged Important Dates list, ready to render.
public struct ImportantDateItem: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case firstMet   // foundational, read-only on the profile page
        case official   // foundational, read-only on the profile page
        case special    // user-authored, editable
    }
    /// Stable id: "firstMet"/"official" for the two foundational rows, or the
    /// special date's UUID string.
    public let id: String
    public let title: String
    public let date: Date
    public let kind: Kind
    public let isBirthday: Bool

    public init(id: String, title: String, date: Date, kind: Kind, isBirthday: Bool = false) {
        self.id = id
        self.title = title
        self.date = date
        self.kind = kind
        self.isBirthday = isBirthday
    }
}

/// Merges the two foundational dates (when present) with the user's special
/// dates. Non-birthdays are newest-first; birthdays sit at the bottom, ordered
/// latest-to-oldest among themselves (same rule as the home timeline).
public struct ImportantDatesComposer {
    public init() {}

    public func compose(firstMet: Date?,
                        official: Date?,
                        special: [SpecialDateInput]) -> [ImportantDateItem] {
        var items: [ImportantDateItem] = []
        if let firstMet {
            items.append(ImportantDateItem(id: "firstMet",
                                           title: "When we first met",
                                           date: firstMet, kind: .firstMet))
        }
        if let official {
            items.append(ImportantDateItem(id: "official",
                                           title: "When we became official",
                                           date: official, kind: .official))
        }
        for s in special {
            items.append(ImportantDateItem(id: s.id.uuidString,
                                           title: s.title,
                                           date: s.date,
                                           kind: .special,
                                           isBirthday: s.isBirthday))
        }
        return Self.sortedForDisplay(items)
    }

    /// Newest-first for regular rows; birthdays anchored at the bottom, latest-first.
    static func sortedForDisplay(_ items: [ImportantDateItem]) -> [ImportantDateItem] {
        func compareNewestFirst(_ lhs: ImportantDateItem, _ rhs: ImportantDateItem) -> Bool {
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id < rhs.id
        }
        let regular = items.filter { !$0.isBirthday }.sorted(by: compareNewestFirst)
        let birthdays = items.filter(\.isBirthday).sorted(by: compareNewestFirst)
        return regular + birthdays
    }
}
