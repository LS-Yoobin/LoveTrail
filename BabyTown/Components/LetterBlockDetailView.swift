import SwiftUI

struct LetterBlockDetailView: View {
    let block: LetterBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: block.typeIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)

                Text(block.typeLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .tracking(0.8)
            }

            blockContent
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BabyTownTheme.cardBackground.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(BabyTownTheme.accent.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block.type {
        case .voiceMemo:
            if let fileId = block.voiceMemoFileId {
                VoiceMemoPlayerView(fileId: fileId, storage: .letter)
            } else {
                Text("Voice message unavailable")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }

        case .photo, .sticker:
            EmptyView()
        }
    }
}

#Preview {
    ScrollView {
        LetterBlockDetailView(
            block: LetterBlock(type: .voiceMemo, voiceMemoFileId: "test.m4a")
        )
        .padding()
    }
}
