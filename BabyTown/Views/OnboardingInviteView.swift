import SwiftUI

struct OnboardingInviteView: View {
    var onSkip: () -> Void
    var onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void

    private enum InviteState {
        case choosingAction
        case pending(code: String)
        case enteringCode
    }

    @State private var state: InviteState = .choosingAction
    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var codeError: String? = nil
    @State private var pollTimer: Timer? = nil
    @FocusState private var codeFocused: Bool

    private var inviterName: String {
        DataPersistenceManager.shared.loadUserNickname() ?? "You"
    }

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

                switch state {
                case .choosingAction:
                    choosingActionContent
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
    }

    private var stateTag: Int {
        switch state {
        case .choosingAction: return 0
        case .pending: return 1
        case .enteringCode: return 2
        }
    }

    // MARK: State A — Choose action

    private var choosingActionContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Connect with your partner")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Choose how you want to get started.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                InviteActionCard(
                    icon: "envelope.heart.fill",
                    title: "Invite your partner",
                    subtitle: "Send them a link. They tap it and you are connected."
                ) {
                    Task { await sendInvite() }
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

    // MARK: State B — Pending

    private func pendingContent(code: String) -> some View {
        VStack(spacing: 28) {
            PulsingRingsView()
                .frame(width: 160, height: 160)

            VStack(spacing: 10) {
                Text("Invitation sent")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("We will let you know the moment they join.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                UIPasteboard.general.string = code
            } label: {
                Text("Copy invite code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BabyTownTheme.accent)
            }

            Button {
                stopPolling()
                onSkip()
            } label: {
                Text("Continue to your space")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
        }
    }

    // MARK: State C — Enter code

    private var enteringCodeContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Enter your code")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Enter the 6 character code from the invite email.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                TextField("Enter your 6 character code", text: $codeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: BabyTownTheme.accent.opacity(0.12), radius: 8, y: 4)
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

    private func sendInvite() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let response = try await StubInviteAPIClient.shared.createInvite(inviterName: inviterName)
            DataPersistenceManager.shared.setPendingPartnerInvite(true)
            DataPersistenceManager.shared.savePendingInviteCode(response.code)
            withAnimation { state = .pending(code: response.code) }
            startPolling(code: response.code)
        } catch {
            // Remain on choosingAction — user can retry
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
            break // back button from ContentView handles navigation
        case .pending, .enteringCode:
            stopPolling()
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
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textSecondary.opacity(0.4))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: BabyTownTheme.accent.opacity(0.1), radius: 10, y: 4)
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
                    .stroke(BabyTownTheme.accent.opacity(animate ? 0.0 : [0.4, 0.25, 0.12][i]), lineWidth: 2)
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
                .foregroundStyle(BabyTownTheme.accent)
        }
        .onAppear { animate = true }
    }
}

#Preview("Choose action") {
    OnboardingInviteView(onSkip: {}, onPartnerJoined: { _, _ in })
}

#Preview("Pending") {
    OnboardingInviteView(onSkip: {}, onPartnerJoined: { _, _ in })
}
