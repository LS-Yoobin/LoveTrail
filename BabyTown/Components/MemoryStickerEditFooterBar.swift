import SwiftUI

/// Footer while arranging moment-page photo stickers.
struct MemoryStickerEditFooterBar: View {
    let onAddMore: () -> Void

    private static var buttonFill: Color { BabyTownTheme.accentMuted }

    var body: some View {
        Button(action: onAddMore) {
            Text("Add More")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Self.buttonFill)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
