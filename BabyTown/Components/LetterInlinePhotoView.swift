import SwiftUI

/// Inline polaroid-style photo embedded in the letter body.
struct LetterInlinePhotoView: View {
    let image: UIImage?
    var rotation: Double
    var scale: CGFloat
    var contentWidth: CGFloat
    var isEditing: Bool
    var isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onScaleChanged: (CGFloat) -> Void
    let onRotationChanged: (Double) -> Void

    @State private var pinchBaseScale: CGFloat = LetterPhotoLayout.defaultScale
    @State private var pinchPreviewScale: CGFloat?
    @State private var rotationBase: Double = LetterPhotoLayout.defaultRotation
    @State private var rotationPreview: Double?

    private static let pinchSensitivity: CGFloat = 0.22

    private var effectiveScale: CGFloat {
        pinchPreviewScale ?? scale
    }

    private var effectiveRotation: Double {
        rotationPreview ?? rotation
    }

    private var frameWidth: CGFloat {
        min(contentWidth, LetterPhotoLayout.baseWidth) * effectiveScale
    }

    private var imageHeight: CGFloat {
        guard let image else { return frameWidth * 0.75 }
        let aspect = image.size.height / max(image.size.width, 1)
        return frameWidth * aspect
    }

    var body: some View {
        ZStack(alignment: .top) {
            polaroidContent
                .gesture(isEditing && isSelected ? customizeGestures : nil)
                .onTapGesture {
                    guard isEditing else { return }
                    onSelect()
                }

            if isEditing, isSelected {
                EditGardenTrashButton(action: onDelete)
                    .offset(y: -44)
                    .zIndex(10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .editGardenPulse(isEditing && !isSelected)
        .onAppear {
            pinchBaseScale = scale
            rotationBase = rotation
        }
        .onChange(of: scale) { _, newScale in
            pinchBaseScale = newScale
            pinchPreviewScale = nil
        }
        .onChange(of: rotation) { _, newRotation in
            rotationBase = newRotation
            rotationPreview = nil
        }
    }

    private var polaroidContent: some View {
        VStack(spacing: 0) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(BabyTownTheme.accentSoft)
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(BabyTownTheme.accent.opacity(0.45))
                }
            }
            .frame(width: frameWidth, height: imageHeight)
            .clipped()

            Rectangle()
                .fill(BabyTownTheme.backgroundCream)
                .frame(width: frameWidth, height: LetterPhotoLayout.chinHeight)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: BabyTownTheme.cardShadow, radius: 10, y: 5)
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .rotationEffect(.degrees(effectiveRotation))
        .customizeDottedOutline(isEditing && isSelected, cornerRadius: 8, padding: 6, lineWidth: 3)
        .contentShape(Rectangle())
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let proposed = pinchBaseScale * damped
                pinchPreviewScale = min(
                    max(proposed, LetterPhotoLayout.minScale),
                    LetterPhotoLayout.maxScale
                )
            }
            .onEnded { amount in
                let damped = 1 + (amount - 1) * Self.pinchSensitivity
                let final = min(
                    max(pinchBaseScale * damped, LetterPhotoLayout.minScale),
                    LetterPhotoLayout.maxScale
                )
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
        SimultaneousGesture(pinchGesture, rotationGesture)
    }
}
