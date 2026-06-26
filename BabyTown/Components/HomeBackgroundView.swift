import SwiftUI

/// Background view that switches between day and night modes
struct HomeBackgroundView: View {
    
    let isNightMode: Bool
    
    var body: some View {
        ZStack {
            if isNightMode {
                // Night mode: Deep blue gradient with stars
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.15),
                        Color(red: 0.1, green: 0.15, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .transition(.opacity)
                
                StarFieldView()
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                ShootingStarView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                // Day mode: solid white so the flower video blends cleanly at the bottom
                BabyTownTheme.background
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
    }
}
