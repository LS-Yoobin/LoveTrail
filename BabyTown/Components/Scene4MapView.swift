import SwiftUI

struct Scene4MapView: View {
    @Binding var isInteractionComplete: Bool
    @State private var pathProgress: CGFloat = 0
    @State private var showSafeZone = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.15), Color.teal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 280, height: 280)
                
                VStack(spacing: 30) {
                    ZStack(alignment: .topLeading) {
                        Path { path in
                            path.move(to: CGPoint(x: 30, y: 30))
                            path.addLine(to: CGPoint(x: 80, y: 80))
                            path.addLine(to: CGPoint(x: 130, y: 60))
                            path.addLine(to: CGPoint(x: 180, y: 100))
                        }
                        .trim(from: 0, to: pathProgress)
                        .stroke(StoryOnboardingTheme.primaryRed, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 210, height: 130)
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                            .offset(x: 22, y: 22)
                        
                        if showSafeZone {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                            }
                            .offset(x: 155, y: 75)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 20))
                            .foregroundColor(StoryOnboardingTheme.primaryRed)
                            .offset(x: getCarPosition().x, y: getCarPosition().y)
                    }
                    .frame(width: 210, height: 130)
                    
                    Button(action: navigate) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18))
                            Text("Navigate")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(isInteractionComplete ? Color.gray : StoryOnboardingTheme.primaryRed)
                        )
                    }
                    .disabled(isInteractionComplete)
                }
            }
            .frame(height: 280)
        }
    }
    
    private func navigate() {
        guard !isInteractionComplete else { return }

        AudioManager.shared.playCarDoorThenEngine()

        withAnimation(.easeInOut(duration: 2.0)) {
            pathProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showSafeZone = true
            }
            isInteractionComplete = true
        }
    }
    
    private func getCarPosition() -> CGPoint {
        if pathProgress == 0 {
            return CGPoint(x: 22, y: 22)
        } else if pathProgress < 0.33 {
            let t = pathProgress / 0.33
            return CGPoint(
                x: 22 + (58 * t),
                y: 22 + (58 * t)
            )
        } else if pathProgress < 0.66 {
            let t = (pathProgress - 0.33) / 0.33
            return CGPoint(
                x: 80 + (50 * t),
                y: 80 - (20 * t)
            )
        } else {
            let t = (pathProgress - 0.66) / 0.34
            return CGPoint(
                x: 130 + (50 * t),
                y: 60 + (40 * t)
            )
        }
    }
}

#Preview {
    Scene4MapView(isInteractionComplete: .constant(false))
        .padding()
        .background(StoryOnboardingTheme.backgroundBlush)
}
