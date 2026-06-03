import SwiftUI

/// Compact Home feed entry into the free Couple Profile / Us space. Never opens
/// the paywall — that journey lives on the couple page.
struct CoupleSpaceCard: View {

    private static let avatarSize: CGFloat = 40
    /// How much of the partner circle stays visible to the left of the user avatar.
    private static let partnerRevealFraction: CGFloat = 0.45

    var avatar: UIImage?
    /// Partner portrait when available; `nil` shows the invite heart placeholder.
    var partnerAvatar: UIImage? = nil
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

    /// Partner behind, user in front — same vertical center, ~45% of partner visible.
    private var avatarThumbnail: some View {
        HStack(spacing: -Self.avatarSize * (1 - Self.partnerRevealFraction)) {
            partnerAvatarCircle
            userAvatarCircle
        }
        .frame(
            width: Self.avatarSize + Self.avatarSize * Self.partnerRevealFraction,
            height: Self.avatarSize,
            alignment: .leading
        )
    }

    private var userAvatarCircle: some View {
        avatarCircle(image: avatar, placeholderSystemName: "person.fill")
        .zIndex(1)
    }

    private var partnerAvatarCircle: some View {
        Group {
            if let partnerAvatar {
                avatarCircle(image: partnerAvatar, placeholderSystemName: "heart.circle")
            } else {
                partnerInvitePlaceholder
            }
        }
        .zIndex(0)
    }

    private var partnerInvitePlaceholder: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(Color.secondary.opacity(0.5))
            Image(systemName: "heart.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private func avatarCircle(image: UIImage?, placeholderSystemName: String) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color(.quaternaryLabel))
                Image(systemName: placeholderSystemName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
    }
}

#Preview("With photos") {
    CoupleSpaceCard(
        avatar: nil,
        partnerAvatar: nil,
        bloomCount: 8,
        isReadyToInvite: true,
        onTap: {}
    )
    .padding(.vertical, 40)
}
