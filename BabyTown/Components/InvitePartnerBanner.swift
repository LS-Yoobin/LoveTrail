import SwiftUI

/// Promo card shown at the top of the Home feed inviting the user to unlock the
/// paid couples tier. Tapping it opens `InvitePartnerPaywallView`.
struct InvitePartnerBanner: View {

    var onTap: () -> Void

    @State private var shimmer = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.22))
                        .frame(width: 50, height: 50)

                    Text("💞")
                        .font(.system(size: 26))
                        .scaleEffect(shimmer ? 1.08 : 1.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Invite your partner to Town")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text("Private cloud backup, just for the two of you")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BabyTownTheme.accentGradient)
                    .shadow(color: BabyTownTheme.accent.opacity(0.32), radius: 12, y: 5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

#Preview {
    InvitePartnerBanner(onTap: {})
        .padding(.vertical, 40)
        .background(Color(.systemGroupedBackground))
}
