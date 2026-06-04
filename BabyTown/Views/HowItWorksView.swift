import SwiftUI

struct HowItWorksView: View {

    var onBack: () -> Void
    var onEnterHome: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 24)

                HeartTrailHeader()
                    .padding(.bottom, 32)

                titleSection
                    .padding(.bottom, 36)

                benefitsSection
                    .padding(.bottom, 12)

                Spacer()

                VStack(spacing: 14) {
                    enterButton
                    OnboardingLegalLinks()
                }
            }
            .opacity(contentOpacity)
        }
        .onboardingBackButton(action: onBack)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                contentOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                buttonOpacity = 1.0
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [.white, BabyTownTheme.accent.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 14) {
            Text("Just pick photos of us.")
                .font(.system(size: 25, weight: .light, design: .serif))
                .foregroundStyle(.white)

            Text("Baby Town does the rest.")
                .font(.system(size: 25, weight: .light, design: .serif))
                .foregroundStyle(BabyTownTheme.accent)

            Text("Select your favorite moments and we'll\norganize them by day and place for you.")
                .font(.system(size: 14))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(spacing: 18) {
            BenefitRow(
                icon: "calendar",
                title: "Auto grouped by day"
            )
            BenefitRow(
                icon: "mappin.circle",
                title: "Places detected when possible"
            )
            BenefitRow(
                icon: "sparkles",
                title: "Throwbacks get better over time"
            )
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - CTA

    private var enterButton: some View {
        Button(action: onEnterHome) {
            Text("Enter Baby Town")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 14, y: 6)
                )
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 8)
        .opacity(buttonOpacity)
    }
}

#Preview {
    HowItWorksView(onBack: {}, onEnterHome: {
        print("Enter Baby Town")
    })
}
