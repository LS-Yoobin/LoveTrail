import SwiftUI

/// Polaroid photos placed on a letter card. Supports drag, pinch-resize, and rotation in edit mode.
struct LetterPhotosOverlay: View {
    let photoBlocks: [LetterBlock]
    let images: [UUID: UIImage]
    let contentWidth: CGFloat
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
        LetterCanvasSizeReader { canvasSize in
            ZStack {
                ForEach(photoBlocks) { block in
                    LetterPositionedPhotoView(
                        block: block,
                        image: images[block.id],
                        contentWidth: contentWidth,
                        canvasSize: canvasSize,
                        isEditing: isEditing,
                        isSelected: selectedID == block.id,
                        dragBounds: Self.dragBounds,
                        onSelect: { selectedID = block.id },
                        onDelete: { onDelete(block.id) },
                        onPositionChanged: { onPositionChanged(block.id, $0) },
                        onScaleChanged: { onScaleChanged(block.id, $0) },
                        onRotationChanged: { onRotationChanged(block.id, $0) }
                    )
                    .zIndex(selectedID == block.id ? 25 : 1)
                }

                if isEditing, let selectedID,
                   let block = photoBlocks.first(where: { $0.id == selectedID }),
                   let position = block.photoPosition {
                    let center = CGPoint(
                        x: position.x * canvasSize.width,
                        y: position.y * canvasSize.height
                    )
                    let photoHeight = LetterPhotoLayout.polaroidHeight(
                        for: images[selectedID],
                        contentWidth: contentWidth,
                        scale: block.photoScale ?? LetterPhotoLayout.defaultScale
                    )
                    EditGardenTrashButton(action: { onDelete(selectedID) })
                        .position(x: center.x, y: center.y - photoHeight / 2 - 44)
                        .zIndex(50)
                }
            }
        }
    }
}

// MARK: - Positioned Photo

private struct LetterPositionedPhotoView: View {
    let block: LetterBlock
    let image: UIImage?
    let contentWidth: CGFloat
    let canvasSize: CGSize
    let isEditing: Bool
    let isSelected: Bool
    let dragBounds: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onPositionChanged: (NormalizedPoint) -> Void
    let onScaleChanged: (CGFloat) -> Void
    let onRotationChanged: (Double) -> Void

    @State private var dragOrigin: NormalizedPoint?
    @State private var pinchBaseScale: CGFloat = 1
    @State private var pinchPreviewScale: CGFloat?
    @State private var rotationBase: Double = 0
    @State private var rotationPreview: Double?

    private static let pinchSensitivity: CGFloat = 0.22

    private var position: NormalizedPoint {
        block.photoPosition ?? NormalizedPoint(x: 0.5, y: 0.65)
    }

    private var effectiveScale: CGFloat {
        pinchPreviewScale ?? block.photoScale ?? LetterPhotoLayout.defaultScale
    }

    private var effectiveRotation: Double {
        rotationPreview ?? block.photoRotation ?? LetterPhotoLayout.defaultRotation
    }

    private var shouldPulse: Bool { isEditing && !isSelected }

    var body: some View {
        let center = CGPoint(
            x: position.x * canvasSize.width,
            y: position.y * canvasSize.height
        )

        LetterInlinePhotoView(
            image: image,
            rotation: effectiveRotation,
            scale: effectiveScale,
            contentWidth: contentWidth,
            isEditing: false,
            usesOverlayLayout: true,
            onDelete: onDelete
        )
        .contentShape(Rectangle())
        .customizeDottedOutline(isEditing && isSelected, cornerRadius: 8, padding: 4, lineWidth: 3)
        .editGardenPulse(shouldPulse)
        .position(x: center.x, y: center.y)
        .onAppear {
            pinchBaseScale = block.photoScale ?? LetterPhotoLayout.defaultScale
            rotationBase = block.photoRotation ?? LetterPhotoLayout.defaultRotation
        }
        .onChange(of: block.photoScale) { _, newScale in
            pinchBaseScale = newScale ?? LetterPhotoLayout.defaultScale
            pinchPreviewScale = nil
        }
        .onChange(of: block.photoRotation) { _, newRotation in
            rotationBase = newRotation ?? LetterPhotoLayout.defaultRotation
            rotationPreview = nil
        }
        .gesture(isEditing && isSelected ? customizeGestures : nil)
        .onTapGesture {
            if isEditing {
                onSelect()
            }
        }
        .allowsHitTesting(isEditing)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = position
                }
                let origin = dragOrigin ?? position
                let limits = dragBounds
                let nx = min(max(origin.x + value.translation.width / canvasSize.width, limits.minX), limits.maxX)
                let ny = min(max(origin.y + value.translation.height / canvasSize.height, limits.minY), limits.maxY)
                onPositionChanged(NormalizedPoint(x: nx, y: ny))
            }
            .onEnded { _ in
                dragOrigin = nil
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let proposed = pinchBaseScale * damped
                pinchPreviewScale = min(max(proposed, LetterPhotoLayout.minScale), LetterPhotoLayout.maxScale)
            }
            .onEnded { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let final = min(max(pinchBaseScale * damped, LetterPhotoLayout.minScale), LetterPhotoLayout.maxScale)
                pinchBaseScale = final
                pinchPreviewScale = nil
                onScaleChanged(final)
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                rotationPreview = rotationBase + angle.degrees
            }
            .onEnded { angle in
                let final = rotationBase + angle.degrees
                rotationBase = final
                rotationPreview = nil
                onRotationChanged(final)
            }
    }

    private var customizeGestures: some Gesture {
        SimultaneousGesture(
            dragGesture,
            SimultaneousGesture(pinchGesture, rotationGesture)
        )
    }
}

// MARK: - Layout Helpers

extension LetterPhotoLayout {
    static func polaroidHeight(for image: UIImage?, contentWidth: CGFloat, scale: CGFloat) -> CGFloat {
        let frameWidth = min(contentWidth, baseWidth) * scale
        guard let image else { return frameWidth * 0.75 + chinHeight }
        let aspect = image.size.height / max(image.size.width, 1)
        return frameWidth * aspect + chinHeight
    }
}
