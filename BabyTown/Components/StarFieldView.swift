import SwiftUI

/// Renders a field of twinkling stars for night mode
struct StarFieldView: View {
    
    let starCount: Int = 35
    @State private var stars: [Star] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(stars) { star in
                    StarView(star: star)
                        .position(
                            x: star.x * geometry.size.width,
                            y: star.y * geometry.size.height
                        )
                }
            }
            .onAppear {
                if stars.isEmpty {
                    generateStars()
                }
            }
        }
    }
    
    private func generateStars() {
        stars = (0..<starCount).map { _ in
            Star(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1.5...3.5),
                animationDuration: Double.random(in: 2.0...4.0),
                animationDelay: Double.random(in: 0...2.0)
            )
        }
    }
}

/// Individual star with twinkling animation
private struct StarView: View {
    
    let star: Star
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: star.size, height: star.size)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                // Stagger the animation start
                DispatchQueue.main.asyncAfter(deadline: .now() + star.animationDelay) {
                    withAnimation(
                        .easeInOut(duration: star.animationDuration)
                        .repeatForever(autoreverses: true)
                    ) {
                        opacity = 0.3
                    }
                }
            }
            .onTapGesture {
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                // Bounce animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.3
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        scale = 1.0
                    }
                }
            }
    }
}

/// Model representing a star's properties
private struct Star: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let animationDuration: Double
    let animationDelay: Double
}
