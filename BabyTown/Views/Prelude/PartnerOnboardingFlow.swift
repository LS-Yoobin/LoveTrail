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

// MARK: - Shared Components

private struct OnboardingContinueButton: View {
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Continue")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            isEnabled
                                ? BabyTownTheme.buttonGradient
                                : LinearGradient(
                                    colors: [Color(.systemGray4), Color(.systemGray4).opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .shadow(
                            color: isEnabled ? BabyTownTheme.accent.opacity(0.3) : .clear,
                            radius: 12, y: 6
                        )
                )
        }
        .disabled(!isEnabled)
        .padding(.horizontal, 40)
        .padding(.bottom, 52)
        .animation(.easeInOut(duration: 0.3), value: isEnabled)
    }
}

// MARK: - Step Stubs (replaced in Tasks 8-11)

private struct PartnerUsernameStep: View {
    var onContinue: (String) -> Void

    @State private var username = ""
    @FocusState private var isFieldFocused: Bool

    private var trimmed: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canContinue: Bool { !trimmed.isEmpty }

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

                Text("What should we call you?")
                    .font(.system(size: 26, weight: .light, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                TextField("Your nickname", text: $username)
                    .textContentType(.nickname)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.continue)
                    .focused($isFieldFocused)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemGray6))
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    )
                    .padding(.horizontal, 40)
                    .onSubmit { if canContinue { onContinue(trimmed) } }

                Spacer()

                OnboardingContinueButton(isEnabled: canContinue) {
                    if canContinue { onContinue(trimmed) }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFieldFocused = true }
        }
    }
}

private struct PartnerEmailStep: View {
    var onContinue: (String) -> Void

    @State private var email = ""
    @FocusState private var isFieldFocused: Bool

    private var trimmed: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canContinue: Bool { !trimmed.isEmpty }

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

                VStack(spacing: 14) {
                    Text("Where can we reach you?")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("For account recovery when we launch")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.continue)
                    .focused($isFieldFocused)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemGray6))
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    )
                    .padding(.horizontal, 40)
                    .onSubmit { if canContinue { onContinue(trimmed) } }

                Spacer()

                OnboardingContinueButton(isEnabled: canContinue) {
                    if canContinue { onContinue(trimmed) }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFieldFocused = true }
        }
    }
}

private struct PartnerPhotoStep: View {
    var onContinue: (UIImage?) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

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

                VStack(spacing: 14) {
                    Text("Add a photo of yourself")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Your partner will see this")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 120)

                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(BabyTownTheme.accent)
                        }
                    }
                }
                .onChange(of: pickerItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        onContinue(selectedImage)
                    } label: {
                        Text("Continue")
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

                    Button {
                        onContinue(nil)
                    } label: {
                        Text("Skip")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .padding(.bottom, 52)
            }
        }
    }
}

private struct PartnerGiftRevealStep: View {
    let inviterName: String
    var onComplete: () -> Void
    var body: some View { Color.clear }
}
