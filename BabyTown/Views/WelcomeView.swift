import SwiftUI

struct WelcomeView: View {

    var onContinue: () -> Void

    @State private var heroScale: CGFloat = 0.88
    @State private var heroOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var sparkleShift: CGFloat = 0
    @State private var glowShift: CGFloat = -18

    var body: some View {
        ZStack {
            background

            FloatingHeartsView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 26)

                heroMark
                    .padding(.bottom, 26)

                hookCopy
                    .opacity(contentOpacity)

                Spacer()

                VStack(spacing: 14) {
                    promiseRow
                        .padding(.bottom, 4)

                    Button(action: onContinue) {
                        Text("Create our private space")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Capsule()
                                    .fill(BabyTownTheme.buttonGradient)
                                    .shadow(color: BabyTownTheme.buttonShadow, radius: 14, y: 6)
                            )
                    }
                    .padding(.horizontal, 40)

                    OnboardingLegalLinks()
                }
                .padding(.bottom, 42)
                .opacity(contentOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                sparkleShift = 8
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                glowShift = 18
            }

            withAnimation(
                .spring(response: 0.8, dampingFraction: 0.6)
                .delay(0.2)
            ) {
                heroScale = 1.0
                heroOpacity = 1.0
            }

            withAnimation(
                .easeOut(duration: 0.6)
                .delay(0.6)
            ) {
                contentOpacity = 1.0
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    BabyTownTheme.blushSoft,
                    Color(red: 1.0, green: 0.96, blue: 0.88),
                    BabyTownTheme.accent.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.76, blue: 0.68).opacity(0.36),
                                Color(red: 0.72, green: 0.82, blue: 1.0).opacity(0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 360, height: 120)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -70, y: 58 + glowShift)

                Spacer()

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.86, blue: 0.46).opacity(0.22),
                                BabyTownTheme.accent.opacity(0.16)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 420, height: 150)
                    .rotationEffect(.degrees(14))
                    .offset(x: 95, y: -44 - glowShift)
            }

            VStack {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.14))
                        .offset(x: 34, y: 86)
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color(red: 0.94, green: 0.57, blue: 0.16).opacity(0.16))
                        .offset(x: -36, y: 132)
                }
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var heroMark: some View {
        ZStack {
            Image("BabyTownFullIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 176, height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(.white.opacity(0.78), lineWidth: 3)
                )
                .shadow(color: BabyTownTheme.accentDeep.opacity(0.18), radius: 18, y: 10)

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("for two")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(BabyTownTheme.accentDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .shadow(color: BabyTownTheme.accent.opacity(0.16), radius: 10, y: 4)
                )
                .offset(y: 13)
            }
            .frame(width: 176, height: 176)

            Image(systemName: "sparkle")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.22))
                .offset(x: -76, y: -80 - sparkleShift)

            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.22).opacity(0.85))
                .offset(x: 80, y: -68 + sparkleShift)
        }
        .scaleEffect(heroScale)
        .opacity(heroOpacity)
    }

    private var hookCopy: some View {
        VStack(spacing: 12) {
            Text("Covela")
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [BabyTownTheme.accentDeep, BabyTownTheme.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Turn your relationship into a living scrapbook.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("Photos, places, little notes, and favorite days stay tucked away in one private world for just the two of you.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(.horizontal, 30)
    }

    private var promiseRow: some View {
        HStack(spacing: 8) {
            hookPill(icon: "photo.stack.fill", title: "Memories")
            hookPill(icon: "map.fill", title: "Places")
            hookPill(icon: "heart.fill", title: "Us")
        }
        .padding(.horizontal, 24)
    }

    private func hookPill(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.58))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.98, green: 0.90, blue: 0.83).opacity(0.46))
        )
    }
}

#Preview {
    WelcomeView {
        print("Continue tapped")
    }
}
