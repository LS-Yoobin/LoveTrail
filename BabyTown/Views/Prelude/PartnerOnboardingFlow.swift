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
                PartnerGiftRevealStep(onComplete: advance)
                    .transition(.opacity)
            }
        }
    }

    private func advance() {
        let next: Step?
        switch step {
        case .welcome:      next = .giftReveal
        case .giftReveal:   next = .username
        case .username:     next = .email
        case .email:        next = .profilePhoto
        case .profilePhoto: next = .colorTheme
        case .colorTheme:   next = nil
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

                BookFlipView(animating: true, size: 160)
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
    @State private var loadTask: Task<Void, Never>?

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
                    loadTask?.cancel()
                    guard let newItem else { return }
                    loadTask = Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    OnboardingContinueButton(isEnabled: true) {
                        onContinue(selectedImage)
                    }

                    Button {
                        onContinue(nil)
                    } label: {
                        Text("Skip")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .padding(.bottom, 52)
                }
            }
        }
    }
}

private struct PartnerGiftRevealStep: View {
    var onComplete: () -> Void

    @State private var captures: [PreludeCapture] = []
    @State private var currentIndex = 0
    @State private var bookScale: CGFloat = 1.0
    @State private var bookOffsetX: CGFloat = 0.0
    @State private var capturesVisible = false

    private static let parchmentGradient = LinearGradient(
        colors: [
            Color(red: 0.992, green: 0.965, blue: 0.925),
            Color(red: 0.973, green: 0.910, blue: 0.816),
            Color(red: 0.953, green: 0.875, blue: 0.753)
        ],
        startPoint: .top,
        endPoint: .bottomTrailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Self.parchmentGradient
                    .ignoresSafeArea()

                Image("BookFlip4")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160)
                    .scaleEffect(bookScale)
                    .offset(x: bookOffsetX)

                if capturesVisible {
                    ZStack {
                        ruledLines()

                        parchmentPage()
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                captures = DataPersistenceManager.shared.loadPreludeCaptures()
                    .filter { $0.isIncludedInGift && !$0.isPartnerRetroactive }
                    .sorted { $0.createdAt < $1.createdAt }

                let screenWidth = geo.size.width
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.85)) {
                        bookScale = 5.0
                        bookOffsetX = -(screenWidth * 0.255)
                    } completion: {
                        withAnimation(.easeIn(duration: 0.4)) {
                            capturesVisible = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ruled lines

    private func ruledLines() -> some View {
        Canvas { ctx, size in
            let lineCount = Int(size.height / 28) + 1
            for i in 0..<lineCount {
                let y = CGFloat(i) * 28
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(
                    path,
                    with: .color(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.06)),
                    lineWidth: 0.5
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Parchment page content

    private func parchmentPage() -> some View {
        VStack(spacing: 0) {
            if captures.count > 1 {
                Text("PAGE \(currentIndex + 1) OF \(captures.count)")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.4))
                    .tracking(2)
                    .padding(.top, 60)
            } else {
                Spacer().frame(height: 60)
            }

            Spacer()

            if captures.isEmpty {
                Text("Nothing here yet. Check back soon.")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Color(red: 0.239, green: 0.094, blue: 0.000))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                captureContent(captures[currentIndex])
            }

            Spacer()

            navigationRow
                .padding(.bottom, 52)
        }
    }

    // MARK: - Single capture display

    private func captureContent(_ capture: PreludeCapture) -> some View {
        VStack(spacing: 12) {
            Image(systemName: capture.typeIcon)
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.accent)

            Text(capture.typeLabel.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(red: 0.761, green: 0.392, blue: 0.165))
                .tracking(2)

            Text(capture.displayTitle)
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(Color(red: 0.239, green: 0.094, blue: 0.000))
                .lineSpacing(17 * 0.6)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text(capture.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(Color(red: 0.627, green: 0.439, blue: 0.314))
        }
    }

    // MARK: - Navigation row

    private var navigationRow: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { currentIndex -= 1 }
            } label: {
                Text("\u{2190} Prev Page")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(Color(red: 0.392, green: 0.235, blue: 0.078))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.10))
                    )
            }
            .opacity(currentIndex == 0 ? 0 : 1)
            .allowsHitTesting(currentIndex != 0)

            Spacer()

            if captures.isEmpty || currentIndex == captures.count - 1 {
                Button(action: onComplete) {
                    Text("Open our space")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(AnyShapeStyle(BabyTownTheme.accentGradient))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { currentIndex += 1 }
                } label: {
                    Text("Next Page \u{2192}")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.761, green: 0.392, blue: 0.165))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
    }
}
