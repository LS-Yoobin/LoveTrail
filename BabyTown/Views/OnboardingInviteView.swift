import SwiftUI

struct OnboardingInviteView: View {
    var onBack: () -> Void
    var onSkip: () -> Void
    var onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void

    private enum InviteState {
        case choosingAction
        case enteringPartnerEmail
        case pending(code: String, partnerEmail: String)
        case enteringCode
    }

    @State private var state: InviteState = .choosingAction
    @State private var partnerEmailInput = ""
    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var codeError: String? = nil
    @State private var emailError: String? = nil
    @State private var pollTimer: Timer? = nil
    @FocusState private var codeFocused: Bool
    @FocusState private var partnerEmailFocused: Bool

    private var inviterName: String {
        DataPersistenceManager.shared.loadUserNickname() ?? "You"
    }

    var body: some View {
        ZStack {
            BabyTownTheme.backgroundCream
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                switch state {
                case .choosingAction:
                    choosingActionContent
                case .enteringPartnerEmail:
                    enteringPartnerEmailContent
                case .pending(let code, let partnerEmail):
                    pendingContent(code: code, partnerEmail: partnerEmail)
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
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.accentDeep)

                Text("Choose how you want to get started.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.72))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                InviteActionCard(
                    icon: "envelope.heart.fill",
                    title: "Invite your partner",
                    subtitle: "Send them a link. They tap it and you are connected."
                ) {
                    partnerEmailInput = DataPersistenceManager.shared.loadPartnerEmail() ?? ""
                    emailError = nil
                    withAnimation { state = .enteringPartnerEmail }
                }

                InviteActionCard(
                    icon: "key.fill",
                    title: "I have a code",
                    subtitle: "Enter the code from the email your partner sent you."
                ) {
                    withAnimation { state = .enteringCode }
                }
            }
        }
    }

    // MARK: State B — Partner email

    private var enteringPartnerEmailContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Where should we send the invite?")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.accentDeep)

                Text("Your partner will get an email with a link to download Covela.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.72))
                    .multilineTextAlignment(.center)
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
                            Task { await sendInvite(partnerEmail: trimmedPartnerEmail) }
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
                Task { await sendInvite(partnerEmail: trimmedPartnerEmail) }
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

    private func pendingContent(code: String, partnerEmail: String) -> some View {
        VStack(spacing: 28) {
            PulsingRingsView()
                .frame(width: 160, height: 160)

            VStack(spacing: 10) {
                Text("Invitation sent")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(BabyTownTheme.accentDeep)

                Text("We sent an invite to \(partnerEmail). We will let you know the moment they join.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.72))
                    .multilineTextAlignment(.center)
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
                UIPasteboard.general.string = code
            } label: {
                Text("Copy invite code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary)
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

    // MARK: State D — Enter code

    private var enteringCodeContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Enter your code")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.accentDeep)

                Text("Enter the 6 character code from the invite email.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.72))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                TextField("Enter your 6 character code", text: $codeInput)
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
                            .font(.system(size: 17, weight: .semibold))
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

    private func sendInvite(partnerEmail: String) async {
        guard isPartnerEmailValid, !isLoading else { return }
        isLoading = true
        do {
            let response = try await StubInviteAPIClient.shared.createInvite(inviterName: inviterName)
            do {
                try await StubInviteAPIClient.shared.sendInviteEmail(
                    partnerEmail: partnerEmail,
                    inviterName: inviterName,
                    code: response.code
                )
            } catch {
                // Email delivery failed — user can still share the code manually.
            }
            DataPersistenceManager.shared.savePartnerEmail(partnerEmail)
            DataPersistenceManager.shared.setPendingPartnerInvite(true)
            DataPersistenceManager.shared.savePendingInviteCode(response.code)
            withAnimation { state = .pending(code: response.code, partnerEmail: partnerEmail) }
            startPolling(code: response.code)
        } catch {
            emailError = "Something went wrong. Please try again."
        }
        isLoading = false
    }

    private func joinWithCode() async {
        guard codeInput.count == 6, !isLoading else { return }
        isLoading = true
        do {
            let response = try await StubInviteAPIClient.shared.acceptInvite(code: codeInput)
            DataPersistenceManager.shared.clearPendingInviteState()
            onPartnerJoined(response.revealCaptures, response.revealerName)
        } catch {
            codeError = "That code is not valid or has expired."
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
        guard let status = try? await StubInviteAPIClient.shared.checkInviteStatus(code: code) else { return }
        if status.status == .accepted {
            stopPolling()
            let revealerName = DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "Your partner"
            DataPersistenceManager.shared.clearPendingInviteState()
            // Stub returns empty captures — real backend will return gift payload
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
        case .enteringPartnerEmail, .enteringCode:
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accentDeep)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.72))
                        .multilineTextAlignment(.leading)
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
