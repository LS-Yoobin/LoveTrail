import SwiftUI
import GardenCore

/// Full-width garden card on the Home feed. Taps into the Couple Profile / Secret Garden.
struct CoupleSpaceCard: View {

    private static let avatarSize: CGFloat = 36

    var avatar: UIImage?
    var partnerAvatar: UIImage? = nil
    var gardenElements: [GardenElement] = []
    var gardenSeason: GardenSeason = .blooming
    var bloomCount: Int
    var isReadyToInvite: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                gardenBackground

                Color.black.opacity(0.25)

                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Our Garden")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(bloomCount) Moments Shared")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.80))
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        avatarRow
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 16)
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
            if gardenElements.isEmpty {
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.90, blue: 0.98),
                        Color(red: 0.66, green: 0.80, blue: 0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                CoupleSpaceGardenBackground(
                    elements: gardenElements,
                    season: gardenSeason
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
        gardenElements: [],
        gardenSeason: .blooming,
        bloomCount: 8,
        isReadyToInvite: false,
        onTap: {}
    )
    .padding(.vertical, 40)
    .background(Color(.systemGroupedBackground))
}
