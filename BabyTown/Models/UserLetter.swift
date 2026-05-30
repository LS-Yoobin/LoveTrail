import Foundation

struct UserLetter: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var body: String
    let createdAt: Date
    var scheduledFor: Date?
    var sentAt: Date?

    var isScheduled: Bool {
        scheduledFor != nil && sentAt == nil
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Letter" : trimmed
    }

    var bodyPreview: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        return firstLine
    }

    var sortDate: Date {
        scheduledFor ?? sentAt ?? createdAt
    }
}
