import SwiftUI

/// A glass card button that opens the Visit Pet flow, illustrated with the
/// currently adopted cat's portrait (falls back to a paw icon if none adopted).
struct VisitPetCard: View {
    let skin: CatSkin?
    let onVisit: () -> Void

    var body: some View {
        Button(action: onVisit) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(skin?.placeholderColor.opacity(0.25) ?? Color.gray.opacity(0.2))
                    if let skin {
                        Image(skin.profileSitAsset).resizable().scaledToFit().padding(8)
                    } else {
                        Image(systemName: "pawprint.fill").font(.title2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Visit Pet").font(.subheadline.weight(.semibold))
                    Text(skin?.petName ?? "Your cat is waiting")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
