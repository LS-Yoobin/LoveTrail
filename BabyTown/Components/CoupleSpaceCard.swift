import SwiftUI

/// Full-width garden card on the Home feed. Taps into the Couple Profile / Secret Garden.
struct CoupleSpaceCard: View {

    private static let avatarSize: CGFloat = 36

    var avatar: UIImage?
    var partnerAvatar: UIImage? = nil
    var gardenThumbnail: UIImage? = nil
    var bloomCount: Int
    var isReadyToInvite: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                gardenBackground

                // Scrim: darker at top (title) and bottom (avatars)
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.42), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 64)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 64)
                }

                // Title row at top
                HStack(alignment: .center) {
                    Text("Our Garden")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Avatar pair at bottom-left
                avatarRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var gardenBackground: some View {
        Group {
            if let gardenThumbnail {
                Image(uiImage: gardenThumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.90, blue: 0.98),
                        Color(red: 0.66, green: 0.80, blue: 0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var avatarRow: some View {
        HStack(spacing: -Self.avatarSize * 0.28) {
            partnerAvatarCircle
            userAvatarCircle
        }
    }

    private var userAvatarCircle: some View {
        avatarCircle(image: avatar, placeholder: "person.fill")
            .zIndex(1)
    }

    private var partnerAvatarCircle: some View {
        avatarCircle(image: partnerAvatar, placeholder: "heart.circle")
            .zIndex(0)
    }

    private func avatarCircle(image: UIImage?, placeholder: String) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.white.opacity(0.25))
                Image(systemName: placeholder)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
    }
}

#Preview {
    CoupleSpaceCard(
        avatar: nil,
        partnerAvatar: nil,
        gardenThumbnail: nil,
        bloomCount: 8,
        isReadyToInvite: false,
        onTap: {}
    )
    .padding(.vertical, 40)
    .background(Color(.systemGroupedBackground))
}
