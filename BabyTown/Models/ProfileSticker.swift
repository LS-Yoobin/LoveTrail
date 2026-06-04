import Foundation

/// A draggable photo cutout on the Couples Profile Page (user avatar, special-date
/// photo, or adopted pet portrait). Position is normalized 0…1 over the page.
struct ProfileSticker: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case userAvatar
        case partnerInvite
        case specialDate
        case pet
        case moment
    }

    let id: UUID
    var kind: Kind
    /// Stable link to the source: `"userAvatar"`, `"pet"`, or a special-date UUID string.
    var sourceKey: String
    var position: NormalizedPoint
    /// Rotation in degrees for a scrapbook feel.
    var rotation: Double
    var scale: CGFloat
    var usedSubjectLift: Bool

    /// Base cutout size — matches the profile header slots in browse mode.
    static let cutoutBaseSize: CGFloat = 84

    /// User + partner profile stickers on the secret garden canvas.
    static let profileAvatarScale: CGFloat = 1.6
    static let profileAvatarMinScale: CGFloat = 1.0
    static let profileAvatarMaxScale: CGFloat = 5.5

    /// Photo cutouts (moment / special date) on the garden and memory pages.
    static let photoStickerDefaultScale: CGFloat = 1.5
    static let photoStickerMinScale: CGFloat = 0.8
    static let photoStickerMaxScale: CGFloat = 5.5

    /// Default rendered size multiplier for profile avatar stickers.
    static let defaultScale: CGFloat = profileAvatarScale
    /// Freshly created garden photo stickers.
    static let newStickerScale: CGFloat = photoStickerDefaultScale
    /// Full moment page stickers spawn larger than the garden default.
    static let memoryPageNewStickerScale: CGFloat = photoStickerDefaultScale * 1.5

    static func scaleLimits(for kind: Kind) -> (min: CGFloat, max: CGFloat) {
        switch kind {
        case .userAvatar, .partnerInvite:
            return (profileAvatarMinScale, profileAvatarMaxScale)
        case .moment, .specialDate, .pet:
            return (photoStickerMinScale, photoStickerMaxScale)
        }
    }

    /// Default normalized position for partner-invite sticker — garden band below
    /// the three profile cards (`ProfileGardenLayout.profileSlotNormalizedY`).
    static let defaultPartnerPosition = NormalizedPoint(x: 0.68, y: ProfileGardenLayout.profileSlotNormalizedY)
    /// Default normalized position for user-avatar sticker.
    static let defaultUserAvatarPosition = NormalizedPoint(x: 0.32, y: ProfileGardenLayout.profileSlotNormalizedY)

    /// Side length on screen for a sticker at the given scale.
    static func renderedSize(scale: CGFloat) -> CGFloat {
        cutoutBaseSize * scale
    }

    init(
        id: UUID = UUID(),
        kind: Kind,
        sourceKey: String,
        position: NormalizedPoint,
        rotation: Double = 0,
        scale: CGFloat = 1,
        usedSubjectLift: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.sourceKey = sourceKey
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.usedSubjectLift = usedSubjectLift
    }
}
