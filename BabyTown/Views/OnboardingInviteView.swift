import SwiftUI

struct OnboardingInviteView: View {
    var onBack: () -> Void
    var onSkip: () -> Void
    var onPartnerJoined: (_ captures: [PreludeCapture], _ revealerName: String) -> Void
    /// Called instead of showing an error when the backend says this account
    /// is already an official couple (local onboarding state was stale).
    var onAlreadyPaired: () -> Void = {}

    private enum InviteState {
        case choosingAction
        case pending(code: String)
        case enteringPartnerEmail(code: String)
        case enteringCode
    }

    @State private var state: InviteState = .choosingAction
    @State private var partnerEmailInput = ""
    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var codeError: String? = nil
    @State private var emailError: String? = nil
    @State private var choosingActionError: String? = nil
    @State private var codeCopied = false
    @State private var pollTimer: Timer? = nil
    @StateObject private var preludeViewModel = PreludeViewModel()
    @FocusState private var codeFocused: Bool
    @FocusState private var partnerEmailFocused: Bool

    private var inviterName: String {
        DataPersistenceManager.shared.loadUserNickname() ?? "You"
    }

    var body: some View {
        ZStack {
            background

            FloatingHeartsView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                switch state {
                case .choosingAction:
                    choosingActionContent
                case .enteringPartnerEmail(let code):
                    enteringPartnerEmailContent(code: code)
                case .pending(let code):
                    pendingContent(code: code)
                case .enteringCode:
                    enteringCodeContent
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.35), value: stateTag)
        }
        .onboardingBackButton(action: handleBack)
        .onDisappear { stopPolling() }
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.partnerInviteAcceptedNotificationName)) { _ in
            if case .pending(let code) = state {
                Task { await checkForAcceptance(code: code) }
            }
        }
    }

    private var background: some View {
        ZStack {
            BabyTownTheme.backgroundCream

            VStack(spacing: 0) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.76, blue: 0.68).opacity(0.36),
                                Color(red: 0.72, green: 0.82, blue: 1.0).opacity(0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 360, height: 120)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -70, y: 58)

                Spacer()

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.86, blue: 0.46).opacity(0.22),
                                BabyTownTheme.accent.opacity(0.16)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 420, height: 150)
                    .rotationEffect(.degrees(14))
                    .offset(x: 95, y: -44)
            }

            VStack {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.14))
                        .offset(x: 34, y: 86)
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color(red: 0.94, green: 0.57, blue: 0.16).opacity(0.16))
                        .offset(x: -36, y: 132)
                }
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var stateTag: Int {
        switch state {
        case .choosingAction: return 0
        case .enteringPartnerEmail: return 1
        case .pending: return 2
        case .enteringCode: return 3
        }
    }

    private var trimmedPartnerEmail: String {
        partnerEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isPartnerEmailValid: Bool {
        AuthService.shared.isValidEmail(trimmedPartnerEmail)
    }

    // MARK: State A — Choose action

    private var choosingActionContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Connect with your partner")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Choose how you want to get started.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 14) {
                InviteActionCard(
                    icon: "key.fill",
                    title: "Invite your partner",
                    subtitle: "Get a code to share. They enter it and you are connected."
                ) {
                    Task { await generateCode() }
                }

                InviteActionCard(
                    icon: "checkmark.circle.fill",
                    title: "I have a code",
                    subtitle: "Enter the code your partner shared with you."
                ) {
                    withAnimation { state = .enteringCode }
                }
            }

            if isLoading {
                VStack(spacing: 6) {
                    ProgressView()
                    if let progress = preludeViewModel.invitePrepProgress {
                        Text("Uploading your gift… \(progress.completed)/\(progress.total)")
                            .font(.system(size: 13))
                            .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.72))
                    }
                }
            }

            if let err = choosingActionError {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: State B — Partner email (secondary path, code already generated)

    private func enteringPartnerEmailContent(code: String) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Where should we send the invite?")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Your partner will get an email with your code and a link to download Covela.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 8) {
                TextField("partner@email.com", text: $partnerEmailInput)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .font(.system(size: 17))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(BabyTownTheme.cardTintLight)
                            .shadow(color: BabyTownTheme.accent.opacity(0.08), radius: 8, y: 4)
                    )
                    .focused($partnerEmailFocused)
                    .onChange(of: partnerEmailInput) { _, _ in
                        emailError = nil
                    }
                    .onSubmit {
                        if isPartnerEmailValid {
                            Task { await sendEmail(code: code, partnerEmail: trimmedPartnerEmail) }
                        }
                    }
                    .onAppear { partnerEmailFocused = true }

                if let err = emailError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }

            Button {
                Task { await sendEmail(code: code, partnerEmail: trimmedPartnerEmail) }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(isPartnerEmailValid ? BabyTownTheme.accentGradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                )
            }
            .disabled(!isPartnerEmailValid || isLoading)

            Text("We only use this to send the invite. Nothing else.")
                .font(.system(size: 13))
                .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: State C — Pending

    private func pendingContent(code: String) -> some View {
        VStack(spacing: 28) {
            PulsingRingsView()
                .frame(width: 160, height: 160)

            VStack(spacing: 10) {
                Text("Your invite code is ready")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Share this code with your partner however you like. We will let you know the moment they join.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Text(code)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(BabyTownTheme.accentDeep)
                .tracking(4)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BabyTownTheme.cardTintLight)
                )

            Button {
                ActivitySharePresenter.present(text: shareMessage(code: code))
            } label: {
                Text("Share code")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(BabyTownTheme.accentGradient))
            }

            VStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { codeCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { codeCopied = false }
                    }
                } label: {
                    Text(codeCopied ? "Copied!" : "Copy invite code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                }

                Button {
                    partnerEmailInput = DataPersistenceManager.shared.loadPartnerEmail() ?? ""
                    emailError = nil
                    withAnimation { state = .enteringPartnerEmail(code: code) }
                } label: {
                    Text("Send by email instead")
                        .font(.system(size: 14))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.65))
                }

                Button {
                    stopPolling()
                    onSkip()
                } label: {
                    Text("Continue to your space")
                        .font(.system(size: 14))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.65))
                }
            }
        }
    }

    private func shareMessage(code: String) -> String {
        "Join me on Covela! Use my invite code: \(code)"
    }

    // MARK: State D — Enter code

    private var enteringCodeContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Enter your code")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Enter the 6 character code from the invite email.")
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
                        .foregroundStyle(.gray.opacity(0.75))
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
    }

    // MARK: Actions

    private func generateCode() async {
        guard !isLoading else { return }
        guard AuthService.shared.isSignedIn else {
            choosingActionError = "Please sign in to create an invite."
            return
        }
        isLoading = true
        choosingActionError = nil
        do {
            let giftCaptureIds = try await preludeViewModel.syncGiftCapturesForInvite()
            let response = try await InviteAPI.client.createInvite(
                inviterName: inviterName,
                giftCaptureIds: giftCaptureIds
            )
            DataPersistenceManager.shared.setPendingPartnerInvite(true)
            DataPersistenceManager.shared.savePendingInviteCode(response.code)
            withAnimation { state = .pending(code: response.code) }
            startPolling(code: response.code)
        } catch {
            if InviteErrorMapper.isAlreadyPaired(error) {
                onAlreadyPaired()
            } else {
                choosingActionError = InviteErrorMapper.message(for: error)
            }
        }
        isLoading = false
    }

    private func sendEmail(code: String, partnerEmail: String) async {
        guard isPartnerEmailValid, !isLoading else { return }
        isLoading = true
        do {
            try await InviteAPI.client.sendInviteEmail(
                partnerEmail: partnerEmail,
                inviterName: inviterName,
                code: code
            )
            DataPersistenceManager.shared.savePartnerEmail(partnerEmail)
            withAnimation { state = .pending(code: code) }
        } catch {
            emailError = InviteErrorMapper.message(for: error)
        }
        isLoading = false
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
            onPartnerJoined(captures, revealerName)
        case .failure(let message, let alreadyPaired):
            if alreadyPaired {
                onAlreadyPaired()
            } else {
                codeError = message
            }
        }
        isLoading = false
    }

    private func startPolling(code: String) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { await checkForAcceptance(code: code) }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkForAcceptance(code: String) async {
        guard let status = try? await InviteAPI.client.checkInviteStatus(code: code) else { return }
        if status.status == .accepted {
            stopPolling()
            var profile = DataPersistenceManager.shared.loadCoupleProfile()
            profile.relationshipStage = .officialCouple
            DataPersistenceManager.shared.saveCoupleProfile(profile)
            let revealerName = DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "Your partner"
            DataPersistenceManager.shared.clearPendingInviteState()
            DataPersistenceManager.shared.recordPreludeChapterIfNeeded()
            // The inviter's poll never receives gift captures — only the invitee's accept-invite call does.
            onPartnerJoined([], revealerName)
        }
    }

    private func handleBack() {
        switch state {
        case .choosingAction:
            onBack()
        case .pending:
            stopPolling()
            withAnimation { state = .choosingAction }
        case .enteringPartnerEmail(let code):
            emailError = nil
            withAnimation { state = .pending(code: code) }
        case .enteringCode:
            withAnimation { state = .choosingAction }
        }
    }
}

// MARK: - Subviews

private struct InviteActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(BabyTownTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(BabyTownTheme.accent.opacity(0.1)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.68))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.55))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BabyTownTheme.cardTintLight, BabyTownTheme.cardTintDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: BabyTownTheme.accent.opacity(0.12), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BabyTownTheme.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Three concentric rings that expand outward in a loop.
private struct PulsingRingsView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(BabyTownTheme.accentDeep.opacity(animate ? 0.0 : [0.35, 0.22, 0.10][i]), lineWidth: 2)
                    .scaleEffect(animate ? 1.6 + CGFloat(i) * 0.3 : 0.6)
                    .animation(
                        .easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.5),
                        value: animate
                    )
            }

            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.accentDeep)
        }
        .onAppear { animate = true }
    }
}

#Preview("Choose action") {
    OnboardingInviteView(onBack: {}, onSkip: {}, onPartnerJoined: { _, _ in })
}

#Preview("Pending") {
    OnboardingInviteView(onBack: {}, onSkip: {}, onPartnerJoined: { _, _ in })
}
