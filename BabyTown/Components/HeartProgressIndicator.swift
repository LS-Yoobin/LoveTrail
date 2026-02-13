import SwiftUI

struct HeartProgressIndicator: View {
    let totalScenes: Int
    let currentScene: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<totalScenes, id: \.self) { index in
                Image(systemName: index < currentScene ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundColor(index < currentScene ? StoryOnboardingTheme.primaryRed : StoryOnboardingTheme.accentPink.opacity(0.4))
                    .scaleEffect(index == currentScene ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentScene)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        HeartProgressIndicator(totalScenes: 5, currentScene: 0)
        HeartProgressIndicator(totalScenes: 5, currentScene: 2)
        HeartProgressIndicator(totalScenes: 5, currentScene: 5)
    }
    .padding()
    .background(StoryOnboardingTheme.backgroundBlush)
}
