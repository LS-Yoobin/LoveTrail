import SwiftUI
import PhotosUI
import Photos
import GardenCore

struct PendingHomeView: View {
    var onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void
    var onResetApp: () -> Void = {}
    var onLogOut: () -> Void = {}

    @StateObject private var viewModel = HomeViewModel(
        pinnedFirstMet: nil,
        pinnedOfficial: UIImage(),
        loadFromPersistence: true
    )

    @State private var pollTimer: Timer? = nil
    @State private var showLockedToast = false
    @State private var bannerVisible = true
    @State private var showSettings = false
    @State private var showVisitPet = false
    @State private var showWaitingGarden = false
    @State private var showingPinnedViewer: PinnedMemoryType?
    @State private var firstMetPickerItem: PhotosPickerItem?
    @State private var officialPickerItem: PhotosPickerItem?
    @State private var showingMomentViewer = false
    @State private var viewerMoments: [Moment] = []
    @State private var viewerInitialIndex = 0

    private var officialMoment: Moment? {
        viewModel.canonicalFoundingMoment(for: "When we became official")
    }

    private var firstMetMoment: Moment? {
        viewModel.canonicalFoundingMoment(for: "When we first met")
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
                    BabyTownHeader(
                        onSettingsTap: { showSettings = true },
                        onGardenTap: { showWaitingGarden = true }
                    )

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

            if showVisitPet {
                NavigationStack {
                    AdoptAPetRootView(onDismiss: { showVisitPet = false })
                }
                .background(Color.white.ignoresSafeArea())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }

            if let viewerType = showingPinnedViewer {
                FullScreenPinnedMemoryViewer(
                    title: viewerType == .firstMet ? "First Photo Taken Together" : "First Photo As Official Jinkies",
                    date: "Pinned",
                    image: viewerType == .firstMet ? viewModel.pinnedFirstMet : viewModel.pinnedOfficial,
                    pickerItem: viewerType == .firstMet ? $firstMetPickerItem : $officialPickerItem,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showingPinnedViewer = nil
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(20)
            }

            if showingMomentViewer {
                momentPhotoViewerOverlay
                    .transition(.opacity)
                    .zIndex(21)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingPinnedViewer != nil)
        .animation(.easeInOut(duration: 0.25), value: showingMomentViewer)
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
                },
                onLogOut: { onLogOut() }
            )
        }
        .animation(.easeInOut(duration: 0.3), value: showVisitPet)
        .fullScreenCover(isPresented: $showWaitingGarden) {
            waitingGardenView
        }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
        .onChange(of: firstMetPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    var creationDate = Date()
                    var latitude: Double? = nil
                    var longitude: Double? = nil
                    if let identifier = newItem.itemIdentifier {
                        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                        if let asset = result.firstObject {
                            creationDate = asset.creationDate ?? Date()
                            latitude = asset.location?.coordinate.latitude
                            longitude = asset.location?.coordinate.longitude
                        }
                    }
                    viewModel.pinnedFirstMet = image
                    viewModel.upsertFoundingMoment(
                        promptText: "When we first met",
                        image: image,
                        dateTaken: creationDate,
                        assetIdentifier: newItem.itemIdentifier,
                        latitude: latitude,
                        longitude: longitude,
                        pinnedAt: Date().addingTimeInterval(-1)
                    )
                }
                firstMetPickerItem = nil
            }
        }
        .onChange(of: officialPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    var creationDate = Date()
                    var latitude: Double? = nil
                    var longitude: Double? = nil
                    if let identifier = newItem.itemIdentifier {
                        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                        if let asset = result.firstObject {
                            creationDate = asset.creationDate ?? Date()
                            latitude = asset.location?.coordinate.latitude
                            longitude = asset.location?.coordinate.longitude
                        }
                    }
                    viewModel.pinnedOfficial = image
                    viewModel.upsertFoundingMoment(
                        promptText: "When we became official",
                        image: image,
                        dateTaken: creationDate,
                        assetIdentifier: newItem.itemIdentifier,
                        latitude: latitude,
                        longitude: longitude,
                        pinnedAt: Date()
                    )
                }
                officialPickerItem = nil
            }
        }
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
                pendingPreviewContent
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.white)
    }

    // MARK: Pending preview sections

    private var pendingPreviewContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Here's a glimpse of your shared space")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            pendingGardenSection
            pendingPinnedSection
            pendingTimelineSection
        }
    }

    private var pendingGardenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            pendingSectionLabel("Secret Garden", icon: "leaf.fill")
                .padding(.horizontal, 20)

            ZStack(alignment: .topTrailing) {
                GardenBackgroundView()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { showWaitingGarden = true }
                    .padding(.horizontal, 20)
            }
            .frame(height: 180)
        }
    }

    private var pendingPinnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            pendingSectionLabel("Pinned Memories", icon: "pin.fill")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    pendingPinnedCard(
                        title: "When we became official",
                        moment: officialMoment
                    )
                    .frame(width: 170)

                    pendingPinnedCard(
                        title: "When we first met",
                        moment: firstMetMoment
                    )
                    .frame(width: 170)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder
    private func pendingPinnedCard(title: String, moment: Moment?) -> some View {
        if let moment {
            foundingPhotoCard(moment: moment, showsPinnedLabel: true) {
                openFoundingMoment(moment)
            }
        } else {
            FoundingPlaceholderCard(title: title, showsPinnedLabel: true) {
                openFoundingPhotoPicker(for: title)
            }
        }
    }

    private var pendingTimelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                HeartbeatIconView()
                Text("The Beginning\u{2026}")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.85))
                Spacer()
            }
            .padding(.leading, 32)
            .padding(.bottom, 4)

            pendingTimelineSlot(
                prompt: "When we became official",
                moment: officialMoment
            )
            pendingTimelineSlot(
                prompt: "When we first met",
                moment: firstMetMoment
            )
        }
        .padding(.bottom, 8)
    }

    private func pendingTimelineSlot(prompt: String, moment: Moment?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let moment {
                foundingPhotoCard(moment: moment, showsPinnedLabel: false) {
                    openFoundingMoment(moment)
                }
                .padding(.horizontal, 20)
            } else {
                FoundingPlaceholderCard(title: prompt, showsPinnedLabel: false) {
                    openFoundingPhotoPicker(for: prompt)
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                HeartbeatIconView()
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.85))
                    Text(moment == nil ? "Tap to add your photo" : "Tap to edit")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.5))
                }
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 16)
    }

    private func foundingPhotoCard(
        moment: Moment,
        showsPinnedLabel: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if showsPinnedLabel {
                VStack(alignment: .leading, spacing: 4) {
                    Text(moment.promptText ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                        Text("Pinned")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.7))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .fill(BabyTownTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .strokeBorder(BabyTownTheme.accent.opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var momentPhotoViewerOverlay: some View {
        MomentPhotoViewer(
            moments: viewerMoments,
            initialIndex: viewerInitialIndex,
            onDismiss: {
                withAnimation(.easeOut(duration: 0.25)) {
                    showingMomentViewer = false
                }
            },
            onUpdateMoments: { updatedMoments in
                var newMoments = viewModel.moments
                for moment in updatedMoments {
                    if let index = newMoments.firstIndex(where: { $0.id == moment.id }) {
                        newMoments[index] = moment
                    }
                }
                viewModel.moments = newMoments
            },
            onDeleteMoment: { moment in
                withAnimation {
                    viewModel.deleteMoment(moment)
                }
            },
            onEditMemory: { section, momentId, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                viewModel.updateMemory(
                    section: section,
                    primaryMomentId: momentId,
                    caption: caption,
                    placeName: placeName,
                    latitude: latitude,
                    longitude: longitude,
                    isPlaceNameUserSet: isPlaceNameUserSet
                )
            },
            onEditCaption: { momentId, caption, voiceNotePath in
                viewModel.updateCaption(for: momentId, caption: caption, voiceNotePath: voiceNotePath)
            },
            onAddPhotos: { section, images in
                viewModel.addPhotosToMemory(section: section, images: images)
            },
            onRemovePhoto: { section, momentId in
                viewModel.removePhotoFromMemory(section: section, momentId: momentId)
            },
            onSyncMemoryPhotos: { section, assetIds, orphanIds in
                await viewModel.syncMemoryPhotos(
                    section: section,
                    selectedAssetIds: assetIds,
                    selectedOrphanMomentIds: orphanIds
                )
            },
            onReloadMemoryMoments: {
                guard let anchorId = viewerMoments.first?.id else { return viewerMoments }
                return viewModel.flattenedPhotosForMemory(containingMomentId: anchorId)
            }
        )
    }

    private func openFoundingPhotoPicker(for promptText: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if promptText == "When we became official" {
                showingPinnedViewer = .official
            } else {
                showingPinnedViewer = .firstMet
            }
        }
    }

    private func openFoundingMoment(_ moment: Moment) {
        viewerMoments = viewModel.foundingMomentsForViewer(containing: moment)
        viewerInitialIndex = 0
        withAnimation(.easeInOut(duration: 0.25)) {
            showingMomentViewer = true
        }
    }

    private func pendingSectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.black.opacity(0.9))
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
            Spacer()
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
