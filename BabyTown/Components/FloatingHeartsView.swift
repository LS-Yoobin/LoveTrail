import SwiftUI

struct OnboardingWelcomeBackground: View {

    @State private var glowShift: CGFloat = -18

    var body: some View {
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
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                glowShift = 18
            }
        }
    }
}

struct FloatingHeart: Identifiable {
    let id = UUID()
    var x: CGFloat
    var size: CGFloat
    var opacity: Double
    var duration: Double
    var delay: Double
}

struct FloatingHeartsView: View {

    @State private var animate = false

    private let hearts: [FloatingHeart] = (0..<12).map { _ in
        FloatingHeart(
            x: CGFloat.random(in: 0.05...0.95),
            size: CGFloat.random(in: 10...22),
            opacity: Double.random(in: 0.12...0.3),
            duration: Double.random(in: 6...12),
            delay: Double.random(in: 0...5)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: heart.size))
                    .foregroundStyle(
                        BabyTownTheme.accent.opacity(heart.opacity)
                    )
                    .position(
                        x: geo.size.width * heart.x,
                        y: animate
                            ? -heart.size
                            : geo.size.height + heart.size
                    )
                    .animation(
                        .easeInOut(duration: heart.duration)
                        .repeatForever(autoreverses: false)
                        .delay(heart.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }
}

#Preview {
    FloatingHeartsView()
        .background(Color(.systemBackground))
}
