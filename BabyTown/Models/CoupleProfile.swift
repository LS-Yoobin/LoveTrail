import Foundation

/// The local user's couple-profile state. Only the user's own identity and their
/// special dates are stored; the partner's identity is backend-authored later and
/// is intentionally absent. Tolerant decode (default-on-missing) mirrors PetState
/// / GardenState so the format can grow safely. The user's avatar image is stored
/// as a separate file (see DataPersistenceManager), not embedded here.
struct CoupleProfile: Codable, Equatable {
    var displayName: String?
    var specialDates: [SpecialDate]
    var stickers: [ProfileSticker]
    /// Short note shown on the garden canvas below the profile photo stickers.
    var profileNote: String?
    /// Normalized position of the note center on the sticker canvas (0…1).
    var profileNotePosition: NormalizedPoint?
    /// Normalized center of the vinyl record player on the scroll canvas (0…1).
    var recordPlayerPosition: NormalizedPoint?
    /// Garden canvas scale for the vinyl player; `nil` uses `VinylRecordPlayerView.gardenDefaultScale`.
    var recordPlayerScale: CGFloat?
    /// Normalized center of the Watch Together TV on the scroll canvas (0…1).
    var watchTogetherTVPosition: NormalizedPoint?
    /// Garden canvas scale for the Watch Together TV; `nil` uses `WatchTogetherTVView.gardenDefaultScale`.
    var watchTogetherTVScale: CGFloat?
    var relationshipStage: RelationshipStage
    var inviteSent: Bool

    init(
        displayName: String? = nil,
        specialDates: [SpecialDate] = [],
        stickers: [ProfileSticker] = [],
        profileNote: String? = nil,
        profileNotePosition: NormalizedPoint? = nil,
        recordPlayerPosition: NormalizedPoint? = nil,
        recordPlayerScale: CGFloat? = nil,
        watchTogetherTVPosition: NormalizedPoint? = nil,
        watchTogetherTVScale: CGFloat? = nil,
        relationshipStage: RelationshipStage = .prelude,
        inviteSent: Bool = false
    ) {
        self.displayName = displayName
        self.specialDates = specialDates
        self.stickers = stickers
        self.profileNote = profileNote
        self.profileNotePosition = profileNotePosition
        self.recordPlayerPosition = recordPlayerPosition
        self.recordPlayerScale = recordPlayerScale
        self.watchTogetherTVPosition = watchTogetherTVPosition
        self.watchTogetherTVScale = watchTogetherTVScale
        self.relationshipStage = relationshipStage
        self.inviteSent = inviteSent
    }

    enum CodingKeys: String, CodingKey {
        case displayName, specialDates, stickers, profileNote, profileNotePosition
        case recordPlayerPosition, recordPlayerScale
        case watchTogetherTVPosition, watchTogetherTVScale
        case relationshipStage, inviteSent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        specialDates = try c.decodeIfPresent([SpecialDate].self, forKey: .specialDates) ?? []
        stickers = try c.decodeIfPresent([ProfileSticker].self, forKey: .stickers) ?? []
        profileNote = try c.decodeIfPresent(String.self, forKey: .profileNote)
        profileNotePosition = try c.decodeIfPresent(NormalizedPoint.self, forKey: .profileNotePosition)
        recordPlayerPosition = try c.decodeIfPresent(NormalizedPoint.self, forKey: .recordPlayerPosition)
        recordPlayerScale = try c.decodeIfPresent(CGFloat.self, forKey: .recordPlayerScale)
        watchTogetherTVPosition = try c.decodeIfPresent(NormalizedPoint.self, forKey: .watchTogetherTVPosition)
        watchTogetherTVScale = try c.decodeIfPresent(CGFloat.self, forKey: .watchTogetherTVScale)
        relationshipStage = try c.decodeIfPresent(RelationshipStage.self, forKey: .relationshipStage) ?? .prelude
        inviteSent = try c.decodeIfPresent(Bool.self, forKey: .inviteSent) ?? false
    }
}
