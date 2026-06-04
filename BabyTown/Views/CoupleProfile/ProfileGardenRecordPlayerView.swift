import SwiftUI

/// Vinyl record player on the garden scroll canvas; draggable in Edit Garden mode.
struct ProfileGardenRecordPlayerView: View {
    let position: NormalizedPoint?
    let scale: CGFloat?
    let canvasSize: CGSize
    let isCustomizing: Bool
    let isPlaying: Bool
    let onPositionChanged: (NormalizedPoint) -> Void
    let onScaleChanged: (CGFloat) -> Void
    var onTap: (() -> Void)?

    @State private var dragOrigin: NormalizedPoint?
    @State private var pinchBaseScale: CGFloat = VinylRecordPlayerView.gardenDefaultScale
    @State private var pinchPreviewScale: CGFloat?

    /// Lower = finer pinch control (matches `ProfileStickerView`).
    private static let pinchSensitivity: CGFloat = 0.22

    private var resolvedPosition: NormalizedPoint {
        position ?? ProfileGardenLayout.defaultRecordPlayerPosition(canvasSize: canvasSize)
    }

    private var resolvedScale: CGFloat {
        max(
            scale ?? VinylRecordPlayerView.gardenDefaultScale,
            VinylRecordPlayerView.gardenMinScale
        )
    }

    private var effectiveScale: CGFloat {
        pinchPreviewScale ?? resolvedScale
    }

    private var center: CGPoint {
        CGPoint(
            x: resolvedPosition.x * canvasSize.width,
            y: resolvedPosition.y * canvasSize.height
        )
    }

    var body: some View {
        VinylRecordPlayerView(isPlaying: isPlaying, scale: effectiveScale, onTap: isCustomizing ? nil : onTap)
            .customizeDottedOutline(isCustomizing, cornerRadius: 14, padding: 4)
            .position(center)
            .gesture(isCustomizing ? customizeGestures : nil)
            .onAppear { pinchBaseScale = resolvedScale }
            .onChange(of: scale) { _, newScale in
                pinchBaseScale = max(
                    newScale ?? VinylRecordPlayerView.gardenDefaultScale,
                    VinylRecordPlayerView.gardenMinScale
                )
                pinchPreviewScale = nil
            }
            .zIndex(20)
    }

    private var scaleLimits: (min: CGFloat, max: CGFloat) {
        (VinylRecordPlayerView.gardenMinScale, VinylRecordPlayerView.gardenMaxScale)
    }

    private var dragLimits: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        (minX: 0.06, maxX: 0.94, minY: 0.06, maxY: 0.94)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = resolvedPosition
                }
                let origin = dragOrigin ?? resolvedPosition
                let limits = dragLimits
                let nx = min(
                    max(origin.x + value.translation.width / canvasSize.width, limits.minX),
                    limits.maxX
                )
                let ny = min(
                    max(origin.y + value.translation.height / canvasSize.height, limits.minY),
                    limits.maxY
                )
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
                let limits = scaleLimits
                pinchPreviewScale = min(max(proposed, limits.min), limits.max)
            }
            .onEnded { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let limits = scaleLimits
                let final = min(max(pinchBaseScale * damped, limits.min), limits.max)
                pinchBaseScale = final
                pinchPreviewScale = nil
                onScaleChanged(final)
            }
    }

    private var customizeGestures: some Gesture {
        SimultaneousGesture(dragGesture, pinchGesture)
    }
}
