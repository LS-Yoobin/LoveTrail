import SwiftUI

struct VaultedMomentPrompt: View {

    @Binding var isPresented: Bool
    var onUnlockForever: () -> Void

    private var accent: Color { BabyTownTheme.accentDeep }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(BabyTownTheme.accentSoft)
                    .frame(width: 72, height: 72)

                Circle()
                    .strokeBorder(BabyTownTheme.accentGradient, lineWidth: 1.5)
                    .frame(width: 72, height: 72)

                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentGradient)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)

            VStack(spacing: 10) {
                Text("This memory is in your vault")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Your story is still here. On the free plan, your 50 most recent moments stay visible. Everything beyond that is safely stored in your vault until you choose to unlock it.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 28)

            vaultRuleCard
                .padding(.horizontal, 24)
                .padding(.top, 20)

            VStack(spacing: 12) {
                Button {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onUnlockForever()
                    }
                } label: {
                    Text("Yes")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BabyTownTheme.accentGradient)
                        )
                        .shadow(color: accent.opacity(0.22), radius: 10, y: 4)
                }
                .buttonStyle(.plain)

                Button {
                    isPresented = false
                } label: {
                    Text("Later")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 28)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BabyTownTheme.cardBackground.ignoresSafeArea())
    }

    private var vaultRuleCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 18))
                .foregroundStyle(accent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Covela Forever")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Unlock your full timeline, every letter, and unlimited pins with one membership for both of you.")
                    .font(.system(size: 12))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accent.opacity(0.14), lineWidth: 1)
                )
        )
    }
}
