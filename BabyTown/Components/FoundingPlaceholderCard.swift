import SwiftUI

/// Dashed placeholder card for founding photo slots on Home and Secret Garden.
struct FoundingPlaceholderCard: View {
    let title: String
    var showsPinnedLabel: Bool = false
    var onTap: () -> Void
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                BabyTownTheme.accent.opacity(0.12),
                                BabyTownTheme.accent.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 150)

                VStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(BabyTownTheme.accent.opacity(0.4))
                        .scaleEffect(pulse ? 1.1 : 1.0)

                    Text("Add Photo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accent)
                }
            }

            // Timeline placeholders use `foundingMomentLabelPlaceholder` below the card;
            // only pinned-strip cards repeat the title here.
            if showsPinnedLabel {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                        Text("Pinned")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.7))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .fill(BabyTownTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .strokeBorder(
                    BabyTownTheme.accent.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
