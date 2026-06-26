import SwiftUI

/// Inline polaroid-style photo embedded in the letter body.
struct LetterInlinePhotoView: View {
    let image: UIImage?
    var rotation: Double
    var scale: CGFloat
    var contentWidth: CGFloat
    var isEditing: Bool
    var usesOverlayLayout: Bool = false
    let onDelete: () -> Void

    private var frameWidth: CGFloat {
        min(contentWidth, LetterPhotoLayout.baseWidth) * scale
    }

    private var imageHeight: CGFloat {
        guard let image else { return frameWidth * 0.75 }
        let aspect = image.size.height / max(image.size.width, 1)
        return frameWidth * aspect
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            polaroidContent

            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.45))
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .accessibilityLabel("Remove photo")
            }
        }
        .frame(maxWidth: usesOverlayLayout ? nil : .infinity)
        .padding(.vertical, usesOverlayLayout ? 0 : 8)
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
        .rotationEffect(.degrees(rotation))
    }
}
