import SwiftUI

private struct TrailHeart: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let size: CGFloat
    let delay: Double
    let drift: CGFloat
}

struct HeartTrailHeader: View {

    @State private var animate = false

    private let hearts: [TrailHeart] = [
        TrailHeart(xOffset: -4,  size: 10, delay: 0.0,  drift: -6),
        TrailHeart(xOffset: 8,   size: 14, delay: 0.6,  drift: 5),
        TrailHeart(xOffset: -12, size: 8,  delay: 1.3,  drift: -8),
        TrailHeart(xOffset: 16,  size: 12, delay: 2.0,  drift: 10),
        TrailHeart(xOffset: -2,  size: 16, delay: 0.9,  drift: -3),
        TrailHeart(xOffset: 10,  size: 9,  delay: 2.5,  drift: 7),
        TrailHeart(xOffset: -8,  size: 11, delay: 1.7,  drift: -10),
    ]

    var body: some View {
        ZStack {
            // Anchor heart at bottom
            Image(systemName: "heart.fill")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .red.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .pink.opacity(0.25), radius: 10, y: 4)
                .offset(y: 50)
                .scaleEffect(animate ? 1.0 : 0.9)
                .animation(
                    .easeInOut(duration: 2.4)
                    .repeatForever(autoreverses: true),
                    value: animate
                )

            // Rising trail
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: heart.size))
                    .foregroundStyle(.pink.opacity(0.35))
                    .offset(
                        x: heart.xOffset + (animate ? heart.drift : 0),
                        y: animate ? -60 : 40
                    )
                    .opacity(animate ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 3.5)
                        .repeatForever(autoreverses: false)
                        .delay(heart.delay),
                        value: animate
                    )
            }
        }
        .frame(height: 140)
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }
}

#Preview {
    HeartTrailHeader()
        .frame(maxWidth: .infinity)
        .background(Color.white)
}
