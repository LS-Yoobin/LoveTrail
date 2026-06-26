import SwiftUI

/// Photo stickers placed on a letter card. Supports drag, pinch-resize, and rotation in edit mode.
struct LetterStickersOverlay: View {
    let stickerBlocks: [LetterBlock]
    let images: [UUID: UIImage]
    var isEditing: Bool
    @Binding var selectedID: UUID?
    let onPositionChanged: (UUID, NormalizedPoint) -> Void
    let onScaleChanged: (UUID, CGFloat) -> Void
    let onRotationChanged: (UUID, Double) -> Void
    let onDelete: (UUID) -> Void
    var onBackgroundTap: (() -> Void)? = nil

    private static let dragBounds = (
        minX: CGFloat(0.08),
        maxX: CGFloat(0.92),
        minY: CGFloat(0.22),
        maxY: CGFloat(0.92)
    )

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isEditing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedID = nil
                            onBackgroundTap?()
                        }
                }

                ForEach(stickerBlocks) { block in
                    stickerView(for: block, canvasSize: geo.size)
                        .zIndex(selectedID == block.id ? 25 : 1)
                }

                if isEditing, let selectedID,
                   stickerBlocks.contains(where: { $0.id == selectedID }) {
                    deleteButton(for: selectedID, canvasSize: geo.size)
                        .zIndex(50)
                }
            }
        }
        .allowsHitTesting(isEditing)
    }

    @ViewBuilder
    private func stickerView(for block: LetterBlock, canvasSize: CGSize) -> some View {
        let sticker = block.profileSticker()
        ProfileStickerView(
            sticker: sticker,
            image: images[block.id],
            label: nil,
            canvasSize: canvasSize,
            isCustomizing: isEditing,
            isSelected: selectedID == block.id,
            showsArrangementChrome: isEditing,
            dragBounds: Self.dragBounds,
            onSelect: { selectedID = block.id },
            onDelete: { onDelete(block.id) },
            showsDeleteButton: false,
            onPositionChanged: { onPositionChanged(block.id, $0) },
            onScaleChanged: { onScaleChanged(block.id, $0) },
            onRotationChanged: { onRotationChanged(block.id, $0) }
        )
    }

    @ViewBuilder
    private func deleteButton(for id: UUID, canvasSize: CGSize) -> some View {
        if let block = stickerBlocks.first(where: { $0.id == id }),
           let position = block.stickerPosition {
            let center = CGPoint(
                x: position.x * canvasSize.width,
                y: position.y * canvasSize.height
            )
            let side = ProfileSticker.renderedSize(
                scale: block.stickerScale ?? LetterPhotoLayout.defaultStickerScale
            )
            EditGardenTrashButton(action: { onDelete(id) })
                .position(x: center.x, y: center.y - side / 2 - 44)
                .allowsHitTesting(true)
        }
    }
}
