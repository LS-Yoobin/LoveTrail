import SwiftUI

struct BabyTownWelcomeCardDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var showLetter = false
    @State private var iconPulse = false

    private var userNickname: String {
        let name = DataPersistenceManager.shared.loadUserNickname()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return "you" }
        return name
    }

    private let message = """
    BabyTown is your shared space to document life's moments with your partner.

    We'll help you find meaningful moments from your photo library, or you can use our camera to capture new ones as they happen.

    Save what matters, revisit what you love, and build your story together — one moment at a time.
    """

    var body: some View {
        ZStack {
            BabyTownTheme.backgroundGradient
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
                iconPulse = true
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
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.3))
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(BabyTownTheme.accent)
                .scaleEffect(iconPulse ? 1.15 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Letter Card

    private var letterCard: some View {
        BabyTownLetterCardStyle.letterChrome(cornerRadius: 20, canvasWidth: BabyTownLetterCardStyle.referenceCanvasWidth) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome to Covela")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("For \(userNickname),")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.85))

                Rectangle()
                    .fill(BabyTownTheme.accent.opacity(0.3))
                    .frame(height: 1)

                Text(message)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.8))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
        }
        .scaleEffect(showLetter ? 1.0 : 0.9)
        .opacity(showLetter ? 1.0 : 0.0)
    }
}

#Preview {
    BabyTownWelcomeCardDetailView()
}
