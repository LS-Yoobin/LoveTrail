import SwiftUI

struct PreludeOnboardingView: View {

    var onBegin: () -> Void

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    featureList
                    giftSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    beginButton
                        .padding(.horizontal, 40)
                        .padding(.top, 24)
                        .padding(.bottom, 52)
                }
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                contentOpacity = 1.0
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BabyTownTheme.accent.opacity(0.18),
                    BabyTownTheme.accent.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 12) {
                Text("💌")
                    .font(.system(size: 54))
                    .padding(.top, 44)

                Text("Your space to fall in love, quietly.")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Capture every feeling before you are official.")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(spacing: 0) {
            featureRow(
                icon: "pencil.and.scribble",
                title: "Notes & Reflections",
                description: "Write how you feel whenever it hits you. Even the small stuff."
            )
            Divider().padding(.leading, 60)
            featureRow(
                icon: "star.fill",
                title: "Firsts",
                description: "Every first has a story. Do not let a single one slip away."
            )
            Divider().padding(.leading, 60)
            featureRow(
                icon: "mic.fill",
                title: "Voice Memos",
                description: "Speak your mind in the moment. Raw, real, and unfiltered."
            )
            Divider().padding(.leading, 60)
            featureRow(
                icon: "heart.fill",
                title: "Reasons",
                description: "The little things you love about them, in your own words."
            )
        }
        .background(Color(.systemBackground))
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(BabyTownTheme.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(BabyTownTheme.accent.opacity(0.1)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Gift section

    private var giftSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🎁")
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 5) {
                Text("When you are ready, send them a gift.")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("Package your captured moments into a scrapbook. When they join, they will see exactly how you felt before you were ever official.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.29, green: 0.10, blue: 0.26),
                            Color(red: 0.55, green: 0.24, blue: 0.36)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: - CTA

    private var beginButton: some View {
        Button(action: onBegin) {
            Text("Begin my Prelude")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(BabyTownTheme.accentGradient)
                        .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 14, y: 6)
                )
        }
    }
}

#Preview {
    PreludeOnboardingView(onBegin: { print("begin") })
}
