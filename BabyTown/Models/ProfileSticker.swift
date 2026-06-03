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

    /// Default rendered size multiplier for new stickers on the profile canvas.
    static let defaultScale: CGFloat = 1
    /// Freshly created photo stickers spawn ~20% larger than the base size.
    static let newStickerScale: CGFloat = 1.2
    /// Base cutout size — matches the profile header slots in browse mode.
    static let cutoutBaseSize: CGFloat = 84

    /// Default normalized position for a freshly synced partner-invite sticker
    /// (garden band directly below the profile cards).
    static let defaultPartnerPosition = NormalizedPoint(x: 0.68, y: 0.46)
    /// Default normalized position for a freshly synced user-avatar sticker.
    static let defaultUserAvatarPosition = NormalizedPoint(x: 0.32, y: 0.46)

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
