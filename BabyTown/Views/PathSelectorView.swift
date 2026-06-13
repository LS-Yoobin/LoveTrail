import SwiftUI

struct PathSelectorView: View {

    var onBack: () -> Void
    var onSelectPrelude: () -> Void
    var onSelectOfficial: () -> Void

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Where are you right now?")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("We will set things up just right for you.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 80)

                Spacer()

                VStack(spacing: 16) {
                    PathCard(
                        icon: "envelope.heart.fill",
                        title: "Prelude",
                        description: "There is someone special on your mind. Not official yet.",
                        action: selectPrelude
                    )

                    PathCard(
                        icon: "heart.circle.fill",
                        title: "Already Official",
                        description: "You are in a relationship and ready to build your shared space.",
                        action: selectOfficial
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                contentOpacity = 1.0
            }
        }
        .onboardingBackButton(action: onBack)
    }

    private func selectPrelude() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSelectPrelude()
    }

    private func selectOfficial() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSelectOfficial()
    }
}

private struct PathCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(BabyTownTheme.accent)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(BabyTownTheme.accent.opacity(0.1)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(BabyTownTheme.accent.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PathSelectorView(
        onBack: { print("back") },
        onSelectPrelude: { print("prelude") },
        onSelectOfficial: { print("official") }
    )
}
