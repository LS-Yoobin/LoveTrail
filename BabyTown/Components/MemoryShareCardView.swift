import SwiftUI

/// Fixed 9:16 export canvas styled like `BabyTownWelcomeCardDetailView`.
struct MemoryShareCardView: View {

    static let exportSize = CGSize(width: 1080, height: 1920)

    /// Matches welcome screen: letter dominates upper area, cats fill the lower band.
    private static let letterHeightRatio: CGFloat = 0.62
    private static let catHeightRatio: CGFloat = 0.28

    let payload: MemorySharePayload
    let images: [UIImage]

    private static let foundingPrompts: Set<String> = [
        "When we first met",
        "When we became official"
    ]

    private var canvasWidth: CGFloat { Self.exportSize.width }
    private var canvasHeight: CGFloat { Self.exportSize.height }

    private func s(_ value: CGFloat) -> CGFloat {
        BabyTownLetterCardStyle.scale(value, canvasWidth: canvasWidth)
    }

    private var displayImages: [UIImage] {
        Array(images.prefix(MemorySharePhotoCollage.maxPhotos))
    }

    private var letterCornerRadius: CGFloat { s(20) }
    private var letterPadding: CGFloat { s(28) }
    private var letterSpacing: CGFloat { s(16) }

    private var hasPhotos: Bool { !displayImages.isEmpty }

    var body: some View {
        ZStack {
            BabyTownTheme.backgroundGradient

            VStack(spacing: s(8)) {
                letterCard
                    .padding(.horizontal, s(20))
                    .padding(.top, s(16))

                Image(MemoryShareStyle.heroCatAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: canvasHeight * Self.catHeightRatio)
                    .padding(.horizontal, s(40))
                    .padding(.bottom, s(24))
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    // MARK: - Letter

    @ViewBuilder
    private var letterCard: some View {
        let letterHeight = hasPhotos ? canvasHeight * Self.letterHeightRatio : nil

        BabyTownLetterCardStyle.letterChrome(
            cornerRadius: letterCornerRadius,
            canvasWidth: canvasWidth,
            cornerStickers: MemoryShareStyle.letterCornerStickers
        ) {
            VStack(alignment: .leading, spacing: 0) {
                letterTextContent
                    .fixedSize(horizontal: false, vertical: true)

                if hasPhotos {
                    MemorySharePhotoCollage(
                        images: displayImages,
                        cornerRadius: s(12),
                        layoutScale: canvasWidth / BabyTownLetterCardStyle.referenceCanvasWidth
                    )
                    .padding(.top, letterSpacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(letterPadding)
            .frame(maxWidth: .infinity)
            .frame(height: letterHeight, alignment: .top)
        }
        .fixedSize(horizontal: false, vertical: letterHeight == nil)
    }

    private var letterTextContent: some View {
        VStack(alignment: .leading, spacing: letterSpacing) {
            Text(payload.dateDisplay)
                .font(.system(size: s(22), weight: .bold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if payload.placeName != nil {
                PlaceNameLabel(
                    rawPlaceName: payload.placeName,
                    isUserSet: payload.isPlaceNameUserSet,
                    font: .system(size: s(17), weight: .semibold, design: .serif),
                    foregroundStyle: BabyTownTheme.textPrimary.opacity(0.85),
                    iconSize: s(14),
                    spacing: s(6),
                    lineLimit: 2
                )
            }

            if let prompt = payload.promptText {
                promptCapsule(prompt)
            }

            if payload.loveNote != nil || hasPhotos {
                Rectangle()
                    .fill(BabyTownTheme.accent.opacity(0.3))
                    .frame(height: s(1))
            }

            if let note = payload.loveNote {
                Text(note)
                    .font(.system(size: s(16), weight: .regular, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.8))
                    .lineSpacing(s(6))
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func promptCapsule(_ text: String) -> some View {
        let isFounding = Self.foundingPrompts.contains(text)

        HStack(spacing: s(4)) {
            if !isFounding {
                Image(systemName: "sparkles")
                    .font(.system(size: s(10)))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            Text(text)
                .font(.system(size: s(11), weight: .medium))
                .foregroundStyle(isFounding ? .white : BabyTownTheme.accent)
        }
        .padding(.horizontal, s(8))
        .padding(.vertical, s(3))
        .background(
            Capsule()
                .fill(isFounding ? Color.green : BabyTownTheme.accent.opacity(0.1))
        )
    }
}
