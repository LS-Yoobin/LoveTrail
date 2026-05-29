import SwiftUI

/// Shared Welcome-letter visuals (see `BabyTownWelcomeCardDetailView`).
enum BabyTownLetterCardStyle {

    static let referenceCanvasWidth: CGFloat = 393

    static func scale(_ value: CGFloat, canvasWidth: CGFloat) -> CGFloat {
        value * (canvasWidth / referenceCanvasWidth)
    }

    // MARK: - Letter chrome

    static func letterCardBackground(
        cornerRadius: CGFloat,
        canvasWidth: CGFloat = referenceCanvasWidth
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.white)
            .shadow(
                color: BabyTownTheme.accent.opacity(0.15),
                radius: scale(20, canvasWidth: canvasWidth),
                y: scale(8, canvasWidth: canvasWidth)
            )
            .shadow(
                color: .black.opacity(0.06),
                radius: scale(6, canvasWidth: canvasWidth),
                y: scale(2, canvasWidth: canvasWidth)
            )
    }

    static func letterCardBorder(
        cornerRadius: CGFloat,
        canvasWidth: CGFloat = referenceCanvasWidth
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                BabyTownTheme.accent.opacity(0.15),
                lineWidth: max(1, scale(1, canvasWidth: canvasWidth))
            )
    }

    struct LetterCornerSticker {
        let icon: String
        let rotation: Double
        let x: CGFloat
        let y: CGFloat
        let alignment: Alignment
    }

    /// Corner stickers on in-app welcome / letter cards (also used for share exports).
    static let welcomeLetterCornerStickers: [LetterCornerSticker] = [
        .init(icon: "heart.fill", rotation: -12, x: -8, y: -8, alignment: .topLeading),
        .init(icon: "camera.fill", rotation: 10, x: 8, y: -8, alignment: .topTrailing),
        .init(icon: "photo.on.rectangle.angled", rotation: -8, x: -8, y: 8, alignment: .bottomLeading),
        .init(icon: "sparkles", rotation: 14, x: 8, y: 8, alignment: .bottomTrailing),
    ]

    /// White letter card with corner stickers sized to the content (not the full screen).
    static func letterChrome<Content: View>(
        cornerRadius: CGFloat,
        canvasWidth: CGFloat,
        cornerStickers: [LetterCornerSticker] = welcomeLetterCornerStickers,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background {
                ZStack {
                    letterCardBackground(cornerRadius: cornerRadius, canvasWidth: canvasWidth)
                    ForEach(Array(cornerStickers.enumerated()), id: \.offset) { _, sticker in
                        stickerDecoration(
                            icon: sticker.icon,
                            rotation: sticker.rotation,
                            x: sticker.x,
                            y: sticker.y,
                            alignment: sticker.alignment,
                            canvasWidth: canvasWidth
                        )
                    }
                }
            }
            .overlay(letterCardBorder(cornerRadius: cornerRadius, canvasWidth: canvasWidth))
    }

    // MARK: - Stickers

    static func stickerDecoration(
        icon: String,
        rotation: Double,
        x: CGFloat,
        y: CGFloat,
        alignment: Alignment,
        canvasWidth: CGFloat = referenceCanvasWidth
    ) -> some View {
        let tapeWidth = scale(30, canvasWidth: canvasWidth)
        let tapeHeight = scale(12, canvasWidth: canvasWidth)
        let boxSize = scale(48, canvasWidth: canvasWidth)
        let iconSize = scale(20, canvasWidth: canvasWidth)
        let boxRadius = scale(10, canvasWidth: canvasWidth)
        let tapeRadius = scale(2, canvasWidth: canvasWidth)
        let tapeYOffset = scale(-18, canvasWidth: canvasWidth)
        let offsetX = scale(x, canvasWidth: canvasWidth)
        let offsetY = scale(y, canvasWidth: canvasWidth)

        return ZStack {
            RoundedRectangle(cornerRadius: tapeRadius)
                .fill(Color.white.opacity(0.7))
                .frame(width: tapeWidth, height: tapeHeight)
                .rotationEffect(.degrees(rotation * 0.5))
                .offset(y: tapeYOffset)

            ZStack {
                RoundedRectangle(cornerRadius: boxRadius)
                    .fill(BabyTownTheme.accent.opacity(0.1))
                    .frame(width: boxSize, height: boxSize)

                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.6))
            }
        }
        .rotationEffect(.degrees(rotation))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .offset(x: offsetX, y: offsetY)
    }
}
