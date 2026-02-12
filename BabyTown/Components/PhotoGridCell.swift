import SwiftUI

struct PhotoGridCell: View {

    let thumbnail: UIImage?
    let isSelected: Bool
    let selectionMode: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                photoContent
                selectionOverlay
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoContent: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
        } else {
            Rectangle()
                .fill(BabyTownTheme.accentSoft)
                .overlay(
                    ProgressView()
                        .tint(BabyTownTheme.accent.opacity(0.4))
                        .scaleEffect(0.7)
                )
        }
    }

    // MARK: - Selection

    @ViewBuilder
    private var selectionOverlay: some View {
        if selectionMode {
            ZStack {
                if isSelected {
                    Color.black.opacity(0.15)
                }

                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(isSelected ? BabyTownTheme.accent : .black.opacity(0.25))
                                .frame(width: 26, height: 26)

                            Image(systemName: isSelected ? "heart.fill" : "heart")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                    }
                    Spacer()
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
    }
}

#Preview {
    HStack(spacing: 2) {
        PhotoGridCell(
            thumbnail: Moment.placeholder(.systemPink),
            isSelected: false,
            selectionMode: true,
            action: {}
        )
        PhotoGridCell(
            thumbnail: Moment.placeholder(.systemTeal),
            isSelected: true,
            selectionMode: true,
            action: {}
        )
        PhotoGridCell(
            thumbnail: nil,
            isSelected: false,
            selectionMode: false,
            action: {}
        )
    }
    .frame(height: 120)
    .padding()
}
