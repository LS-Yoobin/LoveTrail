import SwiftUI

/// Bottom tooltip while arranging profile stickers over the garden.
struct CustomizeProfileBanner: View {
    let onDone: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Customize")
                    .font(.subheadline.weight(.semibold))
                Text("Drag stickers and the record player · pinch to resize")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done", action: onDone)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}
