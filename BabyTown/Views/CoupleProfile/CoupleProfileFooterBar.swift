import SwiftUI

/// Fixed footer with Visit Pet Room and Edit Garden actions.
struct CoupleProfileFooterBar: View {
    let onVisitPet: () -> Void
    let onEditGarden: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            footerButton(title: "Visit Pet Room", action: onVisitPet)
            footerButton(title: "Edit Garden", action: onEditGarden)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func footerButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.75))
                )
        }
        .buttonStyle(.plain)
    }
}
