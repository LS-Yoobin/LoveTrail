import SwiftUI

/// Cutout stickers over the profile scroll canvas. Draws photo stickers plus the
/// user-avatar and partner-invite stickers; all are draggable/resizable in edit mode.
struct ProfileStickersLayer: View {
    let stickers: [ProfileSticker]
    let images: [UUID: UIImage]
    let userName: String
    let partnerTitle: String
    let isCustomizing: Bool
    let selectedID: UUID?
    let onSelect: (UUID?) -> Void
    let onDelete: (UUID) -> Void
    let onTapUser: () -> Void
    let onTapPartner: () -> Void
    let onPositionChanged: (UUID, NormalizedPoint) -> Void
    let onScaleChanged: (UUID, CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Empty-canvas tap target: deselect when editing.
                if isCustomizing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(nil) }
                }

                ForEach(visibleStickers) { sticker in
                    ProfileStickerView(
                        sticker: sticker,
                        image: images[sticker.id],
                        label: label(for: sticker),
                        canvasSize: geo.size,
                        isCustomizing: isCustomizing,
                        onTap: browseTap(for: sticker),
                        isSelected: selectedID == sticker.id,
                        onSelect: { onSelect(sticker.id) },
                        onDelete: isDeletable(sticker) ? { onDelete(sticker.id) } : nil,
                        onPositionChanged: { onPositionChanged(sticker.id, $0) },
                        onScaleChanged: { onScaleChanged(sticker.id, $0) }
                    )
                }
            }
        }
        // User/partner stickers are tappable in browse mode too; individual
        // ProfileStickerViews gate their own hit-testing by kind.
        .allowsHitTesting(true)
    }

    private var visibleStickers: [ProfileSticker] {
        stickers.filter { sticker in
            switch sticker.kind {
            case .moment, .specialDate, .userAvatar, .partnerInvite:
                return true
            case .pet:
                return false
            }
        }
    }

    /// Photo stickers can be deleted; avatar + partner are persistent (re-synced).
    private func isDeletable(_ sticker: ProfileSticker) -> Bool {
        switch sticker.kind {
        case .moment, .specialDate: return true
        case .userAvatar, .partnerInvite, .pet: return false
        }
    }

    private func browseTap(for sticker: ProfileSticker) -> (() -> Void)? {
        switch sticker.kind {
        case .userAvatar: return onTapUser
        case .partnerInvite: return onTapPartner
        case .moment, .specialDate, .pet: return nil
        }
    }

    private func label(for sticker: ProfileSticker) -> String? {
        switch sticker.kind {
        case .userAvatar:
            if images[sticker.id] == nil { return "Profile Photo" }
            return userName.isEmpty ? "You" : userName
        case .partnerInvite:
            return partnerTitle
        case .moment, .specialDate, .pet:
            return nil
        }
    }
}
