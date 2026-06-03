import SwiftUI

/// Top chrome: back and optional add-photo. Profile cutouts, display name, and
/// the partner invite circle sit in the garden band below this bar.
struct CoupleHeaderView: View {
    /// Height of the button row (excluding safe area).
    static let estimatedHeight: CGFloat = 52
    /// Padding above the row when floating over scroll content (`8` inner + `4` outer).
    static let overlayTopPadding: CGFloat = 12
    /// Scroll top inset below the status bar so content clears this header.
    static var scrollTopClearance: CGFloat { estimatedHeight + overlayTopPadding }

    var showsAddPhoto: Bool = false
    let onBack: () -> Void
    var onAddPhoto: (() -> Void)? = nil
    var onInvite: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            if showsAddPhoto, let onAddPhoto {
                Button(action: onAddPhoto) {
                    Text("Add photo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
            } else if let onInvite {
                Button(action: onInvite) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Invite")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(BabyTownTheme.buttonGradient, in: Capsule())
                    .shadow(color: BabyTownTheme.buttonShadow, radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
