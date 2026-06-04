import SwiftUI

/// Fixed footer actions while editing the garden layout.
struct EditGardenFooterBar: View {
    var noteButtonTitle: String = "Add Note"
    var stickerButtonTitle: String = "Create Stickers"
    let onAddNote: () -> Void
    let onCreateStickers: () -> Void

    private static var buttonFill: Color { BabyTownTheme.accentMuted }

    var body: some View {
        HStack(spacing: 12) {
            actionButton(title: noteButtonTitle, action: onAddNote)
            actionButton(title: stickerButtonTitle, action: onCreateStickers)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .tint(.white)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Self.buttonFill)
                )
        }
        .foregroundStyle(Color.white)
        .tint(.white)
        .buttonStyle(.plain)
    }
}
