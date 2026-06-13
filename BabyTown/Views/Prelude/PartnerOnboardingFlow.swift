import SwiftUI
import PhotosUI

struct PartnerOnboardingFlow: View {
    let inviterName: String
    var onComplete: () -> Void

    private enum Step: Equatable {
        case welcome, username, email, profilePhoto, colorTheme, giftReveal
    }

    @State private var step: Step = .welcome

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                welcomeStep
                    .transition(.opacity)
            case .username:
                PartnerUsernameStep { username in
                    DataPersistenceManager.shared.saveUserNickname(username)
                    advance()
                }
                .transition(.opacity)
            case .email:
                PartnerEmailStep { email in
                    DataPersistenceManager.shared.savePartnerEmail(email)
                    advance()
                }
                .transition(.opacity)
            case .profilePhoto:
                PartnerPhotoStep { image in
                    if let image {
                        DataPersistenceManager.shared.savePartnerProfilePhoto(image)
                    }
                    advance()
                }
                .transition(.opacity)
            case .colorTheme:
                ColorThemeView(
                    onBack: {},
                    onContinue: { theme in
                        ThemeManager.shared.setTheme(theme)
                        advance()
                    }
                )
                .transition(.opacity)
            case .giftReveal:
                PartnerGiftRevealStep(
                    inviterName: inviterName,
                    onComplete: onComplete
                )
                .transition(.opacity)
            }
        }
    }

    private func advance() {
        let next: Step?
        switch step {
        case .welcome:      next = .username
        case .username:     next = .email
        case .email:        next = .profilePhoto
        case .profilePhoto: next = .colorTheme
        case .colorTheme:   next = .giftReveal
        case .giftReveal:   next = nil
        }
        if let next {
            withAnimation(.easeInOut(duration: 0.4)) { step = next }
        } else {
            onComplete()
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        ZStack {
            LinearGradient(
                colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                BookFlipView(animating: true, frameInterval: 0.18, size: 160)
                    .padding(.bottom, 40)

                VStack(spacing: 14) {
                    Text("\(inviterName) wants to share something with you")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("A private Prelude, just for you")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                Button(action: advance) {
                    Text("Open it")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(BabyTownTheme.buttonGradient)
                                .shadow(color: BabyTownTheme.accent.opacity(0.3), radius: 12, y: 6)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 52)
            }
        }
    }
}

// MARK: - Step Stubs (replaced in Tasks 8-11)

private struct PartnerUsernameStep: View {
    var onContinue: (String) -> Void
    var body: some View { Color.clear }
}

private struct PartnerEmailStep: View {
    var onContinue: (String) -> Void
    var body: some View { Color.clear }
}

private struct PartnerPhotoStep: View {
    var onContinue: (UIImage?) -> Void
    var body: some View { Color.clear }
}

private struct PartnerGiftRevealStep: View {
    let inviterName: String
    var onComplete: () -> Void
    var body: some View { Color.clear }
}
