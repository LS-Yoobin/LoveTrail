import SwiftUI

/// Landing-page preview: horizontal pinned memories strip with See More.
struct PinnedMemoriesPreviewCard: View {
    let pinnedItems: [PinnedItem]
    let specialDates: [SpecialDate]
    let showsOfficialPlaceholder: Bool
    let showsFirstMetPlaceholder: Bool
    let photoForSpecialDate: (UUID) -> UIImage?
    let onSeeMore: () -> Void
    let onTapOfficialPlaceholder: () -> Void
    let onTapFirstMetPlaceholder: () -> Void
    let onTapSpecialDate: (SpecialDate) -> Void
    let onEditSpecialDate: (SpecialDate) -> Void
    let onDeleteSpecialDate: (SpecialDate) -> Void
    let onUnpinSpecialDate: (SpecialDate) -> Void
    let onTapPinned: (PinnedItem) -> Void
    let onUnpinPinned: (PinnedItem) -> Void
    let onSharePinned: (MemorySharePayload) -> Void

    private var isVisible: Bool {
        !pinnedItems.isEmpty
            || showsOfficialPlaceholder
            || showsFirstMetPlaceholder
            || !specialDates.isEmpty
    }

    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Pinned Memories")
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

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if showsOfficialPlaceholder {
                            FoundingPlaceholderCard(
                                title: "When we became official",
                                showsPinnedLabel: true,
                                onTap: onTapOfficialPlaceholder
                            )
                            .frame(width: 180)
                        }

                        if showsFirstMetPlaceholder {
                            FoundingPlaceholderCard(
                                title: "When we first met",
                                showsPinnedLabel: true,
                                onTap: onTapFirstMetPlaceholder
                            )
                            .frame(width: 180)
                        }

                        ForEach(specialDates) { special in
                            SpecialDateMemoryCard(
                                title: special.title,
                                date: special.date,
                                image: photoForSpecialDate(special.id),
                                isPinned: true,
                                onTap: { onTapSpecialDate(special) },
                                onEdit: { onEditSpecialDate(special) },
                                onDelete: { onDeleteSpecialDate(special) },
                                onTogglePin: { onUnpinSpecialDate(special) }
                            )
                            .frame(width: 180)
                        }

                        ForEach(pinnedItems) { item in
                            PinnedMemoryCard(
                                item: item,
                                onTap: { onTapPinned(item) },
                                onUnpin: { onUnpinPinned(item) },
                                onShare: onSharePinned
                            )
                            .frame(width: 180)
                        }
                    }
                }
            }
            .padding(18)
            .background { CoupleProfileScrollCardBackground() }
        }
    }
}
