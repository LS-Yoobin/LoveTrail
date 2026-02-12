import SwiftUI

struct PinnedMemoryCard: View {

    let title: String
    let image: UIImage?
    var dateLabel: String = "Pinned"
    var placeLabel: String = "Our first chapter"
    var isPlaceholder: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            photoArea
            textArea
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .fill(BabyTownTheme.cardBackground)
                .shadow(color: BabyTownTheme.cardShadow, radius: 8, y: 3)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoArea: some View {
        if let image, !isPlaceholder {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(BabyTownTheme.accentSoft)
                .frame(height: 150)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "heart")
                            .font(.system(size: 28, weight: .thin))
                            .foregroundStyle(BabyTownTheme.accent.opacity(0.35))
                        Text("Optional")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(BabyTownTheme.accent.opacity(0.5))
                    }
                )
        }
    }

    // MARK: - Text

    private var textArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                Text(dateLabel)
                    .font(.system(size: 10))
            }
            .foregroundStyle(BabyTownTheme.accent.opacity(0.7))

            Text(placeLabel)
                .font(.system(size: 10))
                .foregroundStyle(BabyTownTheme.textTertiary)
        }
    }
}

#Preview {
    HStack(spacing: 14) {
        PinnedMemoryCard(
            title: "First Photo Taken Together",
            image: nil,
            isPlaceholder: true
        )
        PinnedMemoryCard(
            title: "First Photo As Official Jinkies",
            image: Moment.samplePinnedOfficial
        )
    }
    .padding(20)
}
