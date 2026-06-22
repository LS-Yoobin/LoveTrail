import SwiftUI

struct GiftRevealView: View {

    let captures: [PreludeCapture]
    let creatorName: String
    let firstCaptureDate: Date
    @ObservedObject var viewModel: PreludeViewModel
    var onComplete: () -> Void

    @State private var currentIndex: Int = 0

    private var isOnFinalCard: Bool {
        currentIndex >= captures.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BabyTownTheme.accentDeep.opacity(0.85), BabyTownTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isOnFinalCard {
                finalCard
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                captureCard(captures[currentIndex])
                    .id(currentIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: currentIndex)
        .animation(.easeInOut(duration: 0.5), value: isOnFinalCard)
    }

    private func captureCard(_ capture: PreludeCapture) -> some View {
        VStack(spacing: 0) {
            Spacer()

            GiftCardView(capture: capture)
                .padding(.horizontal, 28)

            Spacer()

            advanceButton
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
        }
    }

    private var advanceButton: some View {
        Button {
            withAnimation {
                currentIndex += 1
            }
        } label: {
            Text(currentIndex < captures.count - 1 ? "Next →" : "See what's next →")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(BabyTownTheme.accentGradient)
                )
        }
        .buttonStyle(.plain)
    }

    private var finalCard: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                Text("\(creatorName) has been writing this since \(firstCaptureDate, style: .date).")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Now you're here.")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 36)

            Spacer()

            Button {
                viewModel.transitionToOfficial()
                onComplete()
            } label: {
                Text("Start your story together →")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule().fill(.white)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    GiftRevealView(
        captures: [
            PreludeCapture(type: .note, noteText: "I keep thinking about the way you laugh."),
            PreludeCapture(type: .reason, reasonText: "The way you always order the weirdest thing on the menu.")
        ],
        creatorName: "Alex",
        firstCaptureDate: Date().addingTimeInterval(-60 * 60 * 24 * 14),
        viewModel: PreludeViewModel(),
        onComplete: {}
    )
}
