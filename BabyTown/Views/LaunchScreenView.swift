import SwiftUI

/// Custom launch screen with cat image and loading animation
struct LaunchScreenView: View {
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.95, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Cat image with animation
                Image("First Page Cat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                // Loading animation
                VStack(spacing: 16) {
                    // Pulsing dots
                    PulsingDotsLoader()
                    
                    Text("Loading BabyTown...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.gray.opacity(0.8))
                        .opacity(opacity)
                }
                
                Spacer()
            }
        }
        .onAppear {
            // Animate cat image entrance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
