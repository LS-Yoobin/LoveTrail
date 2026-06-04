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
    /// Stable id for the local user's birthday row created during onboarding.
    static let localUserBirthdayID = UUID(uuidString: "7E4A9B12-3C5D-4F8A-9E01-2B6D8C4A1F30")!

    static func localUserBirthday(title: String, date: Date) -> SpecialDate {
        SpecialDate(id: localUserBirthdayID, title: title, date: date)
    }

    static func birthdayTitle(for nickname: String) -> String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "My Birthday" }
        return "\(trimmed)'s Birthday"
    }
}
