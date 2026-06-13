import SwiftUI

/// Watch Together TV placed on the garden scroll canvas; draggable/scalable in Edit Garden mode.
struct ProfileGardenWatchTogetherTVView: View {
    let position: NormalizedPoint?
    let scale: CGFloat?
    let canvasSize: CGSize
    let isCustomizing: Bool
    var isSelected: Bool = false
    let onPositionChanged: (NormalizedPoint) -> Void
    let onScaleChanged: (CGFloat) -> Void
    var onSelect: (() -> Void)?
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)? = nil

    @State private var dragOrigin: NormalizedPoint?
    @State private var pinchBaseScale: CGFloat = WatchTogetherTVView.gardenDefaultScale
    @State private var pinchPreviewScale: CGFloat?

    private static let pinchSensitivity: CGFloat = 0.22

    private var shouldPulse: Bool { isCustomizing && !isSelected }

    private var resolvedPosition: NormalizedPoint {
        position ?? ProfileGardenLayout.defaultWatchTogetherTVPosition(canvasSize: canvasSize)
    }

    private var resolvedScale: CGFloat {
        max(
            scale ?? WatchTogetherTVView.gardenDefaultScale,
            WatchTogetherTVView.gardenMinScale
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
        WatchTogetherTVView(
            state: .idle,
            scale: effectiveScale,
            onTap: isCustomizing ? nil : onTap,
            onLongPress: isCustomizing ? nil : onLongPress
        )
        .customizeDottedOutline(isCustomizing && isSelected, cornerRadius: 14, padding: 4)
        .editGardenPulse(shouldPulse)
        .position(center)
        .gesture(isCustomizing && isSelected ? customizeGestures : nil)
        .onTapGesture {
            if isCustomizing { onSelect?() }
        }
        .onAppear { pinchBaseScale = resolvedScale }
        .onChange(of: scale) { _, newScale in
            pinchBaseScale = max(
                newScale ?? WatchTogetherTVView.gardenDefaultScale,
                WatchTogetherTVView.gardenMinScale
            )
            pinchPreviewScale = nil
        }
        .zIndex(20)
    }

    private var scaleLimits: (min: CGFloat, max: CGFloat) {
        (WatchTogetherTVView.gardenMinScale, WatchTogetherTVView.gardenMaxScale)
    }

    private var dragLimits: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        (minX: 0.06, maxX: 0.94, minY: 0.06, maxY: 0.94)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOrigin == nil { dragOrigin = resolvedPosition }
                let origin = dragOrigin ?? resolvedPosition
                let lim = dragLimits
                let nx = min(max(origin.x + value.translation.width  / canvasSize.width,  lim.minX), lim.maxX)
                let ny = min(max(origin.y + value.translation.height / canvasSize.height, lim.minY), lim.maxY)
                onPositionChanged(NormalizedPoint(x: nx, y: ny))
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let proposed = pinchBaseScale * damped
                let lim = scaleLimits
                pinchPreviewScale = min(max(proposed, lim.min), lim.max)
            }
            .onEnded { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let lim = scaleLimits
                let final = min(max(pinchBaseScale * damped, lim.min), lim.max)
                pinchBaseScale = final
                pinchPreviewScale = nil
                onScaleChanged(final)
            }
    }

    private var customizeGestures: some Gesture {
        SimultaneousGesture(dragGesture, pinchGesture)
    }
}
