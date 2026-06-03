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
