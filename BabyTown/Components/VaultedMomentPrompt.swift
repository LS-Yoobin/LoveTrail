import SwiftUI

struct VaultedMomentPrompt: View {

    @Binding var isPresented: Bool
    var onUnlockForever: () -> Void

    private var accent: Color { BabyTownTheme.accentDeep }

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(accent)

            VStack(spacing: 6) {
                Text("This moment has been safely stored away")
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.85))

                Text("Upgrade to Covela Forever to unlock your full timeline")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(.horizontal, 24)

            Button {
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onUnlockForever()
                }
            } label: {
                Text("Unlock Forever")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [BabyTownTheme.accent, accent],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button {
                isPresented = false
            } label: {
                Text("Maybe later")
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(BabyTownTheme.cardBackground)
    }
}
