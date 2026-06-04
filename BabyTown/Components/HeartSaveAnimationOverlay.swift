import SwiftUI

struct HeartSaveAnimationOverlay: View {
    
    @State private var hearts: [AnimatedHeart] = []
    @State private var opacity: Double = 0
    
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
                .opacity(opacity)
            
            ForEach(hearts.indices, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: hearts[index].size))
                    .foregroundStyle(hearts[index].color)
                    .offset(x: hearts[index].x, y: hearts[index].y)
                    .opacity(hearts[index].opacity)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        withAnimation(.easeIn(duration: 0.2)) {
            opacity = 1.0
        }
        
        let heartCount = 15
        let screenWidth: CGFloat = 400
        let screenHeight: CGFloat = 800
        
        for i in 0..<heartCount {
            let delay = Double(i) * 0.08
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let heart = AnimatedHeart(
                    id: UUID(),
                    x: CGFloat.random(in: -screenWidth/2...screenWidth/2),
                    y: screenHeight / 2,
                    size: CGFloat.random(in: 20...40),
                    color: Bool.random() ? BabyTownTheme.accentDeep : BabyTownTheme.accent,
                    opacity: 1.0
                )
                
                hearts.append(heart)
                
                withAnimation(.easeOut(duration: 1.2)) {
                    if let index = hearts.firstIndex(where: { $0.id == heart.id }) {
                        hearts[index].y = -screenHeight / 2 - 100
                        hearts[index].opacity = 0.0
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onComplete()
        }
    }
}

private struct AnimatedHeart: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
}
