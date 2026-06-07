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
    var showsArrangementChrome: Bool? = nil
    var dragBounds: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)? = nil
    var onSelect: (() -> Void)?
    var onDelete: (() -> Void)?
    var showsDeleteButton: Bool = true
    let onPositionChanged: (NormalizedPoint) -> Void
    let onScaleChanged: (CGFloat) -> Void
    var onDragEnded: (() -> Void)? = nil
    var onDragActiveChanged: ((Bool) -> Void)? = nil
    /// Set for garden moment stickers only; profile avatars omit this.
    var onRotationChanged: ((Double) -> Void)?

    @State private var dragOrigin: NormalizedPoint?
    @State private var pinchBaseScale: CGFloat = 1
    @State private var pinchPreviewScale: CGFloat?
    @State private var rotationBase: Double = 0
    @State private var rotationPreview: Double?
    /// Matches `PetRoomScene.highlightDraggable` — gentle alpha pulse in edit mode.
    private var shouldPulse: Bool { showChrome && !isSelected }

    /// Lower = finer pinch control (0.25 ≈ quarter of native sensitivity).
    private static let pinchSensitivity: CGFloat = 0.22

    private var scaleLimits: (min: CGFloat, max: CGFloat) {
        ProfileSticker.scaleLimits(for: sticker.kind)
    }

    private var effectiveScale: CGFloat {
        pinchPreviewScale ?? sticker.scale
    }

    private var effectiveRotation: Double {
        rotationPreview ?? sticker.rotation
    }

    private var canRotate: Bool {
        onRotationChanged != nil
    }

    private var showChrome: Bool { showsArrangementChrome ?? isCustomizing }

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
            if showsDeleteButton, showChrome, isSelected, let onDelete {
                EditGardenTrashButton(action: onDelete)
                    .offset(y: -44)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .editGardenPulse(shouldPulse)
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
        // Only the selected sticker is draggable/resizable/rotatable so overlapping
        // stickers don't fight over the same gesture. Tapping an unselected sticker
        // selects it first; the gesture bundle arms on the next interaction.
        .gesture(isCustomizing && isSelected ? customizeGestures : nil)
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
        .customizeDottedOutline(showChrome && isSelected, cornerRadius: 4, padding: 0, lineWidth: 3)
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

    private var dragLimits: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        dragBounds ?? (minX: 0.06, maxX: 0.94, minY: 0.10, maxY: 0.92)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = sticker.position
                    onDragActiveChanged?(true)
                }
                let origin = dragOrigin ?? sticker.position
                let limits = dragLimits
                let nx = min(max(origin.x + value.translation.width / canvasSize.width, limits.minX), limits.maxX)
                let ny = min(max(origin.y + value.translation.height / canvasSize.height, limits.minY), limits.maxY)
                onPositionChanged(NormalizedPoint(x: nx, y: ny))
            }
            .onEnded { _ in
                dragOrigin = nil
                onDragActiveChanged?(false)
                onDragEnded?()
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
