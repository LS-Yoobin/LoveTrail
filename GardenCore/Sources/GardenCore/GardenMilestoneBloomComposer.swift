import Foundation

/// A couple member's birthday (month/day) used for annual garden blooms.
public struct GardenBirthdayInput: Equatable, Sendable {
    public let personID: UUID
    public let date: Date
    public let title: String

    public init(personID: UUID, date: Date, title: String) {
        self.personID = personID
        self.date = date
        self.title = title
    }
}

/// Inputs for controlled garden growth: milestone bouquets, annual birthdays,
/// and anniversaries — not one flower per saved photo day.
public struct GardenBloomScheduleInput: Equatable, Sendable {
    /// Timeline memory clusters (day + place cards), not individual photo count.
    public let unlockedMomentCount: Int
    public let birthdays: [GardenBirthdayInput]
    public let anniversaryDate: Date?
    public let relationshipAnchor: Date?
    public let now: Date
    public var calendarTimeZone: TimeZone

    public init(
        unlockedMomentCount: Int,
        birthdays: [GardenBirthdayInput] = [],
        anniversaryDate: Date? = nil,
        relationshipAnchor: Date? = nil,
        now: Date = Date(),
        calendarTimeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles")!
    ) {
        self.unlockedMomentCount = unlockedMomentCount
        self.birthdays = birthdays
        self.anniversaryDate = anniversaryDate
        self.relationshipAnchor = relationshipAnchor
        self.now = now
        self.calendarTimeZone = calendarTimeZone
    }
}

/// Awards garden blooms on a fixed schedule so the field stays sparse and meaningful.
public struct GardenMilestoneBloomComposer {
    public static let basicMomentInterval = 10
    public static let milestone50Count = 50
    public static let milestone100Count = 100

    public var calendarTimeZone: TimeZone

    public init(calendarTimeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles")!) {
        self.calendarTimeZone = calendarTimeZone
    }

    public func acts(from input: GardenBloomScheduleInput) -> [GardenActInput] {
        var acts: [GardenActInput] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = input.calendarTimeZone

        let anchor = normalizedAnchor(from: input, calendar: calendar)

        for threshold in stride(
            from: Self.basicMomentInterval,
            through: input.unlockedMomentCount,
            by: Self.basicMomentInterval
        ) {
            acts.append(
                GardenActInput(
                    id: Self.basicMilestoneID(threshold: threshold),
                    date: anchor,
                    kind: .basicMilestone
                )
            )
        }

        if input.unlockedMomentCount >= Self.milestone50Count {
            acts.append(
                GardenActInput(
                    id: Self.milestoneID(Self.milestone50Count),
                    date: anchor,
                    kind: .milestone50
                )
            )
        }

        if input.unlockedMomentCount >= Self.milestone100Count {
            acts.append(
                GardenActInput(
                    id: Self.milestoneID(Self.milestone100Count),
                    date: anchor,
                    kind: .milestone100
                )
            )
        }

        for birthday in input.birthdays {
            for occurrence in annualOccurrences(
                monthDay: birthday.date,
                anchor: anchor,
                now: input.now,
                calendar: calendar
            ) {
                let year = calendar.component(.year, from: occurrence)
                acts.append(
                    GardenActInput(
                        id: Self.birthdayYearID(personID: birthday.personID, year: year),
                        date: occurrence,
                        kind: .birthday
                    )
                )
            }
        }

        if let anniversaryDate = input.anniversaryDate {
            for occurrence in anniversaryOccurrences(
                monthDay: anniversaryDate,
                anchor: anchor,
                now: input.now,
                calendar: calendar
            ) {
                let year = calendar.component(.year, from: occurrence)
                acts.append(
                    GardenActInput(
                        id: Self.anniversaryYearID(year: year),
                        date: occurrence,
                        kind: .anniversary
                    )
                )
            }
        }

        return acts
    }

    static func basicMilestoneID(threshold: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012x", threshold))!
    }

    static func milestoneID(_ milestone: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-9000-%012x", milestone))!
    }

    static func birthdayYearID(personID: UUID, year: Int) -> UUID {
        var bytes = personID.uuid
        bytes.8 = UInt8((year >> 24) & 0xFF)
        bytes.9 = UInt8((year >> 16) & 0xFF)
        bytes.10 = UInt8((year >> 8) & 0xFF)
        bytes.11 = UInt8(year & 0xFF)
        return UUID(uuid: bytes)
    }

    static func anniversaryYearID(year: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-a000-%012x", year))!
    }

    static func basicMilestoneThreshold(for id: UUID) -> Int? {
        guard id.uuidString.contains("-4000-8000-") else { return nil }
        let suffix = id.uuidString.suffix(12)
        guard let value = Int(suffix, radix: 16), value > 0, value % basicMomentInterval == 0 else {
            return nil
        }
        return value
    }

    static func milestoneCount(for id: UUID) -> Int? {
        guard id.uuidString.contains("-4000-9000-") else { return nil }
        let suffix = id.uuidString.suffix(12)
        guard let value = Int(suffix, radix: 16), [milestone50Count, milestone100Count].contains(value) else {
            return nil
        }
        return value
    }

    private func normalizedAnchor(from input: GardenBloomScheduleInput, calendar: Calendar) -> Date {
        if let relationshipAnchor = input.relationshipAnchor {
            return calendar.startOfDay(for: relationshipAnchor)
        }
        return calendar.startOfDay(for: input.now)
    }

    /// Birthdays on or after the relationship anchor through today.
    private func annualOccurrences(
        monthDay: Date,
        anchor: Date,
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        let month = calendar.component(.month, from: monthDay)
        let day = calendar.component(.day, from: monthDay)
        let startYear = calendar.component(.year, from: anchor)
        let endYear = calendar.component(.year, from: now)

        var results: [Date] = []
        for year in startYear...endYear {
            guard let occurrence = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                continue
            }
            if occurrence >= anchor && occurrence <= now {
                results.append(occurrence)
            }
        }
        return results
    }

    /// Anniversaries start the year after the anchor (first anniversary onward).
    private func anniversaryOccurrences(
        monthDay: Date,
        anchor: Date,
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        let month = calendar.component(.month, from: monthDay)
        let day = calendar.component(.day, from: monthDay)
        let startYear = calendar.component(.year, from: anchor) + 1
        let endYear = calendar.component(.year, from: now)

        guard startYear <= endYear else { return [] }

        var results: [Date] = []
        for year in startYear...endYear {
            guard let occurrence = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                continue
            }
            if occurrence <= now {
                results.append(occurrence)
            }
        }
        return results
    }
}
