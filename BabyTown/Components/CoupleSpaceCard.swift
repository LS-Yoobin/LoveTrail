import SwiftUI

/// Compact Home feed entry into the free Couple Profile / Us space. Never opens
/// the paywall — that journey lives on the couple page.
struct CoupleSpaceCard: View {

    var avatar: UIImage?
    var bloomCount: Int
    /// True when the user has purchased but has not finished inviting their partner.
    var isReadyToInvite: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                gardenGlyph

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Us")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)

                        if isReadyToInvite {
                            Text("Ready to invite")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(BabyTownTheme.accentDeep)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(BabyTownTheme.accentSoft, in: Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                avatarThumbnail

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var subtitle: String {
        if bloomCount == 0 {
            return "Your couple space · grows with memories"
        }
        let noun = bloomCount == 1 ? "bloom" : "blooms"
        return "Your garden · \(bloomCount) \(noun)"
    }

    private var gardenGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.90, blue: 0.98),
                            Color(red: 0.66, green: 0.80, blue: 0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 50, height: 50)
            Text("🌿")
                .font(.system(size: 24))
        }
    }

    @ViewBuilder
    private var avatarThumbnail: some View {
        ZStack {
            if let avatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color(.quaternaryLabel))
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
    }
}

#Preview {
    CoupleSpaceCard(
        avatar: nil,
        bloomCount: 8,
        isReadyToInvite: false,
        onTap: {}
    )
    .padding(.vertical, 40)
}
