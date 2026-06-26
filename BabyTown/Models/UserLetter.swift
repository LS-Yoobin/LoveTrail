import Foundation

struct UserLetter: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var body: String
    var blocks: [LetterBlock]
    let createdAt: Date
    var scheduledFor: Date?
    var sentAt: Date?

    init(
        id: UUID,
        title: String,
        body: String,
        blocks: [LetterBlock] = [],
        createdAt: Date,
        scheduledFor: Date?,
        sentAt: Date?
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.blocks = blocks
        self.createdAt = createdAt
        self.scheduledFor = scheduledFor
        self.sentAt = sentAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        blocks = try container.decodeIfPresent([LetterBlock].self, forKey: .blocks) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        scheduledFor = try container.decodeIfPresent(Date.self, forKey: .scheduledFor)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(scheduledFor, forKey: .scheduledFor)
        try container.encodeIfPresent(sentAt, forKey: .sentAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, body, blocks, createdAt, scheduledFor, sentAt
    }

    var isScheduled: Bool {
        scheduledFor != nil && sentAt == nil
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Letter" : trimmed
    }

    var bodyPreview: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
            return firstLine
        }
        guard let firstBlock = blocks.first else { return "" }
        let blockPreview = firstBlock.previewText
        if blockPreview.isEmpty { return firstBlock.typeLabel }
        let firstLine = blockPreview.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? blockPreview
        return firstLine
    }

    var sortDate: Date {
        scheduledFor ?? sentAt ?? createdAt
    }
}
