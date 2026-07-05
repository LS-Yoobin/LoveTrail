import SwiftUI

/// Asked right after birthday, before Prelude vs Already Official — lets
/// someone who already has a partner's invite code connect immediately
/// instead of building out their own space first only to have it replaced.
struct InviteCodeCheckView: View {
    var onBack: () -> Void
    var onHaveCode: () -> Void
    var onNoCode: () -> Void

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Did your partner send you a code?")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(BabyTownTheme.accentDeep)
                        .multilineTextAlignment(.center)

                    Text("If they already started your shared space, connect right away.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.accent)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 80)

                Spacer()

                VStack(spacing: 16) {
                    PathCard(
                        icon: "key.fill",
                        title: "Yes, I have a code",
                        description: "Enter it now and connect with your partner's space.",
                        action: haveCode
                    )

                    PathCard(
                        icon: "sparkles",
                        title: "Not yet",
                        description: "Let's set things up first.",
                        action: noCode
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                contentOpacity = 1.0
            }
        }
        .onboardingBackButton(action: onBack)
    }

    private func haveCode() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onHaveCode()
    }

    private func noCode() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onNoCode()
    }
}

#Preview {
    InviteCodeCheckView(onBack: {}, onHaveCode: {}, onNoCode: {})
}
