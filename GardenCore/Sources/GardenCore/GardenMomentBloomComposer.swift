import Foundation

/// A saved timeline moment eligible to grow a garden flower.
public struct GardenMomentInput: Equatable, Sendable {
    public let id: UUID
    public let dateTaken: Date
    public let hasDistinctPlace: Bool

    public init(id: UUID, dateTaken: Date, hasDistinctPlace: Bool) {
        self.id = id
        self.dateTaken = dateTaken
        self.hasDistinctPlace = hasDistinctPlace
    }
}

/// Maps saved moments to garden acts: at most one flower per calendar day (the
/// latest moment that day represents the bloom). Days with no saved moments
/// produce no blooms.
public struct GardenMomentBloomComposer {
    /// Matches timeline day grouping in the app (`DaySection`).
    public var calendarTimeZone: TimeZone

    public init(calendarTimeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles")!) {
        self.calendarTimeZone = calendarTimeZone
    }

    public func acts(from moments: [GardenMomentInput]) -> [GardenActInput] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = calendarTimeZone

        var representativeByDay: [Date: GardenMomentInput] = [:]
        for moment in moments {
            let day = calendar.startOfDay(for: moment.dateTaken)
            if let existing = representativeByDay[day] {
                if moment.dateTaken >= existing.dateTaken {
                    representativeByDay[day] = moment
                }
            } else {
                representativeByDay[day] = moment
            }
        }

        return representativeByDay.values.map { moment in
            GardenActInput(
                id: moment.id,
                date: moment.dateTaken,
                kind: moment.hasDistinctPlace ? .place : .moment
            )
        }
    }
}
