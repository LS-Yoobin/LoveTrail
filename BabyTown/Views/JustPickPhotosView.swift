import SwiftUI

struct JustPickPhotosView: View {
    let officialPhoto: UIImage
    let firstMetPhoto: UIImage?
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                polaroidCollage
                    .padding(.bottom, 40)

                VStack(spacing: 10) {
                    Text("Just pick photos of us.")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Covela does the rest.")
                        .font(.system(size: 18))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
                .padding(.horizontal, 28)

                Spacer()

                Button(action: onContinue) {
                    Text("Let's go")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(BabyTownTheme.accentGradient)
                                .shadow(color: BabyTownTheme.accent.opacity(0.3), radius: 12, y: 6)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private var polaroidCollage: some View {
        ZStack {
            if let firstMet = firstMetPhoto {
                PolaroidCard(image: firstMet, rotation: -6)
                    .offset(x: -30, y: 10)

                PolaroidCard(image: officialPhoto, rotation: 5)
                    .offset(x: 30, y: -10)
            } else {
                PolaroidCard(image: officialPhoto, rotation: 0)
            }
        }
        .frame(height: 260)
    }
}

private struct PolaroidCard: View {
    let image: UIImage
    let rotation: Double

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 160)
                .clipped()

            Color.clear.frame(height: 30)
        }
        .frame(width: 180, height: 200)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    JustPickPhotosView(
        officialPhoto: UIImage(systemName: "heart.fill")!,
        firstMetPhoto: UIImage(systemName: "star.fill")!,
        onContinue: {}
    )
}
