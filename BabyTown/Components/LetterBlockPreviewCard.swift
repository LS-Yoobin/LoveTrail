import SwiftUI

struct LetterBlockPreviewCard: View {
    let block: LetterBlock
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: block.typeIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(BabyTownTheme.accent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(block.typeLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .tracking(0.8)

                Text(block.displayTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(block.typeLabel)")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(BabyTownTheme.accent.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        LetterBlockPreviewCard(
            block: LetterBlock(type: .voiceMemo, voiceMemoFileId: "test.m4a"),
            onDelete: {}
        )
    }
    .padding()
}
