import SwiftUI

/// Reserved for future Valentine's Day use. Active in-app card: `BabyTownWelcomeCardDetailView`.
struct ValentineCardDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var showLetter = false
    @State private var heartBeat = false

    private let accentColor = BabyTownTheme.accent

    private let message = """
    Happy Valentine's Day \u{2764}\u{FE0F}

    Thank you for always being my comfort, my safe place, and the person I want to share all my days with, even the ordinary ones. Life feels warmer, lighter, and more meaningful because you're in it.

    No matter where we go or what we're doing, being with you is my favorite place.

    I love you more than words can properly hold, but I hope this little card can remind you today and every day.

    Much Love,
    Mapaba (Yoobin)
    """

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.92, blue: 0.94)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        letterCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        Image("First Page Cat")
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 40)
                            .padding(.top, 8)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showLetter = true
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                heartBeat = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.black.opacity(0.3))
            }

            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundStyle(accentColor)
                .scaleEffect(heartBeat ? 1.15 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Letter Card

    private var letterCard: some View {
        ZStack {
            stickerDecoration(icon: "heart.fill", rotation: -12, x: -8, y: -8, alignment: .topLeading)
            stickerDecoration(icon: "heart.fill", rotation: 10, x: 8, y: -8, alignment: .topTrailing)
            stickerDecoration(icon: "star.fill", rotation: -8, x: -8, y: 8, alignment: .bottomLeading)
            stickerDecoration(icon: "sparkles", rotation: 14, x: 8, y: 8, alignment: .bottomTrailing)

            VStack(alignment: .leading, spacing: 16) {
                Text("To Jinky,")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.black)

                Rectangle()
                    .fill(accentColor.opacity(0.3))
                    .frame(height: 1)

                Text(message)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(.black.opacity(0.8))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: accentColor.opacity(0.15), radius: 20, y: 8)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(accentColor.opacity(0.15), lineWidth: 1)
            )
        }
        .scaleEffect(showLetter ? 1.0 : 0.9)
        .opacity(showLetter ? 1.0 : 0.0)
    }

    // MARK: - Sticker Decorations

    private func stickerDecoration(icon: String, rotation: Double, x: CGFloat, y: CGFloat, alignment: Alignment) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.7))
                .frame(width: 30, height: 12)
                .rotationEffect(.degrees(rotation * 0.5))
                .offset(y: -18)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(accentColor.opacity(0.6))
            }
        }
        .rotationEffect(.degrees(rotation))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .offset(x: x, y: y)
    }
}

#Preview {
    ValentineCardDetailView()
}
