import SwiftUI

struct Scene5HeartTrailView: View {
    @Binding var isInteractionComplete: Bool
    @State private var fillProgress: CGFloat = 0
    @State private var touchPoints: [CGPoint] = []
    @State private var isAnimating = false
    @State private var floatingHearts: [FloatingHeartParticle] = []
    @State private var heartScale: CGFloat = 1.0
    @State private var heartRotation: Double = 0
    @State private var sparkleOpacity: Double = 0
    
    struct FloatingHeartParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var offsetY: CGFloat = 0
        var offsetX: CGFloat = 0
        var opacity: Double = 1.0
        var scale: CGFloat = 0.5
        var rotation: Double = 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Background with warm gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.pink.opacity(0.1 + Double(fillProgress) * 0.3),
                                Color.red.opacity(0.05 + Double(fillProgress) * 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 320, height: 320)
                    .animation(.easeInOut(duration: 0.5), value: fillProgress)
                
                // Floating heart particles (after completion)
                if isAnimating {
                    ForEach(floatingHearts) { particle in
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundColor(StoryOnboardingTheme.primaryRed)
                            .opacity(particle.opacity)
                            .scaleEffect(particle.scale)
                            .rotationEffect(.degrees(particle.rotation))
                            .position(x: particle.x + particle.offsetX, y: particle.y + particle.offsetY)
                    }
                }
                
                // Main heart
                ZStack {
                    // Outline heart (gray)
                    Image(systemName: "heart")
                        .font(.system(size: 140))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    // Filled heart (red) - masked by progress
                    Image(systemName: "heart.fill")
                        .font(.system(size: 140))
                        .foregroundColor(StoryOnboardingTheme.primaryRed)
                        .mask(
                            Rectangle()
                                .frame(height: 140 * fillProgress)
                                .offset(y: -70 * (1 - fillProgress))
                        )
                    
                    // Sparkles when complete
                    if isAnimating {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .opacity(sparkleOpacity)
                    }
                }
                .scaleEffect(heartScale)
                .rotationEffect(.degrees(heartRotation))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrag(at: value.location)
                        }
                )
                
                // Instruction text
                if fillProgress < 0.99 {
                    VStack {
                        Spacer()
                        Text("Shade the heart with your finger")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.bottom, 20)
                    }
                    .frame(height: 320)
                }
            }
            .frame(height: 320)
        }
    }
    
    private func handleDrag(at location: CGPoint) {
        guard !isAnimating else { return }
        
        touchPoints.append(location)
        
        // Increase fill progress based on drag
        let increment: CGFloat = 0.02
        fillProgress = min(1.0, fillProgress + increment)
        
        // Check if heart is fully filled
        if fillProgress >= 0.99 && !isAnimating {
            completeHeart()
        }
    }
    
    private func completeHeart() {
        isAnimating = true
        isInteractionComplete = true
        
        // Heart pulse animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
            heartScale = 1.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                heartScale = 1.0
            }
        }
        
        // Sparkle animation
        withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)) {
            sparkleOpacity = 1.0
        }
        
        // Heart rotation
        withAnimation(.easeInOut(duration: 0.8)) {
            heartRotation = 360
        }
        
        // Create floating hearts
        for i in 0..<20 {
            let angle = Double(i) * (360.0 / 20.0) * .pi / 180.0
            let radius: CGFloat = 80
            let x = 160 + cos(angle) * radius
            let y = 160 + sin(angle) * radius
            
            var particle = FloatingHeartParticle(x: x, y: y)
            floatingHearts.append(particle)
            
            let delay = Double(i) * 0.05
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 2.0)) {
                    if let index = floatingHearts.firstIndex(where: { $0.id == particle.id }) {
                        floatingHearts[index].offsetY = CGFloat.random(in: -150...(-50))
                        floatingHearts[index].offsetX = CGFloat.random(in: -100...100)
                        floatingHearts[index].scale = CGFloat.random(in: 1.0...1.5)
                        floatingHearts[index].opacity = 0
                        floatingHearts[index].rotation = Double.random(in: -180...180)
                    }
                }
            }
        }
        
        // Clean up particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            floatingHearts.removeAll()
        }
    }
}

#Preview {
    Scene5HeartTrailView(isInteractionComplete: .constant(false))
        .padding()
        .background(StoryOnboardingTheme.backgroundBlush)
}
