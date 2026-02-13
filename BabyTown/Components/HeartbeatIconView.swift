import SwiftUI

struct HeartbeatIconView: View {
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 20))
            .foregroundStyle(BabyTownTheme.accent)
            .scaleEffect(scale)
            .onAppear {
                startHeartbeat()
            }
    }
    
    private func startHeartbeat() {
        withAnimation(
            .easeInOut(duration: 0.3)
            .repeatForever(autoreverses: true)
        ) {
            scale = 1.2
        }
    }
}
