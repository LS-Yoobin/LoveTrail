import SwiftUI

/// Renders periodic shooting stars across the night sky
struct ShootingStarView: View {
    
    @State private var isAnimating = false
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.8),
                            Color.white.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 2)
                .rotationEffect(.degrees(-45))
                .offset(x: offset, y: offset * 0.5)
                .opacity(opacity)
                .onAppear {
                    scheduleNextShootingStar()
                }
        }
    }
    
    private func scheduleNextShootingStar() {
        // Random delay between 15-30 seconds
        let delay = Double.random(in: 15.0...30.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateShootingStar()
        }
    }
    
    private func animateShootingStar() {
        // Reset position to top-left
        offset = -100
        opacity = 0
        
        // Fade in and move diagonally
        withAnimation(.linear(duration: 0.1)) {
            opacity = 1.0
        }
        
        withAnimation(.linear(duration: 1.0)) {
            offset = UIScreen.main.bounds.width + 100
        }
        
        // Fade out near the end
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.linear(duration: 0.2)) {
                opacity = 0
            }
        }
        
        // Schedule the next shooting star
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            scheduleNextShootingStar()
        }
    }
}
