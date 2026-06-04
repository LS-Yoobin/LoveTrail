import SwiftUI

/// Reusable pulsing dots loading animation component
struct PulsingDotsLoader: View {
    
    @State private var isAnimating = false
    
    var dotColor: Color = BabyTownTheme.accent.opacity(0.7)
    var dotSize: CGFloat = 12
    var spacing: CGFloat = 12
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        PulsingDotsLoader()
        
        PulsingDotsLoader(dotColor: .blue, dotSize: 16, spacing: 16)
        
        PulsingDotsLoader(dotColor: .purple.opacity(0.6), dotSize: 8, spacing: 8)
    }
}
