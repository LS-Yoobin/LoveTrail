import SwiftUI

/// One cutout sticker plus an optional name pill; drags and pinches as a single unit.
struct ProfileStickerView: View {
    let sticker: ProfileSticker
    let image: UIImage?
    let label: String?
    let canvasSize: CGSize
    let isCustomizing: Bool
    var onTap: (() -> Void)?
    let isSelected: Bool
    var onSelect: (() -> Void)?
    var onDelete: (() -> Void)?
    let onPositionChanged: (NormalizedPoint) -> Void
    let onScaleChanged: (CGFloat) -> Void

    @State private var dragOrigin: NormalizedPoint?
    @State private var pinchBaseScale: CGFloat = 1
    @State private var pinchPreviewScale: CGFloat?

    private static let minScale: CGFloat = 0.5
    private static let maxScale: CGFloat = 4.0
    /// Lower = finer pinch control (0.25 ≈ quarter of native sensitivity).
    private static let pinchSensitivity: CGFloat = 0.22

    private var effectiveScale: CGFloat {
        pinchPreviewScale ?? sticker.scale
    }

    var body: some View {
        let side = ProfileSticker.renderedSize(scale: effectiveScale)
        let center = CGPoint(
            x: sticker.position.x * canvasSize.width,
            y: sticker.position.y * canvasSize.height
        )

        VStack(spacing: 8) {
            stickerBody(side: side)

            if let label {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black, in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .rotationEffect(.degrees(sticker.rotation))
        .overlay(alignment: .top) {
            if isCustomizing, isSelected, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.red, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .offset(y: -44)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .position(center)
        .allowsHitTesting(isCustomizing || onTap != nil)
        .onAppear { pinchBaseScale = sticker.scale }
        .onChange(of: sticker.scale) { _, newScale in
            pinchBaseScale = newScale
            pinchPreviewScale = nil
        }
        .gesture(
            isCustomizing
                ? SimultaneousGesture(dragGesture, pinchGesture)
                : nil
        )
        .onTapGesture {
            if isCustomizing {
                onSelect?()
            } else {
                onTap?()
            }
        }
    }

    @ViewBuilder
    private func stickerBody(side: CGFloat) -> some View {
        Group {
            switch sticker.kind {
            case .partnerInvite:
                partnerInviteBody(side: side)
            case .userAvatar where image == nil:
                userAvatarPlaceholderBody(side: side)
            default:
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
        }
        .frame(width: side, height: side)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        .overlay {
            if isCustomizing {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        Color.white,
                        style: StrokeStyle(
                            lineWidth: isSelected ? 3 : 2,
                            dash: isSelected ? [] : [6, 4]
                        )
                    )
            }
        }
    }

    private func userAvatarPlaceholderBody(side: CGFloat) -> some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: side * 0.52))
                .foregroundStyle(.white.opacity(0.85))
        }
        .overlay(Circle().stroke(.white, lineWidth: 3))
    }

    private func partnerInviteBody(side: CGFloat) -> some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.white.opacity(0.7))
            Image(systemName: "heart.circle")
                .font(.title)
                .foregroundStyle(.white.opacity(0.85))
        }
        .overlay(Circle().stroke(.white, lineWidth: 3))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let origin = dragOrigin ?? sticker.position
                if dragOrigin == nil { dragOrigin = sticker.position }
                let nx = min(max(origin.x + value.translation.width / canvasSize.width, 0.06), 0.94)
                let ny = min(max(origin.y + value.translation.height / canvasSize.height, 0.10), 0.92)
                onPositionChanged(NormalizedPoint(x: nx, y: ny))
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let proposed = pinchBaseScale * damped
                pinchPreviewScale = min(max(proposed, Self.minScale), Self.maxScale)
            }
            .onEnded { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let final = min(max(pinchBaseScale * damped, Self.minScale), Self.maxScale)
                pinchBaseScale = final
                pinchPreviewScale = nil
                onScaleChanged(final)
            }
    }
}
