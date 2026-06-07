import SwiftUI

/// Cutout stickers over the profile scroll canvas. Draws photo stickers plus the
/// user-avatar and partner-invite stickers; all are draggable/resizable in edit mode.
struct ProfileStickersLayer: View {
    let stickers: [ProfileSticker]
    let images: [UUID: UIImage]
    let profileNote: String?
    let profileNotePosition: NormalizedPoint?
    let recordPlayerPosition: NormalizedPoint?
    let recordPlayerScale: CGFloat?
    let isRecordPlayerPlaying: Bool
    let userName: String
    let partnerTitle: String
    let isCustomizing: Bool
    let selectedID: UUID?
    let isNoteSelected: Bool
    var isRecordPlayerSelected: Bool = false
    let onSelect: (UUID?) -> Void
    let onSelectNote: () -> Void
    var onSelectRecordPlayer: (() -> Void)?
    let onDelete: (UUID) -> Void
    let onDeleteNote: () -> Void
    let onTapUser: () -> Void
    let onTapPartner: () -> Void
    var onTapNote: (() -> Void)?
    var onTapRecordPlayer: (() -> Void)?
    var onTapPhotoSticker: ((ProfileSticker) -> Void)?
    let onNotePositionChanged: (NormalizedPoint) -> Void
    let onRecordPlayerPositionChanged: (NormalizedPoint) -> Void
    let onRecordPlayerScaleChanged: (CGFloat) -> Void
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

                // Profile + partner stickers stay underneath so user-created
                // photo stickers never hide behind them.
                ForEach(profileStickers) { sticker in
                    stickerView(sticker, canvasSize: geo.size)
                        .zIndex(stickerZIndex(for: sticker.id))
                }

                ForEach(photoStickers) { sticker in
                    stickerView(sticker, canvasSize: geo.size)
                        .zIndex(stickerZIndex(for: sticker.id))
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
                        showsDeleteButton: false,
                        onPositionChanged: onNotePositionChanged,
                        onTap: isCustomizing ? nil : onTapNote
                    )
                    .zIndex(noteZIndex)
                }

                ProfileGardenRecordPlayerView(
                    position: recordPlayerPosition,
                    scale: recordPlayerScale,
                    canvasSize: geo.size,
                    isCustomizing: isCustomizing,
                    isSelected: isRecordPlayerSelected,
                    isPlaying: isRecordPlayerPlaying,
                    onPositionChanged: onRecordPlayerPositionChanged,
                    onScaleChanged: onRecordPlayerScaleChanged,
                    onSelect: onSelectRecordPlayer,
                    onTap: isCustomizing ? nil : onTapRecordPlayer
                )
                .zIndex(recordPlayerZIndex)

                if isCustomizing {
                    editGardenDeleteButtons(canvasSize: geo.size)
                        .zIndex(30)
                }
            }
        }
        // User/partner stickers are tappable in browse mode too; individual
        // ProfileStickerViews gate their own hit-testing by kind.
        .allowsHitTesting(true)
    }

    private var noteZIndex: Double {
        if isNoteSelected { return 25 }
        return isCustomizing ? 10 : 0
    }

    private var recordPlayerZIndex: Double {
        isRecordPlayerSelected ? 25 : 20
    }

    private func stickerZIndex(for id: UUID) -> Double {
        selectedID == id ? 25 : 1
    }

    private static let trashLift: CGFloat = 44

    @ViewBuilder
    private func editGardenDeleteButtons(canvasSize: CGSize) -> some View {
        if isNoteSelected, profileNote != nil {
            let noteWidth = ProfileGardenNoteLayout.noteWidth(for: canvasSize.width)
            let noteHeight = ProfileGardenNoteLayout.noteHeight(for: noteWidth)
            let fallback = ProfileGardenNoteLayout.defaultPosition(
                stickers: stickers,
                canvasSize: canvasSize
            )
            let center = resolvedCenter(
                normalized: profileNotePosition,
                fallback: fallback,
                canvasSize: canvasSize
            )
            EditGardenTrashButton(action: onDeleteNote)
                .position(x: center.x, y: center.y - noteHeight / 2 - Self.trashLift)
        } else if let selectedID,
                  let sticker = stickers.first(where: { $0.id == selectedID }),
                  isDeletable(sticker) {
            let center = CGPoint(
                x: CGFloat(sticker.position.x) * canvasSize.width,
                y: CGFloat(sticker.position.y) * canvasSize.height
            )
            let contentHeight = stickerContentHeight(sticker)
            EditGardenTrashButton(action: { onDelete(selectedID) })
                .position(x: center.x, y: center.y - contentHeight / 2 - Self.trashLift)
        }
    }

    private func resolvedCenter(
        normalized: NormalizedPoint?,
        fallback: NormalizedPoint,
        canvasSize: CGSize
    ) -> CGPoint {
        let point = normalized ?? fallback
        return CGPoint(
            x: CGFloat(point.x) * canvasSize.width,
            y: CGFloat(point.y) * canvasSize.height
        )
    }

    private func stickerContentHeight(_ sticker: ProfileSticker) -> CGFloat {
        let side = ProfileSticker.renderedSize(scale: sticker.scale)
        let labelBlock: CGFloat = (
            sticker.kind == .userAvatar || sticker.kind == .partnerInvite
        ) ? 46 : 0
        return side + labelBlock
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
            showsDeleteButton: false,
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
