import SwiftUI

/// Prompt label used on full-photo viewers and founding-moment location editing.
struct PromptDisplayCard: View {

    let prompt: String
    var variant: Variant = .photoOverlay

    enum Variant {
        /// Dark photo viewer (PromptPhotoViewer, MomentPhotoViewer immersive).
        case photoOverlay
        /// Light form header above Place name (CaptionEditorSheet location mode).
        case formHeader
        /// Light scrapbook moment page.
        case momentPage
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)

            Text(prompt)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(textColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
    }

    private var textColor: Color {
        switch variant {
        case .photoOverlay: .white
        case .formHeader, .momentPage: BabyTownTheme.textPrimary
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        switch variant {
        case .photoOverlay:
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.15))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        case .formHeader:
            RoundedRectangle(cornerRadius: 12)
                .fill(BabyTownTheme.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(BabyTownTheme.accent.opacity(0.18), lineWidth: 1)
                )
        case .momentPage:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
    }
}
