import Foundation

/// One user-authored special date on the Couples Profile Page. The optional
/// photo is stored as a separate image file keyed by `id` (see
/// DataPersistenceManager), not embedded here.
struct SpecialDate: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    var isPinned: Bool
    var pinnedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        isPinned: Bool = false,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, date, isPinned, pinnedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedAt = try c.decodeIfPresent(Date.self, forKey: .pinnedAt)
    }
}

extension SpecialDate {
    /// Calendar used for home timeline ordering (matches `DaySection` grouping).
    static var homeTimelineCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar
    }

    /// Stable id for the local user's birthday row created during onboarding.
    static let localUserBirthdayID = UUID(uuidString: "7E4A9B12-3C5D-4F8A-9E01-2B6D8C4A1F30")!

    /// Stable id for the invited partner's birthday row (set when partner onboarding exists).
    static let localPartnerBirthdayID = UUID(uuidString: "A3C8F1E2-6B4D-4A90-B7E5-9D2F0C8A4E61")!

    var isBirthday: Bool {
        id == Self.localUserBirthdayID
            || id == Self.localPartnerBirthdayID
            || Self.isBirthdayTitle(title)
    }

    static func normalizedTitleForMatching(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .lowercased()
    }

    static func isBirthdayTitle(_ title: String) -> Bool {
        let normalized = normalizedTitleForMatching(title)
        if normalized == "my birthday" || normalized == "partner's birthday" { return true }
        if normalized.hasSuffix("'s birthday") { return true }
        return normalized.contains("birthday")
    }

    /// Normalized day for chronological ordering on the home timeline.
    var timelineSortDate: Date {
        Self.homeTimelineCalendar.startOfDay(for: date)
    }

    /// Assigns stable birthday ids to legacy rows and clears pin state (birthdays live in the timeline footer only).
    static func migrateBirthdayEntries(in profile: inout CoupleProfile) -> Bool {
        var changed = false
        var hasUserBirthday = profile.specialDates.contains { $0.id == localUserBirthdayID }

        for index in profile.specialDates.indices {
            var entry = profile.specialDates[index]
            guard entry.isBirthday else { continue }

            if entry.isPinned {
                entry.isPinned = false
                entry.pinnedAt = nil
                changed = true
            }

            if entry.id != localUserBirthdayID, entry.id != localPartnerBirthdayID, !hasUserBirthday {
                entry = SpecialDate(
                    id: localUserBirthdayID,
                    title: entry.title,
                    date: entry.date,
                    isPinned: entry.isPinned,
                    pinnedAt: entry.pinnedAt
                )
                hasUserBirthday = true
                changed = true
            }

            profile.specialDates[index] = entry
        }
        return changed
    }

    static func normalizedTimelineDay(_ date: Date) -> Date {
        homeTimelineCalendar.startOfDay(for: date)
    }

    static func localUserBirthday(title: String, date: Date) -> SpecialDate {
        SpecialDate(id: localUserBirthdayID, title: title, date: normalizedTimelineDay(date))
    }

    static func localPartnerBirthday(title: String, date: Date) -> SpecialDate {
        SpecialDate(id: localPartnerBirthdayID, title: title, date: normalizedTimelineDay(date))
    }

    static func birthdayTitle(for nickname: String) -> String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "My Birthday" }
        return "\(trimmed)'s Birthday"
    }

    static func partnerBirthdayTitle(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Partner's Birthday" }
        return "\(trimmed)'s Birthday"
    }
}
