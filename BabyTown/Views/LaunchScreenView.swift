import SwiftUI
import SpriteKit

/// Custom launch screen with running cats and loading animation.
struct LaunchScreenView: View {

    @State private var footerOpacity: Double = 0
    @State private var scene = LaunchCatScene()

    var body: some View {
        ZStack {
            background

            VStack(spacing: 36) {
                Spacer()

                LaunchRunningCatsView(scene: scene)
                    .frame(height: 240)

                VStack(spacing: 16) {
                    PulsingDotsLoader()
                    Text("Loading BabyTown...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.gray.opacity(0.8))
                }
                .opacity(footerOpacity)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                footerOpacity = 1.0
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.98, green: 0.95, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - SpriteKit cats

struct LaunchRunningCatsView: View {
    let scene: LaunchCatScene

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: scene, options: [.allowsTransparency])
                .onAppear { configureScene(size: geometry.size) }
                .onChange(of: geometry.size) { _, newSize in
                    configureScene(size: newSize)
                }
        }
    }

    private func configureScene(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        scene.size = size
        scene.scaleMode = .resizeFill
        scene.startParadeIfNeeded()
    }
}

#Preview {
    LaunchScreenView()
}
