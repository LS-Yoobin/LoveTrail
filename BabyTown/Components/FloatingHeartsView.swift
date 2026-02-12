import SwiftUI

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
                        Color.pink.opacity(heart.opacity)
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
