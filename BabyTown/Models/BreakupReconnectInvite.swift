import Foundation

struct BreakupReconnectInvite: Codable, Identifiable, Equatable {
    let id: UUID
    let senderUserId: String
    let recipientUserId: String
    let sentAt: Date
    var status: InviteStatus

    enum InviteStatus: String, Codable, Equatable {
        case pending
        case accepted
        case declined
        case expired
    }

    enum CodingKeys: String, CodingKey {
        case id, senderUserId, recipientUserId, sentAt, status
    }

    init(
        id: UUID = UUID(),
        senderUserId: String,
        recipientUserId: String,
        sentAt: Date = Date(),
        status: InviteStatus = .pending
    ) {
        self.id = id
        self.senderUserId = senderUserId
        self.recipientUserId = recipientUserId
        self.sentAt = sentAt
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        senderUserId = try c.decode(String.self, forKey: .senderUserId)
        recipientUserId = try c.decode(String.self, forKey: .recipientUserId)
        sentAt = try c.decode(Date.self, forKey: .sentAt)
        status = try c.decodeIfPresent(InviteStatus.self, forKey: .status) ?? .pending
    }
}
