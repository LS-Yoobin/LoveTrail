import SwiftUI

struct WatchTogetherInviteBanner: View {
    let hostName: String
    var onJoin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(hostName) started Watch Together")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }

            Spacer(minLength: 8)

            Button("Join", action: onJoin)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(BabyTownTheme.accentGradient, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(BabyTownTheme.accent.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
