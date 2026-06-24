import SwiftUI

struct PendingHomeView: View {
    var onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void

    @State private var selectedTab = 0
    @State private var pollTimer: Timer? = nil
    @State private var showLockedToast = false
    @State private var bannerVisible = true

    private var partnerName: String {
        DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "your partner"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                navBar
                if bannerVisible { waitingBanner }
                tabContent
                Spacer()
                tabBar
            }
            .ignoresSafeArea(edges: .bottom)

            if showLockedToast {
                lockedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 80)
            }
        }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: Nav bar

    private var navBar: some View {
        HStack {
            Text("Covela")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.white)
    }

    // MARK: Waiting banner

    private var waitingBanner: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(BabyTownTheme.accent)

            Text("Waiting for \(partnerName)\u{2026}")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(BabyTownTheme.accent.opacity(0.12))
        )
        .padding(.vertical, 8)
    }

    // MARK: Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            lockedPlaceholderTab(
                icon: "photo.on.rectangle.angled",
                message: "Your memories will live here once your partner joins."
            )
        case 1:
            petTab
        case 2:
            secretGardenTab
        default:
            lockedPlaceholderTab(icon: "lock.fill", message: "Available once your partner joins.")
        }
    }

    private var petTab: some View {
        AdoptAPetRootView()
    }

    private var secretGardenTab: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.97), BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                TypingTextView(
                    text: "Waiting for your partner\u{2026}",
                    font: .system(size: 28, weight: .bold, design: .serif),
                    color: BabyTownTheme.textPrimary
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                Spacer()
            }
        }
    }

    private func lockedPlaceholderTab(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.textSecondary.opacity(0.35))
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(BabyTownTheme.textSecondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { showToast() }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(icon: "photo.stack", label: "Memories", tag: 0, locked: true)
            tabBarItem(icon: "pawprint.fill", label: "Pet", tag: 1, locked: false)
            tabBarItem(icon: "leaf.fill", label: "Garden", tag: 2, locked: false)
            tabBarItem(icon: "envelope.fill", label: "Letters", tag: 3, locked: true)
        }
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background(.white.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -2)))
    }

    private func tabBarItem(icon: String, label: String, tag: Int, locked: Bool) -> some View {
        Button {
            if locked {
                showToast()
            } else {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(
                locked
                    ? BabyTownTheme.textSecondary.opacity(0.3)
                    : (selectedTab == tag ? BabyTownTheme.accent : BabyTownTheme.textSecondary.opacity(0.6))
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: Toast

    private var lockedToast: some View {
        Text("Available once your partner joins")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.black.opacity(0.75))
            )
    }

    private func showToast() {
        withAnimation { showLockedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showLockedToast = false }
        }
    }

    // MARK: Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { await checkAcceptance() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkAcceptance() async {
        guard let code = DataPersistenceManager.shared.loadPendingInviteCode() else { return }
        guard let status = try? await StubInviteAPIClient.shared.checkInviteStatus(code: code) else { return }
        if status.status == .accepted {
            stopPolling()
            withAnimation { bannerVisible = false }
            DataPersistenceManager.shared.clearPendingInviteState()
            let name = DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "Your partner"
            onPartnerJoined([], name)
        }
    }
}

#Preview {
    PendingHomeView(onPartnerJoined: { _, _ in })
}
