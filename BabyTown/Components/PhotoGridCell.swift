import SwiftUI

struct PhotoGridCell: View {

    let thumbnail: UIImage?
    let isSelected: Bool
    let selectionMode: Bool
    /// When true, always shows heart selection UI; unselected cells are dimmed (memory edit gallery).
    var memoryEditStyle: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Color.clear drives a definite square frame from the column width;
            // the photo fills it as a clipped overlay. Without this anchor the
            // resizable image falls back to its intrinsic size and cells overlap.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    ZStack {
                        photoContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        selectionOverlay
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoContent: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
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
        if selectionMode || memoryEditStyle {
            ZStack {
                if memoryEditStyle {
                    if isSelected {
                        Color.black.opacity(0.15)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Color.black.opacity(0.45)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if isSelected {
                    Color.black.opacity(0.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                selectionHeart
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
    }

    private var selectionHeart: some View {
        Image(systemName: isSelected ? "heart.fill" : "heart")
            .font(.system(size: 30, weight: isSelected ? .regular : .semibold))
            .foregroundStyle(
                isSelected
                    ? Color(red: 0.95, green: 0.25, blue: 0.3)
                    : .white
            )
            .shadow(color: .black.opacity(memoryEditStyle && !isSelected ? 0.5 : 0.35), radius: 3, y: 1)
            .scaleEffect(isSelected ? 1.1 : 1)
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
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
    .padding(2)
}
