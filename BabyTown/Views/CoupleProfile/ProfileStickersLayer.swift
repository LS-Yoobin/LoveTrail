import SwiftUI

/// Cutout stickers over the profile scroll canvas. Draws photo stickers plus the
/// user-avatar and partner-invite stickers; all are draggable/resizable in edit mode.
struct ProfileStickersLayer: View {
    let stickers: [ProfileSticker]
    let images: [UUID: UIImage]
    let profileNote: String?
    let profileNotePosition: NormalizedPoint?
    let userName: String
    let partnerTitle: String
    let isCustomizing: Bool
    let selectedID: UUID?
    let isNoteSelected: Bool
    let onSelect: (UUID?) -> Void
    let onSelectNote: () -> Void
    let onDelete: (UUID) -> Void
    let onDeleteNote: () -> Void
    let onTapUser: () -> Void
    let onTapPartner: () -> Void
    var onTapNote: (() -> Void)?
    var onTapPhotoSticker: ((ProfileSticker) -> Void)?
    let onNotePositionChanged: (NormalizedPoint) -> Void
    let onPositionChanged: (UUID, NormalizedPoint) -> Void
    let onScaleChanged: (UUID, CGFloat) -> Void
    let onRotationChanged: (UUID, Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Empty-canvas tap target: deselect when editing.
                if isCustomizing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(nil) }
                }

                if let profileNote {
                    ProfileGardenNoteView(
                        text: profileNote,
                        position: profileNotePosition,
                        stickers: stickers,
                        canvasSize: geo.size,
                        isCustomizing: isCustomizing,
                        isSelected: isNoteSelected,
                        onSelect: isCustomizing ? onSelectNote : nil,
                        onDelete: isCustomizing ? onDeleteNote : nil,
                        onPositionChanged: onNotePositionChanged,
                        onTap: isCustomizing ? nil : onTapNote
                    )
                }

                // Profile + partner stickers stay underneath so user-created
                // photo stickers never hide behind them.
                ForEach(profileStickers) { sticker in
                    stickerView(sticker, canvasSize: geo.size)
                }

                ForEach(photoStickers) { sticker in
                    stickerView(sticker, canvasSize: geo.size)
                }
            }
        }
        // User/partner stickers are tappable in browse mode too; individual
        // ProfileStickerViews gate their own hit-testing by kind.
        .allowsHitTesting(true)
    }

    private var profileStickers: [ProfileSticker] {
        stickers.filter { $0.kind == .userAvatar || $0.kind == .partnerInvite }
    }

    private var photoStickers: [ProfileSticker] {
        stickers.filter { $0.kind == .moment || $0.kind == .specialDate }
    }

    @ViewBuilder
    private func stickerView(_ sticker: ProfileSticker, canvasSize: CGSize) -> some View {
        ProfileStickerView(
            sticker: sticker,
            image: images[sticker.id],
            label: label(for: sticker),
            canvasSize: canvasSize,
            isCustomizing: isCustomizing,
            onTap: browseTap(for: sticker),
            isSelected: selectedID == sticker.id,
            onSelect: { onSelect(sticker.id) },
            onDelete: isDeletable(sticker) ? { onDelete(sticker.id) } : nil,
            onPositionChanged: { onPositionChanged(sticker.id, $0) },
            onScaleChanged: { onScaleChanged(sticker.id, $0) },
            onRotationChanged: sticker.kind == .moment
                ? { onRotationChanged(sticker.id, $0) }
                : nil
        )
    }

    /// Photo stickers can be removed in edit mode; profile avatars stay on the garden.
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
        case .moment, .specialDate:
            guard let onTapPhotoSticker else { return nil }
            return { onTapPhotoSticker(sticker) }
        case .pet: return nil
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
