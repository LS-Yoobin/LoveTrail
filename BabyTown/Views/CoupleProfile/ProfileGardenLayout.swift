import CoreGraphics

/// Shared scroll/sticker layout math for the Secret Garden profile page.
enum ProfileGardenLayout {
    /// Top inset for scroll content — matches horizontal card padding (16).
    static let contentTopPadding: CGFloat = 16
    /// Gap between the card stack and the profile-avatar band.
    static let avatarBandTopGap: CGFloat = 5
    /// Vertical band where user + partner stickers sit in browse mode.
    static let avatarBandHeight: CGFloat = 168
    /// Open canvas below the avatar band for photo stickers.
    static let stickerCanvasHeight: CGFloat = 760

    /// Typical height of Our History + Important Dates + Pinned Memories preview.
    static let estimatedCardsHeight: CGFloat = 700

    /// Default vinyl player center — lower-right of the card stack, above the
    /// user / invite-partner avatar band (`profileSlotNormalizedY`).
    static func defaultRecordPlayerPosition(canvasSize: CGSize) -> NormalizedPoint {
        let totalH = max(
            canvasSize.height,
            contentTopPadding
                + estimatedCardsHeight
                + avatarBandTopGap
                + avatarBandHeight
                + stickerCanvasHeight
        )
        let avatarBandTopY = contentTopPadding + estimatedCardsHeight + avatarBandTopGap
        let recordHalfHeight: CGFloat = 44
        let gapAboveAvatars: CGFloat = 32
        let centerY = avatarBandTopY - gapAboveAvatars - recordHalfHeight
        return NormalizedPoint(
            x: 0.86,
            y: min(profileSlotNormalizedY - 0.06, max(0.10, centerY / totalH))
        )
    }

    /// Normalized Y for default user/partner sticker centers (0…1 over full scroll content).
    static var profileSlotNormalizedY: CGFloat {
        let total = contentTopPadding
            + estimatedCardsHeight
            + avatarBandTopGap
            + avatarBandHeight
            + stickerCanvasHeight
        let centerY = contentTopPadding
            + estimatedCardsHeight
            + avatarBandTopGap
            + avatarBandHeight * 0.45
        return centerY / total
    }
}
