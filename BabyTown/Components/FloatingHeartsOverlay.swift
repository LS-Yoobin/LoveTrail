import SwiftUI

struct FloatingHeartOverlay: Identifiable {
    let id = UUID()
    var offset: CGFloat = 0
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var xOffset: CGFloat = 0
}

struct FloatingHeartsOverlay: View {
    @State private var hearts: [FloatingHeartOverlay] = []
    let isActive: Bool
    
    var body: some View {
        ZStack {
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundColor(StoryOnboardingTheme.primaryRed)
                    .opacity(heart.opacity)
                    .scaleEffect(heart.scale)
                    .offset(x: heart.xOffset, y: heart.offset)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                spawnHearts()
            }
        }
    }
    
    private func spawnHearts() {
        for i in 0..<8 {
            let delay = Double(i) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                var heart = FloatingHeartOverlay()
                heart.xOffset = CGFloat.random(in: -40...40)
                hearts.append(heart)
                
                withAnimation(.easeOut(duration: 2.0)) {
                    if let index = hearts.firstIndex(where: { $0.id == heart.id }) {
                        hearts[index].offset = -200
                        hearts[index].opacity = 0
                        hearts[index].scale = 1.5
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    hearts.removeAll { $0.id == heart.id }
                }
            }
        }
    }
}

#Preview {
    FloatingHeartsOverlay(isActive: true)
        .frame(width: 300, height: 400)
        .background(StoryOnboardingTheme.backgroundBlush)
}
