import SwiftUI

struct Scene2PhoneCallView: View {
    @Binding var isInteractionComplete: Bool
    @State private var isPulsing = true
    @State private var showCallAnimation = false
    @State private var floatingHearts: [FloatingHeart] = []
    @State private var wiggleRotation: Double = 0
    
    struct FloatingHeart: Identifiable {
        let id = UUID()
        var offset: CGSize = .zero
        var opacity: Double = 1.0
        var scale: CGFloat = 0.5
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                    
                    Image(systemName: "phone.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(wiggleRotation))
                }
                
                ZStack {
                    ForEach(floatingHearts) { heart in
                        Image(systemName: "heart.fill")
                            .font(.system(size: 30))
                            .foregroundColor(StoryOnboardingTheme.primaryRed)
                            .scaleEffect(heart.scale)
                            .opacity(heart.opacity)
                            .offset(heart.offset)
                    }
                }
            }
            .frame(height: 280)
        }
        .onAppear {
            startWiggleAnimation()
            isInteractionComplete = true
        }
    }
    
    private func startWiggleAnimation() {
        withAnimation(
            .easeInOut(duration: 0.1)
            .repeatForever(autoreverses: true)
        ) {
            wiggleRotation = 15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(
                .easeInOut(duration: 0.1)
                .repeatForever(autoreverses: true)
            ) {
                wiggleRotation = -15
            }
        }
    }
    
    private func startHeartAnimation() {
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                let newHeart = FloatingHeart()
                floatingHearts.append(newHeart)
                
                let randomX = CGFloat.random(in: -60...60)
                let randomRotation = Double.random(in: -15...15)
                
                withAnimation(.easeOut(duration: 1.2)) {
                    if let index = floatingHearts.firstIndex(where: { $0.id == newHeart.id }) {
                        floatingHearts[index].offset = CGSize(width: randomX, height: -120)
                        floatingHearts[index].scale = 1.2
                        floatingHearts[index].opacity = 0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    floatingHearts.removeAll { $0.id == newHeart.id }
                }
            }
        }
    }
}

#Preview {
    Scene2PhoneCallView(isInteractionComplete: .constant(false))
        .padding()
        .background(StoryOnboardingTheme.backgroundBlush)
}
