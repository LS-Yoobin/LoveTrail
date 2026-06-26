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
    /// Optional mood stamp tinting the profile note.
    var profileNoteMood: ProfileNoteMood?
    /// Ambient mood for the secret garden (icon rain + tint).
    var gardenMood: ProfileNoteMood?
    /// When `gardenMood` was last chosen; cleared when mood is cleared or expires.
    var gardenMoodSelectedAt: Date?
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
    /// Normalized center of the prelude gift book on the scroll canvas (0…1).
    var preludeBookPosition: NormalizedPoint?
    /// Garden canvas scale for the prelude book; `nil` uses `PreludeBookView.gardenDefaultScale`.
    var preludeBookScale: CGFloat?
    /// Shared couple identifier set by the backend when two users are linked.
    var coupleId: String?
    /// The date on which the couple broke up; `nil` when still together.
    var breakupDate: Date?
    /// Expiry date of the archive window after a breakup; data is deleted after this date.
    var archiveExpiryDate: Date?
    /// Whether the local user has "stepped out" of the relationship (soft-breakup initiator flag).
    var hasSteppedOut: Bool
    var relationshipStage: RelationshipStage
    var inviteSent: Bool

    init(
        displayName: String? = nil,
        specialDates: [SpecialDate] = [],
        stickers: [ProfileSticker] = [],
        profileNote: String? = nil,
        profileNoteMood: ProfileNoteMood? = nil,
        gardenMood: ProfileNoteMood? = nil,
        gardenMoodSelectedAt: Date? = nil,
        profileNotePosition: NormalizedPoint? = nil,
        recordPlayerPosition: NormalizedPoint? = nil,
        recordPlayerScale: CGFloat? = nil,
        watchTogetherTVPosition: NormalizedPoint? = nil,
        watchTogetherTVScale: CGFloat? = nil,
        preludeBookPosition: NormalizedPoint? = nil,
        preludeBookScale: CGFloat? = nil,
        coupleId: String? = nil,
        breakupDate: Date? = nil,
        archiveExpiryDate: Date? = nil,
        hasSteppedOut: Bool = false,
        relationshipStage: RelationshipStage = .prelude,
        inviteSent: Bool = false
    ) {
        self.displayName = displayName
        self.specialDates = specialDates
        self.stickers = stickers
        self.profileNote = profileNote
        self.profileNoteMood = profileNoteMood
        self.gardenMood = gardenMood
        self.gardenMoodSelectedAt = gardenMoodSelectedAt
        self.profileNotePosition = profileNotePosition
        self.recordPlayerPosition = recordPlayerPosition
        self.recordPlayerScale = recordPlayerScale
        self.watchTogetherTVPosition = watchTogetherTVPosition
        self.watchTogetherTVScale = watchTogetherTVScale
        self.preludeBookPosition = preludeBookPosition
        self.preludeBookScale = preludeBookScale
        self.coupleId = coupleId
        self.breakupDate = breakupDate
        self.archiveExpiryDate = archiveExpiryDate
        self.hasSteppedOut = hasSteppedOut
        self.relationshipStage = relationshipStage
        self.inviteSent = inviteSent
    }

    enum CodingKeys: String, CodingKey {
        case displayName, specialDates, stickers, profileNote, profileNoteMood, gardenMood, gardenMoodSelectedAt, profileNotePosition
        case recordPlayerPosition, recordPlayerScale
        case watchTogetherTVPosition, watchTogetherTVScale
        case preludeBookPosition, preludeBookScale
        case coupleId, breakupDate, archiveExpiryDate, hasSteppedOut
        case relationshipStage, inviteSent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        specialDates = try c.decodeIfPresent([SpecialDate].self, forKey: .specialDates) ?? []
        stickers = try c.decodeIfPresent([ProfileSticker].self, forKey: .stickers) ?? []
        profileNote = try c.decodeIfPresent(String.self, forKey: .profileNote)
        profileNoteMood = try c.decodeIfPresent(ProfileNoteMood.self, forKey: .profileNoteMood)
        gardenMood = try c.decodeIfPresent(ProfileNoteMood.self, forKey: .gardenMood)
        gardenMoodSelectedAt = try c.decodeIfPresent(Date.self, forKey: .gardenMoodSelectedAt)
        profileNotePosition = try c.decodeIfPresent(NormalizedPoint.self, forKey: .profileNotePosition)
        recordPlayerPosition = try c.decodeIfPresent(NormalizedPoint.self, forKey: .recordPlayerPosition)
        recordPlayerScale = try c.decodeIfPresent(CGFloat.self, forKey: .recordPlayerScale)
        watchTogetherTVPosition = try c.decodeIfPresent(NormalizedPoint.self, forKey: .watchTogetherTVPosition)
        watchTogetherTVScale = try c.decodeIfPresent(CGFloat.self, forKey: .watchTogetherTVScale)
        preludeBookPosition = try c.decodeIfPresent(NormalizedPoint.self, forKey: .preludeBookPosition)
        preludeBookScale = try c.decodeIfPresent(CGFloat.self, forKey: .preludeBookScale)
        coupleId = try c.decodeIfPresent(String.self, forKey: .coupleId)
        breakupDate = try c.decodeIfPresent(Date.self, forKey: .breakupDate)
        archiveExpiryDate = try c.decodeIfPresent(Date.self, forKey: .archiveExpiryDate)
        hasSteppedOut = try c.decodeIfPresent(Bool.self, forKey: .hasSteppedOut) ?? false
        relationshipStage = try c.decodeIfPresent(RelationshipStage.self, forKey: .relationshipStage) ?? .prelude
        inviteSent = try c.decodeIfPresent(Bool.self, forKey: .inviteSent) ?? false
    }

    static let gardenMoodLifetime: TimeInterval = 24 * 60 * 60

    mutating func setGardenMood(_ mood: ProfileNoteMood?, selectedAt: Date = Date()) {
        gardenMood = mood
        gardenMoodSelectedAt = mood != nil ? selectedAt : nil
    }

    /// Clears garden mood when it has been active for 24 hours or lacks a selection timestamp.
    /// Returns `true` when the profile was changed.
    mutating func pruneExpiredGardenMood(now: Date = Date()) -> Bool {
        guard gardenMood != nil else { return false }
        let isExpired = gardenMoodSelectedAt.map {
            now.timeIntervalSince($0) >= Self.gardenMoodLifetime
        } ?? true
        guard isExpired else { return false }
        gardenMood = nil
        gardenMoodSelectedAt = nil
        return true
    }
}
