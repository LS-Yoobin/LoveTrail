import Foundation

/// Pure counter for scheduled litter-box "use" events between a clean and now.
/// The cat uses the box at fixed hours each day; an uncleaned box is dirty once
/// at least one use event has elapsed since the last clean.
public enum LitterSchedule {
    /// The cat uses the litter box at 6 AM and 6 PM (local Pacific time).
    public static let defaultUseHours = [6, 18]

    public static func useEventsSinceLastClean(
        cleanedAt: Date,
        now: Date,
        useHours: [Int] = defaultUseHours,
        calendar: Calendar
    ) -> Int {
        guard now > cleanedAt else { return 0 }
        let startDay = calendar.startOfDay(for: cleanedAt)
        let endDay = calendar.startOfDay(for: now)

        var uses = 0
        var day = startDay
        while day <= endDay {
            for hour in useHours {
                guard let event = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
                if event > cleanedAt, event <= now { uses += 1 }
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return uses
    }
}
