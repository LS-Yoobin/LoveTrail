import SwiftUI

struct WelcomeView: View {

    var onContinue: () -> Void

    @State private var heartScale: CGFloat = 0.6
    @State private var heartOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.white,
                    Color.pink.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Floating hearts
            FloatingHeartsView()
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // BabyTown Logo at top
                Image("BabyTownLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .padding(.top, 60)
                    .opacity(textOpacity)
                
                Spacer()

                // Center heart
                Image("First Page Cat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
                    .shadow(
                        color: .pink.opacity(0.3),
                        radius: 20, y: 8
                    )

                // Title
                Text("Welcome to your BabyTown!")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .opacity(textOpacity)

                Spacer()

                // Continue button
                Button(action: onContinue) {
                    Text("Let's go.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.pink,
                                            Color.pink.opacity(0.8)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(
                                    color: .pink.opacity(0.3),
                                    radius: 12, y: 6
                                )
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            withAnimation(
                .spring(response: 0.8, dampingFraction: 0.6)
                .delay(0.2)
            ) {
                heartScale = 1.0
                heartOpacity = 1.0
            }

            withAnimation(
                .easeOut(duration: 0.6)
                .delay(0.6)
            ) {
                textOpacity = 1.0
            }

            withAnimation(
                .easeOut(duration: 0.6)
                .delay(1.0)
            ) {
                buttonOpacity = 1.0
            }
        }
    }
}

#Preview {
    WelcomeView {
        print("Continue tapped")
    }
}
