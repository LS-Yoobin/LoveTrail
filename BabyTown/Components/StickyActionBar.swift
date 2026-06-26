import SwiftUI

struct StickyActionBar: View {

    var onSelectPhotos: () -> Void
    var onScan: (() -> Void)?
    var onPlanner: (() -> Void)?
    var onPrompt: (() -> Void)?
    var onCapture: (() -> Void)?
    var isNightMode: Bool = false

    private enum Metrics {
        static let fontSize: CGFloat = 14
        static let iconSize: CGFloat = 14
        static let labelSpacing: CGFloat = 6
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 11
        static let strokeWidth: CGFloat = 1.5
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                primaryPill(title: "Select Photos", systemImage: "photo.on.rectangle.angled", action: onSelectPhotos)

                if let onScan {
                    secondaryPill(title: "Scan", systemImage: "viewfinder.circle", action: onScan)
                }

                if let onPlanner {
                    secondaryPill(title: "Planner", systemImage: "calendar.badge.plus", action: onPlanner)
                }

                if let onPrompt {
                    secondaryPill(title: "Prompt", systemImage: "sparkles", action: onPrompt)
                }

                if let onCapture {
                    Button(action: onCapture) {
                        Image(systemName: "camera")
                            .font(.system(size: Metrics.fontSize, weight: .medium))
                            .foregroundStyle(
                                isNightMode
                                    ? AnyShapeStyle(.white)
                                    : AnyShapeStyle(BabyTownTheme.accentIconGradient)
                            )
                            .frame(width: Metrics.iconSize + Metrics.verticalPadding * 2,
                                   height: Metrics.iconSize + Metrics.verticalPadding * 2)
                            .background(
                                Circle().fill(isNightMode ? Color.white.opacity(0.22) : BabyTownTheme.accent.opacity(0.18))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 0)
        }
    }

    // MARK: - Pills

    private func primaryPill(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title: title, systemImage: systemImage)
                .foregroundStyle(.white)
                .padding(.horizontal, Metrics.horizontalPadding)
                .padding(.vertical, Metrics.verticalPadding)
                .background(Capsule().fill(BabyTownTheme.accentGradient))
        }
        .buttonStyle(.plain)
    }

    private func secondaryPill(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title: title, systemImage: systemImage)
                .foregroundStyle(isNightMode ? .white : BabyTownTheme.accent)
                .padding(.horizontal, Metrics.horizontalPadding)
                .padding(.vertical, Metrics.verticalPadding)
                .background(
                    Capsule()
                        .strokeBorder(BabyTownTheme.accent, lineWidth: Metrics.strokeWidth)
                )
        }
        .buttonStyle(.plain)
    }

    /// Shared label layout so icon optical size does not change pill dimensions (e.g. `sparkles` vs `viewfinder.circle`).
    private func pillLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: Metrics.labelSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.iconSize, weight: .semibold))
                .frame(width: Metrics.iconSize, height: Metrics.iconSize)

            Text(title)
                .font(.system(size: Metrics.fontSize, weight: .semibold))
                .lineLimit(1)
        }
    }
}

#Preview {
    ZStack {
        HomeBackgroundView(isNightMode: true)
        VStack(spacing: 0) {
            BabyTownHeader(isNightMode: true)
            StickyActionBar(
                onSelectPhotos: {},
                onScan: {},
                onPrompt: {},
                isNightMode: true
            )
        }
    }
}
