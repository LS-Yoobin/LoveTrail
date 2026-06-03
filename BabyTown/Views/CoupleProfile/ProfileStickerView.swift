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
    /// Set for garden moment stickers only; profile avatars omit this.
    var onRotationChanged: ((Double) -> Void)?

    @State private var dragOrigin: NormalizedPoint?
    @State private var pinchBaseScale: CGFloat = 1
    @State private var pinchPreviewScale: CGFloat?
    @State private var rotationBase: Double = 0
    @State private var rotationPreview: Double?

    private static let minScale: CGFloat = 0.5
    private static let maxScale: CGFloat = 4.0
    /// Lower = finer pinch control (0.25 ≈ quarter of native sensitivity).
    private static let pinchSensitivity: CGFloat = 0.22

    private var effectiveScale: CGFloat {
        pinchPreviewScale ?? sticker.scale
    }

    private var effectiveRotation: Double {
        rotationPreview ?? sticker.rotation
    }

    private var canRotate: Bool {
        onRotationChanged != nil
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
        .rotationEffect(.degrees(effectiveRotation))
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
        .onAppear {
            pinchBaseScale = sticker.scale
            rotationBase = sticker.rotation
        }
        .onChange(of: sticker.scale) { _, newScale in
            pinchBaseScale = newScale
            pinchPreviewScale = nil
        }
        .onChange(of: sticker.rotation) { _, newRotation in
            rotationBase = newRotation
            rotationPreview = nil
        }
        .gesture(isCustomizing ? customizeGestures : nil)
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
        profileSlotPlaceholder(side: side, systemImage: "person.crop.circle.badge.plus")
    }

    private func partnerInviteBody(side: CGFloat) -> some View {
        profileSlotPlaceholder(side: side, systemImage: "heart.circle")
    }

    /// Matches the invite-partner circle: same diameter, dashed ring, and icon scale.
    private static let emptyAvatarFill = Color(red: 0.36, green: 0.56, blue: 0.90)

    private func profileSlotPlaceholder(side: CGFloat, systemImage: String) -> some View {
        ZStack {
            Circle().fill(Self.emptyAvatarFill)
            Circle().strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.white.opacity(0.7))
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(width: side, height: side)
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

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                guard canRotate else { return }
                rotationPreview = rotationBase + angle.degrees
            }
            .onEnded { angle in
                guard canRotate else { return }
                let final = rotationBase + angle.degrees
                rotationBase = final
                rotationPreview = nil
                onRotationChanged?(final)
            }
    }

    /// A single concrete gesture type (required by `some Gesture`); rotation is
    /// gated inside `rotationGesture` via `canRotate`.
    private var customizeGestures: some Gesture {
        SimultaneousGesture(
            dragGesture,
            SimultaneousGesture(pinchGesture, rotationGesture)
        )
    }
}
