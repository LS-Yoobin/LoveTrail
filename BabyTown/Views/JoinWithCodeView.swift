import SwiftUI

/// Standalone code-redemption screen shown right after birthday, before the
/// user picks Prelude vs Already Official — lets someone who already has a
/// partner's code connect immediately instead of setting up their own space first.
struct JoinWithCodeView: View {
    var onBack: () -> Void
    var onJoined: (_ captures: [PreludeCapture], _ revealerName: String) -> Void
    /// Called instead of showing an error when the backend says this account
    /// is already an official couple (local onboarding state was stale).
    var onAlreadyPaired: () -> Void = {}

    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var codeError: String? = nil
    @FocusState private var codeFocused: Bool

    var body: some View {
        ZStack {
            BabyTownTheme.backgroundCream
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Enter your code")
                            .font(.system(size: 31, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(BabyTownTheme.textPrimary)

                        Text("Enter the 6 character code your partner shared with you.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.66))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    VStack(spacing: 8) {
                        TextField(
                            "",
                            text: $codeInput,
                            prompt: Text("Enter your 6 character code")
                                .foregroundStyle(BabyTownTheme.textSecondary)
                        )
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundStyle(BabyTownTheme.accentDeep)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(BabyTownTheme.cardTintLight)
                                    .shadow(color: BabyTownTheme.accent.opacity(0.08), radius: 8, y: 4)
                            )
                            .focused($codeFocused)
                            .onChange(of: codeInput) { _, new in
                                codeInput = String(new.prefix(6))
                                codeError = nil
                            }
                            .onAppear { codeFocused = true }

                        if let err = codeError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }

                    Button {
                        Task { await joinWithCode() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Join")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(codeInput.count == 6 ? BabyTownTheme.accentGradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                        )
                    }
                    .disabled(codeInput.count < 6 || isLoading)
                }

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onboardingBackButton(action: onBack)
    }

    private func joinWithCode() async {
        guard codeInput.count == 6, !isLoading else { return }
        guard AuthService.shared.isSignedIn else {
            codeError = "Please sign in to join."
            return
        }
        isLoading = true
        switch await InviteJoinFlow.join(code: codeInput) {
        case .joined(let captures, let revealerName):
            onJoined(captures, revealerName)
        case .failure(let message, let alreadyPaired):
            if alreadyPaired {
                onAlreadyPaired()
            } else {
                codeError = message
            }
        }
        isLoading = false
    }
}

#Preview {
    JoinWithCodeView(onBack: {}, onJoined: { _, _ in })
}
