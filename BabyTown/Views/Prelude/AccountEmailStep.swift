import SwiftUI

struct AccountEmailStep: View {
    @Binding var email: String
    var onContinue: () -> Void
    var onCancel: () -> Void

    @FocusState private var emailFocused: Bool
    @State private var hasBlurred: Bool = false

    private var nickname: String {
        DataPersistenceManager.shared.loadUserNickname() ?? "you"
    }

    private var isEmailValid: Bool {
        let parts = email.split(separator: "@")
        return parts.count == 2 && (parts.last?.contains(".") == true)
    }

    private var showValidationHint: Bool {
        hasBlurred && !isEmailValid && !email.isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            BabyTownTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: cancel + progress
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Icon
                        envelopeIcon
                            .padding(.top, 32)

                        // Title
                        Text("Create your account")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                            .padding(.horizontal, 32)

                        // Subtitle
                        Text("Your username is already set. Just add your email.")
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .padding(.horizontal, 32)

                        // Read-only username chip
                        usernameChip
                            .padding(.top, 24)
                            .padding(.horizontal, 32)

                        // Email field + validation hint
                        emailSection
                            .padding(.top, 20)
                            .padding(.horizontal, 32)

                        Spacer(minLength: 32)
                    }
                }

                // Bottom: CTA + footer
                bottomSection
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                    .padding(.top, 8)
                    .background(BabyTownTheme.background)
            }
        }
        .onAppear {
            emailFocused = true
        }
        .onChange(of: emailFocused) { _, focused in
            if !focused {
                hasBlurred = true
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(.systemGray6)))
            }
            .buttonStyle(.plain)

            Spacer()

            stepDots
        }
    }

    // MARK: - 2-dot step indicator

    private var stepDots: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(BabyTownTheme.accent)
                .frame(width: 8, height: 8)
            Circle()
                .fill(BabyTownTheme.accent.opacity(0.25))
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Envelope icon

    private var envelopeIcon: some View {
        ZStack {
            Circle()
                .fill(BabyTownTheme.accent.opacity(0.12))
                .frame(width: 80, height: 80)

            Image(systemName: "envelope.fill")
                .font(.system(size: 32))
                .foregroundStyle(BabyTownTheme.accent)
        }
    }

    // MARK: - Username chip

    private var usernameChip: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("@\(nickname)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accentDeep)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(BabyTownTheme.accent.opacity(0.15))
                )
            Spacer()
        }
    }

    // MARK: - Email field + hint

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("you@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($emailFocused)
                .font(.system(size: 16))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    showValidationHint
                                        ? Color.orange.opacity(0.6)
                                        : (emailFocused ? BabyTownTheme.accent.opacity(0.5) : Color.clear),
                                    lineWidth: 1.5
                                )
                        )
                )

            if showValidationHint {
                Text("Enter a valid email to continue.")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showValidationHint)
    }

    // MARK: - Bottom section

    private var bottomSection: some View {
        VStack(spacing: 14) {
            continueButton

            Text("Used to connect with your partner. We'll never share it.")
                .font(.system(size: 12))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            onContinue()
        } label: {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background {
                    if isEmailValid {
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                            .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 12, y: 5)
                    } else {
                        Capsule()
                            .fill(Color(.systemGray4))
                    }
                }
        }
        .disabled(!isEmailValid)
        .animation(.easeInOut(duration: 0.25), value: isEmailValid)
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var email = ""
    AccountEmailStep(
        email: $email,
        onContinue: { print("continue, email: \(email)") },
        onCancel: { print("cancel") }
    )
}
