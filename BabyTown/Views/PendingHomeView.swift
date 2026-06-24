import SwiftUI

struct PendingHomeView: View {
    var onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void
    var onResetApp: () -> Void = {}

    @State private var pollTimer: Timer? = nil
    @State private var showLockedToast = false
    @State private var bannerVisible = true
    @State private var showSettings = false
    @State private var showVisitPet = false
    @State private var showWaitingGarden = false
    @State private var scrollOffset: CGFloat = 0
    @State private var peakPullOffset: CGFloat = 0
    @State private var didCrossPetOpenThreshold = false
    @State private var petThresholdHapticTick = 0
    @State private var petOpenHapticTick = 0

    private let petOpenThreshold: CGFloat = 110

    private var currentPullProgress: CGFloat {
        max(0, -scrollOffset) / petOpenThreshold
    }

    private var partnerName: String {
        DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "your partner"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                Color.white
                    .ignoresSafeArea()

                LoopingVideoPlayer(videoName: "transparent_flowers")
                    .frame(height: 300)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .opacity(0.4)
                    .allowsHitTesting(false)
                    .offset(y: 50)

                VStack(spacing: 0) {
                    BabyTownHeader(onSettingsTap: { showSettings = true })

                    if bannerVisible {
                        waitingBanner
                            .padding(.top, 4)
                    }

                    lockedActionBar

                    pendingHomeScroll
                }
            }

            if showLockedToast {
                lockedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                onResetApp: {
                    showSettings = false
                    onResetApp()
                },
                onReplayStory: {},
                onVisitPet: {
                    showSettings = false
                    showVisitPet = true
                },
                onOpenCoupleProfile: {
                    showSettings = false
                    showWaitingGarden = true
                }
            )
        }
        .fullScreenCover(isPresented: $showVisitPet) {
            NavigationStack {
                AdoptAPetRootView(onDismiss: { showVisitPet = false })
            }
            .background(Color.white.ignoresSafeArea())
        }
        .fullScreenCover(isPresented: $showWaitingGarden) {
            waitingGardenView
        }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
        .sensoryFeedback(.impact(weight: .medium), trigger: petThresholdHapticTick)
        .sensoryFeedback(.success, trigger: petOpenHapticTick)
    }

    // MARK: Waiting banner

    private var waitingBanner: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(BabyTownTheme.inviteBannerText)

            Text("Waiting for \(partnerName)\u{2026}")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.inviteBannerText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(BabyTownTheme.inviteBannerFill)
                .overlay(
                    Capsule()
                        .strokeBorder(BabyTownTheme.inviteBannerBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // MARK: Locked home chrome

    private var lockedActionBar: some View {
        StickyActionBar(
            onSelectPhotos: { showToast() },
            onScan: { showToast() },
            onPrompt: { showToast() }
        )
        .opacity(0.35)
        .allowsHitTesting(true)
    }

    private var pendingHomeScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                MapPullHintView(
                    progress: min(currentPullProgress, 1),
                    isVisible: scrollOffset > -24 && scrollOffset < 30,
                    isNightMode: false
                )

                lockedMemoriesContent
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.white)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, topOffset in
            handleScrollTopOffsetChange(topOffset)
        }
    }

    private var lockedMemoriesContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 120)

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.25))

            Text("Your memories will live here once your partner joins.")
                .font(.system(size: 15))
                .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { showToast() }
    }

    private func handleScrollTopOffsetChange(_ topOffset: CGFloat) {
        if topOffset < 80 {
            scrollOffset = topOffset
        } else {
            let coarseOffset = (topOffset / 32).rounded() * 32
            if scrollOffset < 80 || abs(coarseOffset - scrollOffset) >= 32 {
                scrollOffset = coarseOffset
            }
        }

        let pull = max(0, -topOffset)

        if pull > peakPullOffset {
            peakPullOffset = pull
        }

        if pull >= petOpenThreshold, !didCrossPetOpenThreshold {
            didCrossPetOpenThreshold = true
            petThresholdHapticTick += 1
        }

        let wasPulling = peakPullOffset > 2
        if wasPulling && pull < 2 {
            if peakPullOffset >= petOpenThreshold {
                openVisitPet()
            }
            peakPullOffset = 0
            didCrossPetOpenThreshold = false
        }
    }

    private func openVisitPet() {
        guard !showVisitPet else { return }
        petOpenHapticTick += 1
        withAnimation(.easeInOut(duration: 0.3)) {
            showVisitPet = true
        }
    }

    private var waitingGardenView: some View {
        ZStack(alignment: .topLeading) {
            HomeBackgroundView(isNightMode: false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                TypingTextView(
                    text: "Waiting for your partner\u{2026}",
                    font: .system(size: 28, weight: .bold, design: .serif),
                    color: BabyTownTheme.accentDeep
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                Spacer()
            }

            Button {
                showWaitingGarden = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }

    // MARK: Toast

    private var lockedToast: some View {
        Text("Available once your partner joins")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(BabyTownTheme.accentDeep.opacity(0.92))
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
            let name = DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "Your partner"
            DataPersistenceManager.shared.clearPendingInviteState()
            onPartnerJoined([], name)
        }
    }
}

#Preview {
    PendingHomeView(onPartnerJoined: { _, _ in })
}
