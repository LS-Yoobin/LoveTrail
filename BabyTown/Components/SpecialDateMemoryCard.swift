import SwiftUI

enum SpecialDateMemoryCardStyle {
    /// Horizontal pinned strips (matches PinnedMemoryCard).
    case compact
    /// Home timeline and full-screen pinned feed (matches PromptMemoryCard / DayClusterCard).
    case timeline
}

/// Home pinned-row and timeline card for a couple special date from the profile.
struct SpecialDateMemoryCard: View {
    let title: String
    let date: Date
    let image: UIImage?
    var style: SpecialDateMemoryCardStyle = .compact
    var isPinned: Bool = false
    var isLeftAligned: Bool = true
    var index: Int = 0
    var onTap: () -> Void
    var onShare: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onTogglePin: (() -> Void)? = nil

    private var showsMenu: Bool {
        onShare != nil || onEdit != nil || onDelete != nil || onTogglePin != nil
    }

    private var timelineDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }

    private var compactFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        switch style {
        case .compact:
            compactBody
        case .timeline:
            timelineBody
        }
    }

    // MARK: - Compact (pinned strip)

    private var compactBody: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                compactPhotoArea
                compactTextArea
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .fill(BabyTownTheme.cardBackground)
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if showsMenu {
                compactMenu
            }
        }
    }

    @ViewBuilder
    private var compactPhotoArea: some View {
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
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 150)
                    .overlay {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 32))
                            .foregroundStyle(BabyTownTheme.accent.opacity(0.45))
                    }
            }
        }
        .frame(height: 150)
    }

    private var compactTextArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .lineLimit(2)
            Text(compactFormattedDate)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: isPinned ? "pin.fill" : "heart.text.square")
                    .font(.system(size: 8))
                Text(isPinned ? "Pinned" : "Special date")
                    .font(.system(size: 10))
            }
            .foregroundStyle(BabyTownTheme.accent.opacity(0.7))
        }
    }

    private var compactMenu: some View {
        Menu {
            menuActions
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

    // MARK: - Timeline (home feed)

    private var timelineBody: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                timelineHeaderSection
                timelineTitleSection
                ZStack(alignment: isLeftAligned ? .bottomTrailing : .bottomLeading) {
                    timelinePhotoArea
                    catDecoration
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(12)
            .padding(.trailing, showsMenu ? 28 : 0)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if showsMenu {
                timelineMenu
                    .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .fill(BabyTownTheme.cardBackground.opacity(0.75))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .strokeBorder(BabyTownTheme.accent.opacity(0.15), lineWidth: 1)
        )
    }

    private var timelineHeaderSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timelineDateFormatter.string(from: date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)

            Text("Special date")
                .font(.system(size: 12))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timelineTitleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.accent)

                Text("Important Date")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .textCase(.uppercase)
            }

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(3)
        }
    }

    @ViewBuilder
    private var timelinePhotoArea: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .overlay {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 36))
                        .foregroundStyle(BabyTownTheme.accent.opacity(0.45))
                }
        }
    }

    private var catDecoration: some View {
        let variant = (index % 5) + 1
        return Image("cat_variant_\(variant)")
            .resizable()
            .scaledToFit()
            .frame(width: 110, height: 110)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .allowsHitTesting(false)
    }

    private var timelineMenu: some View {
        Menu {
            menuActions
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var menuActions: some View {
        if let onShare {
            Button(action: onShare) {
                Label("Share Memory", systemImage: "square.and.arrow.up")
            }
        }
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
    }
}
