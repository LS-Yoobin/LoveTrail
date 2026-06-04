import SwiftUI

/// Fixed footer actions while editing the garden layout.
struct EditGardenFooterBar: View {
    var noteButtonTitle: String = "Add Note"
    var stickerButtonTitle: String = "Create Stickers"
    let onAddNote: () -> Void
    let onCreateStickers: () -> Void

    private static let buttonFill = Color(red: 0.93, green: 0.55, blue: 0.52)

    var body: some View {
        HStack(spacing: 12) {
            actionButton(title: noteButtonTitle, action: onAddNote)
            actionButton(title: stickerButtonTitle, action: onCreateStickers)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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
    }
}
