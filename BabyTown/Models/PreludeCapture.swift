import Foundation

struct PreludeCapture: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let type: CaptureType
    var isIncludedInGift: Bool
    var isPartnerRetroactive: Bool

    var noteText: String?
    var noteMood: ProfileNoteMood?
    var notePhotoId: UUID?
    var firstLabel: String?
    var firstPhotoId: UUID?
    var voiceMemoFileId: String?
    var reasonText: String?
    var firstDate: Date?
    /// Backend Covela capture id, set once this capture has been synced to the server.
    var serverId: String?

    enum CaptureType: String, Codable {
        case note, first, voiceMemo, reason
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        type: CaptureType,
        isIncludedInGift: Bool = true,
        isPartnerRetroactive: Bool = false,
        noteText: String? = nil,
        noteMood: ProfileNoteMood? = nil,
        notePhotoId: UUID? = nil,
        firstLabel: String? = nil,
        firstPhotoId: UUID? = nil,
        voiceMemoFileId: String? = nil,
        reasonText: String? = nil,
        firstDate: Date? = nil,
        serverId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.isIncludedInGift = isIncludedInGift
        self.isPartnerRetroactive = isPartnerRetroactive
        self.noteText = noteText
        self.noteMood = noteMood
        self.notePhotoId = notePhotoId
        self.firstLabel = firstLabel
        self.firstPhotoId = firstPhotoId
        self.voiceMemoFileId = voiceMemoFileId
        self.reasonText = reasonText
        self.firstDate = firstDate
        self.serverId = serverId
    }

    var displayTitle: String {
        switch type {
        case .note: return noteText?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60).description ?? "Note"
        case .first: return firstLabel ?? "A First"
        case .voiceMemo: return "Voice Memo"
        case .reason: return reasonText?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60).description ?? "A Reason"
        }
    }

    var typeLabel: String {
        switch type {
        case .note: return "Note"
        case .first: return "First"
        case .voiceMemo: return "Voice"
        case .reason: return "Reason"
        }
    }

    var typeIcon: String {
        switch type {
        case .note: return "pencil.and.scribble"
        case .first: return "star.fill"
        case .voiceMemo: return "mic.fill"
        case .reason: return "heart.fill"
        }
    }

    /// Date used for timeline ordering and display.
    var timelineDate: Date {
        type == .first ? (firstDate ?? createdAt) : createdAt
    }
}
