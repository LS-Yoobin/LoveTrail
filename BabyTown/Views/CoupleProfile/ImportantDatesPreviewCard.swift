import SwiftUI
import GardenCore

/// Landing-page preview: horizontal scroll of up to two important dates with See More.
struct ImportantDatesPreviewCard: View {
    let items: [ImportantDateItem]
    var previewLimit: Int = 2
    let photoForItem: (ImportantDateItem) -> UIImage?
    let onSeeMore: () -> Void
    let onTapSpecial: (String) -> Void
    let onTapPhoto: (ImportantDateItem) -> Void

    private static let dateFormat: Date.FormatStyle =
        .dateTime.month(.abbreviated).day().year()

    private var previewItems: [ImportantDateItem] {
        Array(items.prefix(previewLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            if previewItems.isEmpty {
                Text("Add your first special date")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(previewItems) { item in
                            previewRow(item)
                                .frame(width: 220)
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 18)
                }
                .padding(.horizontal, -18)
                .contentMargins(.horizontal, 0, for: .scrollContent)
            }
        }
        .padding(18)
        .background { CoupleProfileScrollCardBackground() }
    }

    private var headerRow: some View {
        HStack {
            Text("Important Dates")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button(action: onSeeMore) {
                HStack(spacing: 4) {
                    Text("See More")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func previewRow(_ item: ImportantDateItem) -> some View {
        let image = photoForItem(item)

        HStack(spacing: 12) {
            if item.kind == .special {
                thumbnailButton(image, item: item)
                Button { onTapSpecial(item.id) } label: {
                    rowText(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else if image != nil {
                Button { onTapPhoto(item) } label: {
                    HStack(spacing: 12) {
                        thumbnail(image)
                        rowText(item)
                    }
                }
                .buttonStyle(.plain)
            } else {
                thumbnail(nil)
                rowText(item)
            }
        }
    }

    private func rowText(_ item: ImportantDateItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(item.date, format: Self.dateFormat)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private func thumbnailButton(_ image: UIImage?, item: ImportantDateItem) -> some View {
        if image != nil {
            Button { onTapSpecial(item.id) } label: { thumbnail(image) }
                .buttonStyle(.plain)
        } else {
            thumbnail(nil)
        }
    }

    private func thumbnail(_ image: UIImage?) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15))
                Image(systemName: "calendar").font(.caption).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
