import SwiftUI

/// Home pinned-row card for a couple special date from the profile.
struct SpecialDateMemoryCard: View {
    let title: String
    let date: Date
    let image: UIImage?
    var isPinned: Bool = false
    var onTap: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onTogglePin: (() -> Void)? = nil

    private var showsMenu: Bool {
        onEdit != nil || onDelete != nil || onTogglePin != nil
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        BabyTownTheme.accent.opacity(0.12),
                                        BabyTownTheme.accent.opacity(0.06),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 150)
                            .overlay {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 32))
                                    .foregroundStyle(BabyTownTheme.accent.opacity(0.45))
                            }
                    }
                }
                .frame(height: 150)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .lineLimit(2)
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 8))
                        Text("Special date")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.7))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .fill(BabyTownTheme.cardBackground)
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if showsMenu {
                Menu {
                    if let onTogglePin {
                        Button(action: onTogglePin) {
                            Label(
                                isPinned ? "Unpin Memory" : "Pin Memory",
                                systemImage: isPinned ? "pin.slash" : "pin"
                            )
                        }
                    }
                    if let onEdit {
                        Button(action: onEdit) {
                            Label("Edit Special Date", systemImage: "square.and.pencil")
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Special Date", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.6))
                        )
                        .contentShape(Rectangle())
                }
                .padding(8)
                .offset(x: -5, y: 5)
            }
        }
    }
}
