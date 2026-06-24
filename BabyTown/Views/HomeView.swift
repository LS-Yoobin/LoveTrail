import SwiftUI
import PhotosUI
import Photos
import GardenCore

enum PinnedMemoryType {
    case firstMet
    case official
}

struct HomeView: View {

    @StateObject private var viewModel: HomeViewModel
    @StateObject private var nightModeManager = NightModeManager()
    @StateObject private var shareCoordinator = MemoryShareCoordinator()

    var onSelectPhotos: () -> Void
    var onOpenPhotoViewer: (_ moment: Moment, _ allInDay: [Moment]) -> Void
    var onResetApp: (() -> Void)? = nil
    var onReplayStory: (() -> Void)? = nil
    @Binding var selectedPrompt: PromptItem?
    var onMemoriesAdded: (() -> Void)? = nil
    
    @State private var showCameraSheet = false
    @State private var showCameraFullScreen = false
    @State private var showSettings = false
    @State private var showVisitPet = false
    @State private var showCoupleProfile = false
    /// Cached for `CoupleSpaceCard` — recomputing garden blooms on every scroll frame
    /// was reloading JSON from disk and tanking Home scroll performance.
    @State private var coupleSpaceBloomCount = 0
    @State private var coupleSpaceAvatar: UIImage?
    @State private var coupleSpaceGardenThumbnail: UIImage?
    @State private var homeSpecialDates: [SpecialDate] = []
    @State private var showHomeSpecialDateEditor = false
    @State private var editingHomeSpecialDate: SpecialDate?
    @State private var editingHomeSpecialDateImage: UIImage?
    @State private var showInviteFlow = false
    @ObservedObject private var store = StoreManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var memorySearchText = ""
    @State private var cachedMemorySearchRows: [MemorySearchRow] = []
    @FocusState private var isMemorySearchFocused: Bool
    @State private var isSearchBarPinned = false
    @State private var firstMetPickerItem: PhotosPickerItem?
    @State private var officialPickerItem: PhotosPickerItem?
    @State private var showingPinnedViewer: PinnedMemoryType?
    @State private var showingMomentViewer = false
    @State private var viewerMoments: [Moment] = []
    @State private var viewerInitialIndex = 0
    @State private var viewerMemoryPagePromptText: String?
    @State private var viewerImportantDate: MemoryPageImportantDateInfo?
    @State private var viewerPromptMemoryId: UUID?
    @State private var showPromptSheet = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showUpButton = false
    @State private var scrollToNewMemory = false
    @State private var scrollToTop = false
    /// Aligns the initial rest position with the scroll-to-top button's target.
    @State private var didAlignInitialScroll = false
    @State private var showNotifications = false
    @State private var hasUnreadNotifications = AppNotification.hasUnread()
    @State private var showOnThisDayViewer = false
    @State private var onThisDayPhotos: [Moment] = []
    @State private var onThisDayStartIndex = 0
    @State private var showScan = false
    @State private var showMapView = false
    @State private var showToC = false
    @State private var showPinnedMemoriesFeed = false
    @State private var peakPullOffset: CGFloat = 0
    @State private var didCrossMapOpenThreshold = false
    @State private var mapThresholdHapticTick = 0
    @State private var mapOpenHapticTick = 0
    @State private var visibleRowCount = HomeView.timelinePageSize
    @State private var selectedTimelineYear = 0
    @State private var isYearFilterPinned = false
    @State private var showVaultedPrompt = false
    @State private var showForeverPaywall = false
    @State private var showPinCapSheet = false

    private let mapOpenThreshold: CGFloat = 110
    private static let timelinePageSize = 15

    private var vaultedIDs: Set<UUID> {
        viewModel.vaultedMomentIDs(isForeverUnlocked: store.isForeverUnlocked)
    }

    private var homeDisplayName: String {
        let profile = DataPersistenceManager.shared.loadCoupleProfile()
        return profile.displayName ?? DataPersistenceManager.shared.loadUserNickname() ?? "You"
    }

    private var homePartnerSlotTitle: String {
        let dpm = DataPersistenceManager.shared
        if dpm.isPartnerAccount() {
            return dpm.loadInviterName() ?? "Justin"
        }
        return "Invite partner"
    }


    init(
        pinnedFirstMet: UIImage?,
        pinnedOfficial: UIImage,
        moments: [Moment] = [],
        onSelectPhotos: @escaping () -> Void,
        onOpenPhotoViewer: @escaping (Moment, [Moment]) -> Void,
        onResetApp: (() -> Void)? = nil,
        onReplayStory: (() -> Void)? = nil,
        selectedPrompt: Binding<PromptItem?> = .constant(nil)
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            pinnedFirstMet: pinnedFirstMet,
            pinnedOfficial: pinnedOfficial,
            moments: moments
        ))
        self.onSelectPhotos = onSelectPhotos
        self.onOpenPhotoViewer = onOpenPhotoViewer
        self.onResetApp = onResetApp
        self.onReplayStory = onReplayStory
        _selectedPrompt = selectedPrompt
    }

    init(
        viewModel: HomeViewModel,
        onSelectPhotos: @escaping () -> Void = {},
        onOpenPhotoViewer: @escaping (Moment, [Moment]) -> Void = { _, _ in },
        onResetApp: (() -> Void)? = nil,
        onReplayStory: (() -> Void)? = nil,
        selectedPrompt: Binding<PromptItem?> = .constant(nil)
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectPhotos = onSelectPhotos
        self.onOpenPhotoViewer = onOpenPhotoViewer
        self.onResetApp = onResetApp
        self.onReplayStory = onReplayStory
        _selectedPrompt = selectedPrompt
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background Layer
                HomeBackgroundView(isNightMode: nightModeManager.isNightMode)
                    .animation(.easeInOut(duration: 0.8), value: nightModeManager.isNightMode)
                
                if !nightModeManager.isNightMode {
                    LoopingVideoPlayer(videoName: "transparent_flowers")
                        .frame(height: 300)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .opacity(0.4)
                        .allowsHitTesting(false)
                        .offset(y: 50)
                }

                // Main Content Layer
                VStack(spacing: 0) {
                    BabyTownHeader(
                        onSettingsTap: { showSettings = true },
                        onNotificationsTap: { showNotifications = true },
                        onMapTap: { openMap() },
                        isNightMode: nightModeManager.isNightMode,
                        showsUnreadBadge: hasUnreadNotifications
                    )
                    
                    StickyActionBar(
                        onSelectPhotos: onSelectPhotos,
                        onScan: { showScan = true },
                        onPrompt: { showPromptSheet = true },
                        isNightMode: nightModeManager.isNightMode
                    )

                    if isSearchBarPinned {
                        memoryInlineSearchBar
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                    }

                    if isYearFilterPinned && showsTimelineYearFilter {
                        timelineYearFilterBar(isPinned: true)
                            .zIndex(2)
                    }

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: isMemorySearchActive ? 16 : 28) {
                                Color.clear
                                    .frame(height: 0)
                                    .id("homeScrollTop")

                                if !isUsingMemorySearch {
                                    MapPullHintView(
                                        progress: min(currentPullProgress, 1),
                                        isVisible: scrollOffset > -24 && scrollOffset < 30 && !showMapView && !isYearFilterPinned,
                                        isNightMode: nightModeManager.isNightMode
                                    )
                                }

                                if !isSearchBarPinned {
                                    memorySearchBarPlaceholder
                                }

                                if isMemorySearchActive {
                                    inlineMemorySearchResults
                                } else {
                                    CoupleSpaceCard(
                                        avatar: coupleSpaceAvatar,
                                        gardenThumbnail: coupleSpaceGardenThumbnail,
                                        bloomCount: coupleSpaceBloomCount,
                                        isReadyToInvite: store.isForeverUnlocked,
                                        onTap: {
                                            dismissMemorySearchKeyboard()
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showCoupleProfile = true
                                            }
                                        }
                                    )

                                    // On This Day section (cached; never computed in body)
                                    let onThisDayMatches = viewModel.onThisDaySections
                                    if !onThisDayMatches.isEmpty {
                                        OnThisDaySection(
                                            matches: onThisDayMatches,
                                            isNightMode: nightModeManager.isNightMode
                                        ) { section in
                                            let photos = viewModel.flattenedPhotos(for: section)
                                            guard !photos.isEmpty else { return }
                                            onThisDayPhotos = photos
                                            onThisDayStartIndex = 0
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                showOnThisDayViewer = true
                                            }
                                        }
                                        divider
                                    }

                                    if showsPinnedSection {
                                        pinnedSection
                                        divider
                                    }

                                    if viewModel.isEmpty {
                                        emptyState
                                    } else {
                                        timelineSection
                                    }
                                }
                            }
                            .padding(.top, isSearchBarPinned ? (isMemorySearchActive ? 4 : 8) : 18)
                            .padding(.bottom, 100)
                        }
                        .coordinateSpace(name: "homeScroll")
                        .onPreferenceChange(TimelineYearFilterAnchorKey.self) { minY in
                            updateYearFilterPinState(minY: minY)
                        }
                        .scrollDismissesKeyboard(
                            isMemorySearchFocused ? .immediately : .interactively
                        )
                        .onChange(of: isMemorySearchFocused) { _, focused in
                            if focused {
                                isSearchBarPinned = true
                            } else if !isMemorySearchActive {
                                isSearchBarPinned = false
                            }
                        }
                        .onChange(of: memorySearchText, initial: true) { _, _ in
                            rebuildMemorySearchRowsCache()
                            if isMemorySearchActive {
                                isSearchBarPinned = true
                            } else if !isMemorySearchFocused {
                                isSearchBarPinned = false
                                cachedMemorySearchRows = []
                            }
                        }
                        .onChange(of: viewModel.moments.count) { _, _ in
                            clampVisibleRowCount()
                            if isMemorySearchActive {
                                rebuildMemorySearchRowsCache()
                            }
                        }
                        .onChange(of: viewModel.promptMemories.count) { _, _ in
                            clampVisibleRowCount()
                            if isMemorySearchActive {
                                rebuildMemorySearchRowsCache()
                            }
                        }
                        .onChange(of: homeSpecialDates.count) { _, _ in
                            clampVisibleRowCount()
                        }
                        .onChange(of: selectedTimelineYear) { _, _ in
                            visibleRowCount = Self.timelinePageSize
                            clampVisibleRowCount()
                        }
                        .onChange(of: isYearFilterPinned) { _, pinned in
                            if pinned {
                                peakPullOffset = 0
                                didCrossMapOpenThreshold = false
                            }
                        }
                        .onScrollGeometryChange(for: CGFloat.self) { geometry in
                            geometry.contentOffset.y + geometry.contentInsets.top
                        } action: { previousTopOffset, topOffset in
                            dismissSearchKeyboardIfScrolling(
                                from: previousTopOffset,
                                to: topOffset
                            )
                            handleScrollTopOffsetChange(topOffset)
                        }
                        .onScrollGeometryChange(for: TimelinePagingSignal.self) { geometry in
                            TimelinePagingSignal(
                                offsetY: geometry.contentOffset.y,
                                distanceFromBottom: geometry.contentSize.height
                                    - (geometry.contentOffset.y + geometry.containerSize.height)
                            )
                        } action: { _, signal in
                            // Grow the window only once the user has genuinely scrolled down
                            // (offsetY guard) AND is near the bottom. The offsetY guard is what
                            // prevents a launch-time cascade: at launch offsetY ≈ 0, so nothing
                            // auto-loads no matter what the still-settling content height reads.
                            // No per-frame @State write here, so scrolling stays smooth.
                            if hasMoreTimelineItems, signal.offsetY > 120, signal.distanceFromBottom < 700 {
                                loadMoreTimelineRows()
                            }
                        }
                        .onChange(of: scrollToNewMemory) { _, newValue in
                            if newValue {
                                withAnimation {
                                    proxy.scrollTo("timeline", anchor: .top)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    scrollToNewMemory = false
                                }
                            }
                        }
                        .onChange(of: scrollToTop) { _, newValue in
                            if newValue {
                                withAnimation {
                                    proxy.scrollTo("homeScrollTop", anchor: .top)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    scrollToTop = false
                                }
                            }
                        }
                        .onAppear {
                            // Rest at the same spot the scroll-to-top button targets,
                            // so the default position isn't 18pt below it.
                            guard !didAlignInitialScroll else { return }
                            didAlignInitialScroll = true
                            DispatchQueue.main.async {
                                proxy.scrollTo("homeScrollTop", anchor: .top)
                            }
                        }
                    }
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: mapThresholdHapticTick)
                .sensoryFeedback(.success, trigger: mapOpenHapticTick)
                .onAppear {
                    viewModel.checkAndReleasePhotos()
                    viewModel.refreshOnThisDay()
                }
                .onChange(of: viewModel.moments.count) { oldCount, newCount in
                    if newCount > oldCount {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scrollToNewMemory = true
                        }
                    }
                }
                .onChange(of: viewModel.promptMemories.count) { oldCount, newCount in
                    if newCount > oldCount {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scrollToNewMemory = true
                        }
                    }
                }
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

                // Floating Buttons
                cameraButton
                
                if showUpButton {
                    upButton
                }

                // Overlays and Viewers
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
                    .zIndex(10)
                }
                
                if showingMomentViewer, !showMapView {
                    momentPhotoViewerOverlay
                    .transition(.opacity)
                    .zIndex(11)
                }
                
                
                if showOnThisDayViewer {
                    OnThisDayPhotoViewer(
                        photos: onThisDayPhotos,
                        startIndex: onThisDayStartIndex,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showOnThisDayViewer = false
                            }
                        },
                        onAddMemory: { moment in
                            let newMoment = Moment(
                                id: UUID(), dateTaken: moment.dateTaken, assetIdentifier: moment.assetIdentifier,
                                thumbnail: moment.thumbnail, placeName: moment.placeName, caption: moment.caption,
                                voiceNotePath: moment.voiceNotePath, promptText: nil, isPinned: false,
                                pinnedAt: nil, isLocked: false, unlockTime: nil,
                                latitude: moment.latitude, longitude: moment.longitude, isAddedFromOnThisDay: true,
                                dateAddedToApp: Date()
                            )
                            viewModel.addMoments([newMoment])
                        },
                        viewModel: viewModel
                    )
                    .transition(.opacity)
                    .zIndex(13)
                }
                
                if showMapView {
                    memoryMapOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(20)
                        .transition(.opacity)
                }

                if showCoupleProfile {
                    coupleProfileOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(26)
                        .transition(.opacity)
                }
            } // Close ZStack
            .animation(.easeInOut(duration: 0.3), value: showMapView)
            .animation(.easeInOut(duration: 0.3), value: showCoupleProfile)
            .animation(.easeInOut(duration: 0.25), value: showingPinnedViewer != nil)
            .animation(.easeInOut(duration: 0.25), value: showingMomentViewer)
            .sheet(isPresented: $showPromptSheet) {
                JinkyPromptSheetView { prompt in
                    self.selectedPrompt = prompt
                    showPromptSheet = false
                    onSelectPhotos()
                }
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
            }
            .fullScreenCover(isPresented: $showCameraFullScreen) {
                PolaroidCameraView(
                    polaroidStore: viewModel.polaroidStore,
                    onPhotosReleased: { releasedEntries in
                        viewModel.releasePolaroids(releasedEntries)
                        viewModel.checkAndReleasePhotos()
                    }
                )
            }
            .sheet(isPresented: $showCameraSheet) {
                CameraCaptureView(
                    polaroidStore: viewModel.polaroidStore,
                    onPhotosReleased: { releasedEntries in
                        viewModel.releasePolaroids(releasedEntries)
                        viewModel.checkAndReleasePhotos()
                    }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(
                    onResetApp: { onResetApp?() },
                    onReplayStory: { onReplayStory?() },
                    onVisitPet: { showVisitPet = true },
                    onOpenCoupleProfile: { showCoupleProfile = true }
                )
            }
            .sheet(isPresented: $showHomeSpecialDateEditor) {
                SpecialDateEditorSheet(
                    editing: editingHomeSpecialDate,
                    initialImage: editingHomeSpecialDateImage,
                    onSave: { saveHomeSpecialDate($0, image: $1) },
                    onDelete: editingHomeSpecialDate == nil ? nil : { deleteHomeSpecialDate($0) }
                )
            }
            .sheet(isPresented: $showInviteFlow) {
                InvitePartnerFlowView(onDone: { showInviteFlow = false })
            }
            .fullScreenCover(isPresented: $showNotifications, onDismiss: refreshUnreadNotifications) {
                NotificationCenterView(onNotificationRead: refreshUnreadNotifications)
            }
            .onAppear(perform: refreshUnreadNotifications)
            .fullScreenCover(isPresented: $showScan) {
                ScanView(existingAssetIdentifiers: Set(viewModel.moments.compactMap { $0.assetIdentifier })) { moments in
                    viewModel.addMoments(moments)
                }
            }
            .fullScreenCover(isPresented: $showVisitPet) {
                visitPetOverlay
            }
            .fullScreenCover(isPresented: $showPinnedMemoriesFeed) {
                PinnedMemoriesFeedView(
                    viewModel: viewModel,
                    specialDates: pinnedHomeSpecialDates,
                    userAvatar: coupleSpaceAvatar,
                    userName: homeDisplayName,
                    partnerSlotTitle: homePartnerSlotTitle,
                    isForeverUnlocked: store.isForeverUnlocked,
                    onBack: { showPinnedMemoriesFeed = false },
                    onPartnerTap: { showInviteFlow = true },
                    onShare: shareMemory,
                    onEditSpecialDate: { beginEditHomeSpecialDate($0) },
                    onDeleteSpecialDate: { deleteHomeSpecialDate($0) },
                    onTogglePinSpecialDate: { toggleHomeSpecialDatePin($0) }
                )
            }
            .sheet(isPresented: $showToC) {
                TableOfContentsView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showVaultedPrompt) {
                VaultedMomentPrompt(
                    isPresented: $showVaultedPrompt,
                    onUnlockForever: { showForeverPaywall = true }
                )
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(BabyTownTheme.cardBackground)
            }
            .sheet(isPresented: $showPinCapSheet) {
                VStack(spacing: 20) {
                    Capsule()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                    Image(systemName: "pin.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(BabyTownTheme.accentDeep)
                    Text("You have reached your 10 pinned moment limit")
                        .font(.system(size: 16, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Text("Upgrade to Covela Forever to pin unlimited moments")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button {
                        showPinCapSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showForeverPaywall = true
                        }
                    } label: {
                        Text("Unlock Forever")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(LinearGradient(
                                colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep],
                                startPoint: .leading, endPoint: .trailing
                            )))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    Button { showPinCapSheet = false } label: {
                        Text("Maybe later")
                            .font(.system(size: 14))
                            .foregroundStyle(.black.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationBackground(BabyTownTheme.cardBackground)
            }
            .fullScreenCover(isPresented: $showForeverPaywall) {
                CovelaForeverPaywallView(
                    store: store,
                    onUnlock: { showForeverPaywall = false },
                    onDismiss: { showForeverPaywall = false }
                )
            }
            .memorySharePresentation(coordinator: shareCoordinator)
            .onAppear {
                viewModel.onPinCapReached = { showPinCapSheet = true }
                refreshCoupleSpaceCardMetadata()
            }
            .onChange(of: viewModel.moments.count) { _, _ in
                refreshCoupleSpaceCardMetadata()
            }
            .onChange(of: showCoupleProfile) { _, isShowing in
                if !isShowing { refreshCoupleSpaceCardMetadata() }
            }
        }
    }

    private func shareMemory(_ payload: MemorySharePayload) {
        shareCoordinator.share(payload)
    }

    private func shareHomeSpecialDate(_ special: SpecialDate) {
        shareMemory(
            MemorySharePayload(
                special: special,
                image: DataPersistenceManager.shared.loadSpecialDatePhoto(id: special.id)
            )
        )
    }
    
    // MARK: - Map pull reveal

    @ViewBuilder
    private var visitPetOverlay: some View {
        NavigationStack {
            AdoptAPetRootView(onDismiss: { showVisitPet = false })
        }
        .background(BabyTownTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var coupleProfileOverlay: some View {
        CoupleProfileView(homeViewModel: viewModel, onBack: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCoupleProfile = false
            }
        })
        .background {
            Group {
                if nightModeManager.isNightMode {
                    HomeBackgroundView(isNightMode: true)
                } else {
                    Color(red: 0.78, green: 0.90, blue: 0.98)
                }
            }
            .ignoresSafeArea()
        }
    }

    /// Refreshes Us-card metadata off the hot path (scroll / body). Uses in-memory
    /// `viewModel.moments` so we don't re-read `moments.json` every frame.
    private func refreshCoupleSpaceCardMetadata() {
        let dpm = DataPersistenceManager.shared
        coupleSpaceAvatar = dpm.isPartnerAccount()
            ? dpm.loadPartnerProfilePhoto()
            : dpm.loadUserAvatar()
        homeSpecialDates = dpm.loadCoupleProfile().specialDates.sorted { $0.date < $1.date }
        let moments = viewModel.moments
        let gardenContext = GardenActMapper.persistedContext(
            moments: moments,
            promptMemories: viewModel.promptMemories,
            dpm: dpm
        )
        coupleSpaceBloomCount = GardenActMapper.composeElements(context: gardenContext).count

        let season = dpm.loadGardenState().season(now: Date())
        Task { @MainActor in
            let thumbnail = await GardenSnapshotRenderer.render(
                context: gardenContext,
                season: season
            )
            coupleSpaceGardenThumbnail = thumbnail
        }
    }

    private func openHomeSpecialDate(_ special: SpecialDate) {
        let dpm = DataPersistenceManager.shared
        if let image = dpm.loadSpecialDatePhoto(id: special.id) {
            openImportantDateMemoryPage(
                title: special.title,
                date: special.date,
                image: image,
                itemId: special.id.uuidString
            )
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCoupleProfile = true
            }
        }
    }

    private func beginEditHomeSpecialDate(_ special: SpecialDate) {
        let dpm = DataPersistenceManager.shared
        editingHomeSpecialDate = special
        editingHomeSpecialDateImage = dpm.loadSpecialDatePhoto(id: special.id)
        showHomeSpecialDateEditor = true
    }

    private func normalizedSpecialDateForSave(_ date: SpecialDate) -> SpecialDate {
        guard date.isBirthday else { return date }
        var copy = date
        copy.isPinned = false
        copy.pinnedAt = nil
        return copy
    }

    private func saveHomeSpecialDate(_ date: SpecialDate, image: UIImage?) {
        let dpm = DataPersistenceManager.shared
        var profile = dpm.loadCoupleProfile()
        let toSave = normalizedSpecialDateForSave(date)
        if let idx = profile.specialDates.firstIndex(where: { $0.id == toSave.id }) {
            profile.specialDates[idx] = toSave
        } else {
            profile.specialDates.append(toSave)
        }
        if let image {
            dpm.saveSpecialDatePhoto(image, id: toSave.id)
        }
        ProfileStickerSync.sync(profile: &profile, dpm: dpm)
        dpm.saveCoupleProfile(profile)
        refreshCoupleSpaceCardMetadata()
    }

    private func updateHomeSpecialDate(_ date: SpecialDate) {
        let dpm = DataPersistenceManager.shared
        var profile = dpm.loadCoupleProfile()
        let toSave = normalizedSpecialDateForSave(date)
        if let idx = profile.specialDates.firstIndex(where: { $0.id == toSave.id }) {
            profile.specialDates[idx] = toSave
        } else {
            profile.specialDates.append(toSave)
        }
        ProfileStickerSync.sync(profile: &profile, dpm: dpm)
        dpm.saveCoupleProfile(profile)
        refreshCoupleSpaceCardMetadata()
    }

    private func toggleHomeSpecialDatePin(_ special: SpecialDate) {
        guard !special.isBirthday else { return }
        var updated = special
        updated.isPinned.toggle()
        updated.pinnedAt = updated.isPinned ? Date() : nil
        withAnimation {
            updateHomeSpecialDate(updated)
        }
    }

    private func deleteHomeSpecialDate(_ date: SpecialDate) {
        let dpm = DataPersistenceManager.shared
        var profile = dpm.loadCoupleProfile()
        profile.specialDates.removeAll { $0.id == date.id }
        dpm.deleteSpecialDatePhoto(id: date.id)
        ProfileStickerSync.sync(profile: &profile, dpm: dpm)
        dpm.saveCoupleProfile(profile)
        refreshCoupleSpaceCardMetadata()
    }

    
    @ViewBuilder
    private var memoryMapOverlay: some View {
        ZStack {
            MapView(
                viewModel: viewModel,
                onOpenMemory: { section in
                    clearMemoryPageViewerContext()
                    let photos = viewModel.flattenedPhotos(for: section)
                    viewerMoments = photos
                    viewerInitialIndex = 0
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingMomentViewer = true
                    }
                },
                onDismiss: {
                    showingMomentViewer = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showMapView = false
                    }
                },
                onScanPhotos: {
                    showingMomentViewer = false
                    showMapView = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showScan = true
                    }
                }
            )

            if showingMomentViewer {
                momentPhotoViewerOverlay
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingMomentViewer)
    }
    
    private var currentPullProgress: CGFloat {
        max(0, -scrollOffset) / mapOpenThreshold
    }
    
    private func handleScrollTopOffsetChange(_ topOffset: CGFloat) {
        showUpButton = topOffset > 100

        // Avoid re-rendering the feed on every scroll frame (pinned photos can flash,
        // especially over the animated night background). Search keeps scrollOffset frozen.
        if !isMemorySearchActive {
            if topOffset < 80 {
                if scrollOffset != topOffset {
                    scrollOffset = topOffset
                }
            } else {
                let coarseOffset = (topOffset / 32).rounded() * 32
                if scrollOffset < 80 || abs(coarseOffset - scrollOffset) >= 32 {
                    scrollOffset = coarseOffset
                }
            }
        }

        guard !isUsingMemorySearch, !isYearFilterPinned else {
            peakPullOffset = 0
            didCrossMapOpenThreshold = false
            return
        }
        
        // Negative topOffset = overscroll pull-down at the top of the feed.
        let pull = max(0, -topOffset)
        
        if pull > peakPullOffset {
            peakPullOffset = pull
        }
        
        if pull >= mapOpenThreshold, !didCrossMapOpenThreshold {
            didCrossMapOpenThreshold = true
            mapThresholdHapticTick += 1
        }
        
        let wasPulling = peakPullOffset > 2
        if wasPulling && pull < 2 {
            if peakPullOffset >= mapOpenThreshold {
                openVisitPet()
            }
            peakPullOffset = 0
            didCrossMapOpenThreshold = false
        }
    }
    
    private func refreshUnreadNotifications() {
        hasUnreadNotifications = AppNotification.hasUnread(
            userNickname: DataPersistenceManager.shared.loadUserNickname()
        )
    }

    private func openMap() {
        guard !showMapView else { return }
        mapOpenHapticTick += 1
        withAnimation(.easeInOut(duration: 0.3)) {
            showMapView = true
        }
    }

    private func openVisitPet() {
        guard !showVisitPet, !isYearFilterPinned else { return }
        mapOpenHapticTick += 1
        withAnimation(.easeInOut(duration: 0.3)) {
            showVisitPet = true
        }
    }

    private func dismissMemorySearchKeyboard() {
        guard isMemorySearchFocused else { return }
        isMemorySearchFocused = false
    }

    private func dismissSearchKeyboardIfScrolling(from previousOffset: CGFloat, to offset: CGFloat) {
        guard isMemorySearchFocused else { return }
        guard abs(offset - previousOffset) > 2 else { return }
        dismissMemorySearchKeyboard()
    }

    // MARK: - Memory Search

    private var isMemorySearchActive: Bool {
        !memorySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isUsingMemorySearch: Bool {
        isSearchBarPinned || isMemorySearchActive
    }

    private var memorySearchFilteredSections: [DaySection] {
        let filtered = viewModel.moments.filter {
            MemorySearchMatcher.matches(moment: $0, query: memorySearchText)
        }
        return DaySection.grouped(from: filtered)
    }

    private var memorySearchFilteredPrompts: [PromptMemory] {
        viewModel.promptMemories
            .filter { MemorySearchMatcher.matches(promptMemory: $0, query: memorySearchText) }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private enum MemorySearchItem {
        case daySection(DaySection)
        case promptMemory(PromptMemory)
    }

    private struct MemorySearchRow: Identifiable {
        let id: String
        let item: MemorySearchItem
        let displayIndex: Int
    }

    private func rebuildMemorySearchRowsCache() {
        guard isMemorySearchActive else {
            cachedMemorySearchRows = []
            return
        }

        let sections = memorySearchFilteredSections
        let prompts = memorySearchFilteredPrompts
        var rows: [MemorySearchRow] = []
        rows.reserveCapacity(sections.count + prompts.count)

        for (displayIndex, section) in sections.enumerated() {
            rows.append(MemorySearchRow(
                id: "day-\(section.id)",
                item: .daySection(section),
                displayIndex: displayIndex
            ))
        }

        let promptOffset = sections.count
        for (index, memory) in prompts.enumerated() {
            rows.append(MemorySearchRow(
                id: "prompt-\(memory.id.uuidString)",
                item: .promptMemory(memory),
                displayIndex: promptOffset + index
            ))
        }

        cachedMemorySearchRows = rows
    }

    private var memorySearchBarIconColor: Color {
        nightModeManager.isNightMode ? .white.opacity(0.55) : BabyTownTheme.daySearchBarIcon
    }

    private var memorySearchBarPlaceholderColor: Color {
        nightModeManager.isNightMode ? .white.opacity(0.45) : BabyTownTheme.daySearchBarPlaceholder
    }

    private var memorySearchBarTextColor: Color {
        nightModeManager.isNightMode ? .white : BabyTownTheme.daySearchBarText
    }

    private var memorySearchBarPlaceholder: some View {
        Button {
            isSearchBarPinned = true
            DispatchQueue.main.async {
                isMemorySearchFocused = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(memorySearchBarIconColor)

                Text("Search places, dates, love notes...")
                    .font(.system(size: 16))
                    .foregroundStyle(memorySearchBarPlaceholderColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(memorySearchBarBackground)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var memoryInlineSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(memorySearchBarIconColor)

            TextField(
                "",
                text: $memorySearchText,
                prompt: Text("Search places, dates, love notes...")
                    .foregroundStyle(memorySearchBarPlaceholderColor)
            )
                .font(.system(size: 16))
                .foregroundStyle(memorySearchBarTextColor)
                .tint(memorySearchBarTextColor)
                .focused($isMemorySearchFocused)
                .submitLabel(.search)

            if !memorySearchText.isEmpty {
                Button {
                    memorySearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(memorySearchBarPlaceholderColor)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(memorySearchBarBackground)
        .padding(.horizontal, 20)
    }

    private var memorySearchBarBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                nightModeManager.isNightMode
                    ? Color.white.opacity(0.1)
                    : BabyTownTheme.daySearchBarFill
            )
    }

    @ViewBuilder
    private var inlineMemorySearchResults: some View {
        let rows = cachedMemorySearchRows

        if rows.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        nightModeManager.isNightMode
                            ? .white.opacity(0.35)
                            : BabyTownTheme.textSecondary.opacity(0.5)
                    )

                Text("No memories found")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(nightModeManager.isNightMode ? .white : BabyTownTheme.textPrimary)

                Text("Try a place, date, love note, or prompt")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        nightModeManager.isNightMode
                            ? .white.opacity(0.6)
                            : BabyTownTheme.textSecondary
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
            .padding(.horizontal, 32)
        } else {
            // VStack (not LazyVStack): already inside ScrollView; lazy nesting causes identity glitches.
            VStack(spacing: 24) {
                ForEach(rows) { row in
                    let index = row.displayIndex

                    switch row.item {
                    case .daySection(let section):
                        DayClusterCard(
                            section: section,
                            onOpenPhoto: { moment, allMoments in
                                clearMemoryPageViewerContext()
                                viewerMoments = allMoments
                                if let idx = allMoments.firstIndex(where: { $0.id == moment.id }) {
                                    viewerInitialIndex = idx
                                }
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showingMomentViewer = true
                                }
                            },
                            onEditCaption: { momentId, caption, voiceNotePath in
                                viewModel.updateCaption(for: momentId, caption: caption, voiceNotePath: voiceNotePath)
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
                            onRemove: { section in
                                withAnimation { viewModel.removeMoments(from: section) }
                            },
                            onTogglePin: { section in
                                withAnimation { viewModel.togglePin(for: section, isForeverUnlocked: store.isForeverUnlocked) }
                            },
                            onAddPhotos: { section, images in
                                viewModel.addPhotosToMemory(section: section, images: images)
                            },
                            onRemovePhoto: { section, momentId in
                                viewModel.removePhotoFromMemory(section: section, momentId: momentId)
                            },
                            onSyncMemoryPhotos: { section, assetIds, orphanIds in
                                Task {
                                    await viewModel.syncMemoryPhotos(
                                        section: section,
                                        selectedAssetIds: assetIds,
                                        selectedOrphanMomentIds: orphanIds
                                    )
                                }
                            },
                            onShare: shareMemory,
                            isLeftAligned: index.isMultiple(of: 2),
                            index: index
                        )
                        .padding(
                            .leading,
                            index.isMultiple(of: 2) ? 20 : 46
                        )
                        .padding(
                            .trailing,
                            index.isMultiple(of: 2) ? 46 : 20
                        )
                        .id(row.id)

                    case .promptMemory(let memory):
                        PromptMemoryCard(
                            memory: memory,
                            onTap: {},
                            onOpenPhoto: { photo, _ in
                                openPromptMemoryPage(memory: memory, photo: photo)
                            },
                            onRemove: { memory in
                                withAnimation { viewModel.removePromptMemory(memory) }
                            },
                            onEditMemory: { memoryId, photoId, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                                viewModel.updatePromptMemory(
                                    memoryId: memoryId,
                                    primaryPhotoId: photoId,
                                    loveNote: caption,
                                    placeName: placeName,
                                    latitude: latitude,
                                    longitude: longitude,
                                    isPlaceNameUserSet: isPlaceNameUserSet
                                )
                            },
                            onAddPhotos: { memoryId, images in
                                viewModel.addPhotosToPromptMemory(memoryId: memoryId, images: images)
                            },
                            onRemovePhoto: { memoryId, photoId in
                                viewModel.removePhotoFromPromptMemory(memoryId: memoryId, photoId: photoId)
                            },
                            onSyncMemoryPhotos: { memoryId, assetIds, orphanIds in
                                Task {
                                    await viewModel.syncPromptMemoryPhotos(
                                        memoryId: memoryId,
                                        selectedAssetIds: assetIds,
                                        selectedOrphanMomentIds: orphanIds
                                    )
                                }
                            },
                            onTogglePin: { memory in
                                withAnimation { viewModel.togglePromptMemoryPin(memory) }
                            },
                            onShare: shareMemory,
                            isLeftAligned: index.isMultiple(of: 2),
                            index: index
                        )
                        .padding(
                            .leading,
                            index.isMultiple(of: 2) ? 20 : 46
                        )
                        .padding(
                            .trailing,
                            index.isMultiple(of: 2) ? 46 : 20
                        )
                        .id(row.id)
                    }
                }
            }
            .padding(.top, 12)
            .animation(nil, value: cachedMemorySearchRows.map(\.id))
        }
    }

    // MARK: - Pinned Memories

    private var hasFirstMetPinned: Bool {
        viewModel.pinnedItems.contains { item in
            switch item {
            case .moment(let m, _): return m.promptText == "When we first met"
            case .prompt(let p): return p.promptText == "When we first met"
            }
        }
    }

    private var hasOfficialPinned: Bool {
        viewModel.pinnedItems.contains { item in
            switch item {
            case .moment(let m, _): return m.promptText == "When we became official"
            case .prompt(let p): return p.promptText == "When we became official"
            }
        }
    }

    private var hasOfficialFoundingPhoto: Bool {
        viewModel.moments.contains { $0.promptText == "When we became official" }
    }

    private var hasFirstMetFoundingPhoto: Bool {
        viewModel.moments.contains { $0.promptText == "When we first met" }
    }

    /// Placeholders are for empty slots only — not when a founding photo exists but was unpinned.
    private var showsOfficialPinnedPlaceholder: Bool {
        !hasOfficialPinned && !hasOfficialFoundingPhoto
    }

    private var showsFirstMetPinnedPlaceholder: Bool {
        !hasFirstMetPinned && !hasFirstMetFoundingPhoto
    }

    private var pinnedHomeSpecialDates: [SpecialDate] {
        homeSpecialDates.filter { $0.isPinned && !$0.isBirthday }
    }

    private enum PinnedMemoryRowItem: Identifiable {
        case special(SpecialDate)
        case pinned(PinnedItem)

        var id: String {
            switch self {
            case .special(let date): return "special-\(date.id.uuidString)"
            case .pinned(let item): return "pinned-\(item.id.uuidString)"
            }
        }

        var pinnedAt: Date {
            switch self {
            case .special(let date): return date.pinnedAt ?? .distantPast
            case .pinned(let item): return item.pinnedAt
            }
        }
    }

    private var sortedPinnedMemoryRowItems: [PinnedMemoryRowItem] {
        var rows: [PinnedMemoryRowItem] = pinnedHomeSpecialDates.map { .special($0) }
        rows += viewModel.pinnedItems.map { .pinned($0) }
        return rows.sorted { $0.pinnedAt > $1.pinnedAt }
    }

    private var showsPinnedSection: Bool {
        !viewModel.pinnedItems.isEmpty
            || showsOfficialPinnedPlaceholder
            || showsFirstMetPinnedPlaceholder
            || !pinnedHomeSpecialDates.isEmpty
    }

    private var pinnedSection: some View {
        VStack(spacing: 12) {
            sectionLabel("Pinned Memories", icon: "pin.fill", seeMoreAction: { showPinnedMemoriesFeed = true })
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if showsOfficialPinnedPlaceholder {
                        FoundingPlaceholderCard(
                            title: "When we became official",
                            showsPinnedLabel: true
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showingPinnedViewer = .official
                            }
                        }
                        .frame(width: 180)
                    }

                    if showsFirstMetPinnedPlaceholder {
                        FoundingPlaceholderCard(
                            title: "When we first met",
                            showsPinnedLabel: true
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showingPinnedViewer = .firstMet
                            }
                        }
                        .frame(width: 180)
                    }

                    ForEach(sortedPinnedMemoryRowItems) { row in
                        switch row {
                        case .special(let special):
                            SpecialDateMemoryCard(
                                title: special.title,
                                date: special.date,
                                image: DataPersistenceManager.shared.loadSpecialDatePhoto(id: special.id),
                                isPinned: true,
                                onTap: { openHomeSpecialDate(special) },
                                onShare: { shareHomeSpecialDate(special) },
                                onEdit: { beginEditHomeSpecialDate(special) },
                                onDelete: { deleteHomeSpecialDate(special) },
                                onTogglePin: { toggleHomeSpecialDatePin(special) }
                            )
                            .frame(width: 180)

                        case .pinned(let item):
                            PinnedMemoryCard(
                                item: item,
                                onTap: {
                                    switch item {
                                    case .moment(_, let all):
                                        clearMemoryPageViewerContext()
                                        viewerMoments = all
                                        viewerInitialIndex = 0
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            showingMomentViewer = true
                                        }
                                    case .prompt(let p):
                                        guard let photo = p.photos.first else { return }
                                        openPromptMemoryPage(memory: p, photo: photo)
                                    }
                                },
                                onUnpin: {
                                    withAnimation {
                                        switch item {
                                        case .moment(let m, _):
                                            viewModel.unpinMoment(m)
                                        case .prompt(let p):
                                            viewModel.togglePromptMemoryPin(p)
                                        }
                                    }
                                },
                                onShare: shareMemory
                            )
                            .frame(width: 180)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Section Helpers

    private func sectionLabel(_ text: String, icon: String, showToCButton: Bool = false, seeMoreAction: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(nightModeManager.isNightMode ? .white.opacity(0.9) : .black.opacity(0.9))
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(nightModeManager.isNightMode ? .white : .black)

            Spacer()

            if let seeMoreAction {
                Button(action: seeMoreAction) {
                    HStack(spacing: 4) {
                        Text("See More")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(
                        nightModeManager.isNightMode ? .white.opacity(0.75) : BabyTownTheme.accent
                    )
                }
                .buttonStyle(.plain)
            }

            if showToCButton {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showToC = true
                } label: {
                    Image(systemName: "book.closed")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(BabyTownTheme.accentGradient)
                                .shadow(color: BabyTownTheme.accent.opacity(0.28), radius: 4, y: 2)
                        )
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(BabyTownTheme.accent.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 32)
    }

    // MARK: - Timeline

    private var showsTimelineYearFilter: Bool {
        !isUsingMemorySearch && !viewModel.isEmpty && timelineAvailableYears.count > 1
    }

    private var timelineAvailableYears: [Int] {
        var years = Set(viewModel.availableYears())
        let calendar = Calendar.current
        for special in homeSpecialDates where !special.isPinned {
            years.insert(calendar.component(.year, from: special.date))
        }
        let sorted = years.sorted(by: >)
        guard !sorted.isEmpty else { return [] }
        return [0] + sorted
    }

    private func timelineItemMatchesYear(_ item: TimelineItem, year: Int) -> Bool {
        guard year != 0 else { return true }
        return Calendar.current.component(.year, from: item.yearHeaderDate) == year
    }

    private var filteredMemoryTimelineItems: [TimelineItem] {
        memoryTimelineItems.filter { timelineItemMatchesYear($0, year: selectedTimelineYear) }
    }

    private var filteredBirthdayTimelineItems: [TimelineItem] {
        birthdayTimelineItems.filter { timelineItemMatchesYear($0, year: selectedTimelineYear) }
    }

    private func shouldShowFoundingSlot(_ slot: (promptText: String, moment: Moment?, section: DaySection?)) -> Bool {
        guard selectedTimelineYear != 0 else { return true }
        guard let moment = slot.moment else { return false }
        return Calendar.current.component(.year, from: moment.dateTaken) == selectedTimelineYear
    }

    private var filteredFoundingTimelineSlots: [(promptText: String, moment: Moment?, section: DaySection?)] {
        viewModel.foundingTimelineSlots.filter(shouldShowFoundingSlot)
    }

    private func updateYearFilterPinState(minY: CGFloat) {
        guard showsTimelineYearFilter else {
            if isYearFilterPinned {
                isYearFilterPinned = false
            }
            return
        }

        let shouldPin = minY <= 0.5
        guard shouldPin != isYearFilterPinned else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isYearFilterPinned = shouldPin
        }
    }

    private func timelineYearFilterBar(isPinned: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(timelineAvailableYears, id: \.self) { year in
                    YearFilterChip(
                        title: year == 0 ? "All" : String(year),
                        isSelected: year == selectedTimelineYear
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTimelineYear = year
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .background {
            if isPinned {
                Rectangle()
                    .fill(
                        nightModeManager.isNightMode
                            // Match the night sky's top gradient color so the pinned bar
                            // blends in instead of showing a black strip, while still
                            // masking the memories scrolling underneath.
                            ? Color(red: 0.05, green: 0.08, blue: 0.15)
                            : BabyTownTheme.background
                    )
            }
        }
        .contentShape(Rectangle())
    }

    private var timelineSection: some View {
        VStack(spacing: 12) {
            sectionLabel(
                nightModeManager.isNightMode ? "Our Dreams 🌙" : "Our Adventures",
                icon: "heart.text.square",
                showToCButton: true
            )
            .padding(.horizontal, 20)
            .id("timeline")

            if showsTimelineYearFilter {
                timelineYearFilterBar(isPinned: false)
                    .opacity(isYearFilterPinned ? 0 : 1)
                    .allowsHitTesting(!isYearFilterPinned)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: TimelineYearFilterAnchorKey.self,
                                value: geometry.frame(in: .named("homeScroll")).minY
                            )
                        }
                    }
            }

            ZStack(alignment: .top) {
                HeartTrailBackground(
                    sectionCount: filteredMemoryTimelineItems.count
                        + filteredBirthdayTimelineItems.count
                        + filteredFoundingTimelineSlots.count
                )

                let memoryRows = paginatedMemoryTimelineRows
                let birthdayRows = birthdayTimelineRows
                LazyVStack(spacing: 24) {
                    if filteredMemoryTimelineItems.isEmpty && selectedTimelineYear != 0 {
                        Text("No memories from \(selectedTimelineYear) yet.")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .foregroundStyle(
                                nightModeManager.isNightMode
                                    ? .white.opacity(0.7)
                                    : BabyTownTheme.textPrimary.opacity(0.65)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 32)
                            .padding(.top, 24)
                    }

                    ForEach(memoryRows) { row in
                        let index = row.displayIndex
                        if selectedTimelineYear == 0, let year = row.yearHeader {
                            yearHeaderView(year)
                        }

                        switch row.item {
                        case .daySection(let section):
                            VStack(spacing: 16) {
                                DayClusterCard(
                                    section: section,
                                    onOpenPhoto: { moment, allMoments in
                                        if vaultedIDs.contains(moment.id) {
                                            showVaultedPrompt = true
                                        } else {
                                            clearMemoryPageViewerContext()
                                            viewerMoments = allMoments
                                            if let idx = allMoments.firstIndex(where: { $0.id == moment.id }) {
                                                viewerInitialIndex = idx
                                            }
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                showingMomentViewer = true
                                            }
                                        }
                                    },
                                    onEditCaption: { momentId, caption, voiceNotePath in
                                        viewModel.updateCaption(for: momentId, caption: caption, voiceNotePath: voiceNotePath)
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
                                    onRemove: { section in
                                        withAnimation {
                                            viewModel.removeMoments(from: section)
                                        }
                                    },
                                    onTogglePin: { section in
                                        withAnimation {
                                            viewModel.togglePin(for: section, isForeverUnlocked: store.isForeverUnlocked)
                                        }
                                    },
                                    onAddPhotos: { section, images in
                                        viewModel.addPhotosToMemory(section: section, images: images)
                                    },
                                    onRemovePhoto: { section, momentId in
                                        viewModel.removePhotoFromMemory(section: section, momentId: momentId)
                                    },
                                    onSyncMemoryPhotos: { section, assetIds, orphanIds in
                                        Task {
                                            await viewModel.syncMemoryPhotos(
                                                section: section,
                                                selectedAssetIds: assetIds,
                                                selectedOrphanMomentIds: orphanIds
                                            )
                                        }
                                    },
                                    onShare: shareMemory,
                                    isLeftAligned: index.isMultiple(of: 2),
                                    index: index,
                                    isVaulted: section.moments.contains { vaultedIDs.contains($0.id) }
                                )
                                .padding(
                                    .leading,
                                    index.isMultiple(of: 2) ? 20 : 46
                                )
                                .padding(
                                    .trailing,
                                    index.isMultiple(of: 2) ? 46 : 20
                                )
                            }


                        case .promptMemory(let memory):
                            PromptMemoryCard(
                                memory: memory,
                                onTap: {
                                    // TODO: Open prompt memory detail view
                                },
                                onOpenPhoto: { photo, _ in
                                    openPromptMemoryPage(memory: memory, photo: photo)
                                },
                                onRemove: { memory in
                                    withAnimation {
                                        viewModel.removePromptMemory(memory)
                                    }
                                },
                                onEditMemory: { memoryId, photoId, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                                    viewModel.updatePromptMemory(
                                        memoryId: memoryId,
                                        primaryPhotoId: photoId,
                                        loveNote: caption,
                                        placeName: placeName,
                                        latitude: latitude,
                                        longitude: longitude,
                                        isPlaceNameUserSet: isPlaceNameUserSet
                                    )
                                },
                                onAddPhotos: { memoryId, images in
                                    viewModel.addPhotosToPromptMemory(memoryId: memoryId, images: images)
                                },
                                onRemovePhoto: { memoryId, photoId in
                                    viewModel.removePhotoFromPromptMemory(memoryId: memoryId, photoId: photoId)
                                },
                                onSyncMemoryPhotos: { memoryId, assetIds, orphanIds in
                                    Task {
                                        await viewModel.syncPromptMemoryPhotos(
                                            memoryId: memoryId,
                                            selectedAssetIds: assetIds,
                                            selectedOrphanMomentIds: orphanIds
                                        )
                                    }
                                },
                                onTogglePin: { memory in
                                    withAnimation {
                                        viewModel.togglePromptMemoryPin(memory)
                                    }
                                },
                                onShare: shareMemory,
                                isLeftAligned: index.isMultiple(of: 2),
                                index: index
                            )
                            .padding(
                                .leading,
                                index.isMultiple(of: 2) ? 20 : 46
                            )
                            .padding(
                                .trailing,
                                index.isMultiple(of: 2) ? 46 : 20
                            )
                            
                        case .processingMemory(let memory):
                            ProcessingMemoryCard(
                                memory: memory,
                                pendingCount: viewModel.processingMemoryCount,
                                image: viewModel.polaroidStore.loadImage(for: PolaroidEntry(
                                    id: memory.id,
                                    capturedAt: memory.date,
                                    imageFileName: memory.imageFileName,
                                    released: false
                                )),
                                onUnlock: {
                                    viewModel.checkAndReleasePhotos()
                                }
                            )
                            .padding(
                                .leading,
                                index.isMultiple(of: 2) ? 20 : 46
                            )
                            .padding(
                                .trailing,
                                index.isMultiple(of: 2) ? 46 : 20
                            )

                        case .specialDate(let special):
                            SpecialDateMemoryCard(
                                title: special.title,
                                date: special.date,
                                image: DataPersistenceManager.shared.loadSpecialDatePhoto(id: special.id),
                                style: .timeline,
                                isPinned: special.isPinned,
                                isLeftAligned: index.isMultiple(of: 2),
                                index: index,
                                onTap: { openHomeSpecialDate(special) },
                                onShare: { shareHomeSpecialDate(special) },
                                onEdit: { beginEditHomeSpecialDate(special) },
                                onDelete: { deleteHomeSpecialDate(special) },
                                onTogglePin: { toggleHomeSpecialDatePin(special) }
                            )
                            .padding(
                                .leading,
                                index.isMultiple(of: 2) ? 20 : 46
                            )
                            .padding(
                                .trailing,
                                index.isMultiple(of: 2) ? 46 : 20
                            )
                        }
                    }

                    if hasMoreTimelineItems {
                        loadOlderMemoriesButton
                    }

                    if !hasMoreTimelineItems {
                    // "The Beginning..." after regular memories (newest-first above)
                    if selectedTimelineYear == 0 || !filteredFoundingTimelineSlots.isEmpty {
                    HStack(spacing: 8) {
                        HeartbeatIconView()

                        TypingTextView(
                            text: "The Beginning...",
                            font: .system(size: 15, weight: .medium, design: .serif),
                            color: foundingMomentTitleColor
                        )

                        Spacer()
                    }
                    .padding(.leading, 32)
                    .padding(.top, 8)

                    // Founding moments anchored at the very bottom
                    ForEach(Array(filteredFoundingTimelineSlots.enumerated()), id: \.offset) { _, slot in
                        if let section = slot.section, let moment = slot.moment {
                        VStack(spacing: 12) {
                            DayClusterCard(
                                section: section,
                                onOpenPhoto: { moment, allMoments in
                                    clearMemoryPageViewerContext()
                                    viewerMoments = allMoments
                                    if let i = allMoments.firstIndex(where: { $0.id == moment.id }) {
                                        viewerInitialIndex = i
                                    }
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showingMomentViewer = true
                                    }
                                },
                                onEditCaption: { momentId, caption, voiceNotePath in
                                    viewModel.updateCaption(for: momentId, caption: caption, voiceNotePath: voiceNotePath)
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
                                onRemove: { section in
                                    withAnimation {
                                        viewModel.removeMoments(from: section)
                                    }
                                },
                                onTogglePin: { section in
                                    withAnimation {
                                        viewModel.togglePin(for: section, isForeverUnlocked: store.isForeverUnlocked)
                                    }
                                },
                                onAddPhotos: { section, images in
                                    viewModel.addPhotosToMemory(section: section, images: images)
                                },
                                onRemovePhoto: { section, momentId in
                                    viewModel.removePhotoFromMemory(section: section, momentId: momentId)
                                },
                                onSyncMemoryPhotos: { section, assetIds, orphanIds in
                                    Task {
                                        await viewModel.syncMemoryPhotos(
                                            section: section,
                                            selectedAssetIds: assetIds,
                                            selectedOrphanMomentIds: orphanIds
                                        )
                                    }
                                },
                                onShare: shareMemory
                            )
                            .padding(.horizontal, 20)

                            foundingMomentLabel(moment)
                        }
                        .padding(.top, 16)
                        } else {
                            VStack(spacing: 12) {
                                FoundingPlaceholderCard(
                                    title: slot.promptText,
                                    showsPinnedLabel: false
                                ) {
                                    openFoundingPhotoPicker(for: slot.promptText)
                                }
                                .padding(.horizontal, 20)

                                foundingMomentLabelPlaceholder(promptText: slot.promptText)
                            }
                            .padding(.top, 16)
                        }
                    }
                    }

                    // Birthdays — oldest anchor at the absolute bottom (below founding)
                    ForEach(birthdayRows) { row in
                        let index = row.displayIndex
                        if selectedTimelineYear == 0, let year = row.yearHeader {
                            yearHeaderView(year)
                        }

                        if case .specialDate(let special) = row.item {
                            SpecialDateMemoryCard(
                                title: special.title,
                                date: special.date,
                                image: DataPersistenceManager.shared.loadSpecialDatePhoto(id: special.id),
                                style: .timeline,
                                isPinned: false,
                                isLeftAligned: index.isMultiple(of: 2),
                                index: index,
                                onTap: { openHomeSpecialDate(special) },
                                onShare: { shareHomeSpecialDate(special) },
                                onEdit: { beginEditHomeSpecialDate(special) },
                                onDelete: { deleteHomeSpecialDate(special) },
                                onTogglePin: nil
                            )
                            .padding(
                                .leading,
                                index.isMultiple(of: 2) ? 20 : 46
                            )
                            .padding(
                                .trailing,
                                index.isMultiple(of: 2) ? 46 : 20
                            )
                        }
                    }
                    }
                }
            }
        }
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

    private func foundingMomentLabelPlaceholder(promptText: String) -> some View {
        HStack(spacing: 8) {
            HeartbeatIconView()

            VStack(alignment: .leading, spacing: 4) {
                Text(promptText)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(foundingMomentTitleColor)

                Text("Tap to add your photo")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(foundingMomentDateColor)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var foundingMomentTitleColor: Color {
        nightModeManager.isNightMode
            ? .white.opacity(0.95)
            : BabyTownTheme.textPrimary.opacity(0.85)
    }

    private var foundingMomentDateColor: Color {
        nightModeManager.isNightMode
            ? .white.opacity(0.82)
            : BabyTownTheme.textPrimary.opacity(0.5)
    }

    private func foundingMomentLabel(_ moment: Moment) -> some View {
        HStack(spacing: 8) {
            HeartbeatIconView()

            VStack(alignment: .leading, spacing: 4) {
                Text(moment.promptText ?? "")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(foundingMomentTitleColor)

                Text(foundingDateString(moment.dateTaken))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(foundingMomentDateColor)
            }

            Spacer()
        }
        .padding(.leading, 32)
        .padding(.vertical, 12)
    }

    private func foundingDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date)
    }
    
    private enum TimelineItem {
        case daySection(DaySection)
        case promptMemory(PromptMemory)
        case processingMemory(ProcessingMemory)
        case specialDate(SpecialDate)
        
        var date: Date {
            switch self {
            case .daySection(let section):
                return section.timelineSortDate
            case .promptMemory(let memory):
                return memory.date
            case .processingMemory(let memory):
                return memory.date
            case .specialDate(let special):
                return special.timelineSortDate
            }
        }

        /// Year divider label — always the real event year (e.g. 1999 birth year).
        var yearHeaderDate: Date {
            switch self {
            case .specialDate(let special):
                return special.date
            default:
                return date
            }
        }

        var isBirthday: Bool {
            if case .specialDate(let special) = self {
                return special.isBirthday
            }
            return false
        }

        var stableId: String {
            switch self {
            case .daySection(let section):
                return "day-\(section.id)"
            case .promptMemory(let memory):
                return "prompt-\(memory.id.uuidString)"
            case .processingMemory(let memory):
                return "processing-\(memory.id.uuidString)"
            case .specialDate(let special):
                return "special-\(special.id.uuidString)"
            }
        }

        var stableSortKey: String { stableId }
    }
    
    /// Unpinned special dates only — pinned ones live in the pinned strip.
    private var timelineSpecialDates: [SpecialDate] {
        homeSpecialDates.filter { !$0.isPinned }
    }

    private struct TimelinePagingSignal: Equatable {
        let offsetY: CGFloat
        let distanceFromBottom: CGFloat
    }

    private var hasMoreTimelineItems: Bool {
        visibleRowCount < filteredMemoryTimelineItems.count
    }

    /// Manual "load more" fallback. Auto-loading is driven by scroll position as the user
    /// nears the bottom; this button covers any case where that didn't fire.
    private var loadOlderMemoriesButton: some View {
        Button(action: loadMoreTimelineRows) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                Text("Load older memories")
            }
            .font(.system(size: 15, weight: .medium, design: .serif))
            .foregroundStyle(
                nightModeManager.isNightMode
                    ? .white.opacity(0.85)
                    : BabyTownTheme.textPrimary.opacity(0.7)
            )
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
        .padding(.top, 8)
    }

    /// Photos and non-birthday special dates — newest first.
    private var memoryTimelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        
        items += viewModel.daySections.map { .daySection($0) }
        items += viewModel.promptMemories.map { .promptMemory($0) }
        items += timelineSpecialDates.filter { !$0.isBirthday }.map { .specialDate($0) }
        if let processingMemory = viewModel.processingMemoryForTimeline {
            items.append(.processingMemory(processingMemory))
        }
        
        return HomeTimelineOrdering.sorted(items) { item in
            HomeTimelineOrdering.SortableItem(
                date: item.date,
                stableKey: item.stableSortKey,
                isProcessing: isProcessingMemory(item),
                isBirthday: false
            )
        }
    }

    /// Birthdays are rendered in a fixed block above founding moments, never mixed into the main feed.
    private var birthdayTimelineItems: [TimelineItem] {
        timelineSpecialDates
            .filter(\.isBirthday)
            .sorted { lhs, rhs in
                if lhs.timelineSortDate != rhs.timelineSortDate {
                    return lhs.timelineSortDate > rhs.timelineSortDate
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { .specialDate($0) }
    }
    
    private func isProcessingMemory(_ item: TimelineItem) -> Bool {
        if case .processingMemory = item {
            return true
        }
        return false
    }

    private struct TimelineRow: Identifiable {
        let id: String
        let item: TimelineItem
        let yearHeader: String?
        let displayIndex: Int
    }

    /// Builds timeline rows and precomputes year-header boundaries in a single pass.
    private func buildTimelineRows(from items: [TimelineItem], startingDisplayIndex: Int = 0) -> [TimelineRow] {
        let calendar = Calendar.current
        var rows: [TimelineRow] = []
        rows.reserveCapacity(items.count)

        var previousYear: Int? = nil
        for (offset, item) in items.enumerated() {
            let year = calendar.component(.year, from: item.yearHeaderDate)
            let header: String? = (year != previousYear) ? String(year) : nil
            previousYear = year
            rows.append(TimelineRow(
                id: item.stableId,
                item: item,
                yearHeader: header,
                displayIndex: startingDisplayIndex + offset
            ))
        }
        return rows
    }

    /// Only the visible page is turned into rows — year-header boundaries are computed
    /// within the prefix, which preserves correctness since rows stay newest-first.
    private var paginatedMemoryTimelineRows: [TimelineRow] {
        buildTimelineRows(from: Array(filteredMemoryTimelineItems.prefix(visibleRowCount)))
    }

    /// Grow the visible window by one page. Called by the load-more button's `.onAppear`
    /// (auto on scroll) and its tap action (manual fallback). Clamped to the total.
    private func loadMoreTimelineRows() {
        guard hasMoreTimelineItems else { return }
        visibleRowCount = min(visibleRowCount + Self.timelinePageSize, filteredMemoryTimelineItems.count)
    }

    private func clampVisibleRowCount() {
        let total = filteredMemoryTimelineItems.count
        if total > 0, visibleRowCount > total {
            visibleRowCount = total
        }
    }

    private var birthdayTimelineRows: [TimelineRow] {
        let foundingCount = filteredFoundingTimelineSlots.count
        return buildTimelineRows(
            from: filteredBirthdayTimelineItems,
            startingDisplayIndex: filteredMemoryTimelineItems.count + foundingCount
        )
    }

    private func yearHeaderView(_ year: String) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(BabyTownTheme.accent.opacity(0.15))
                .frame(height: 1)

            Text(year)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(nightModeManager.isNightMode ? .white.opacity(0.7) : BabyTownTheme.textPrimary.opacity(0.6))

            Rectangle()
                .fill(BabyTownTheme.accent.opacity(0.15))
                .frame(height: 1)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 40)

            PulsingHeartView()
                .frame(height: 70)

            Text("Ready to add our moments?")
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundStyle(.white)

            Text("Tap Select Photos and I'll build our love timeline.")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var cameraButton: some View {
        VStack {
            Spacer()
                .allowsHitTesting(false)

            Button {
                if !viewModel.polaroidStore.canCapturePhoto() {
                    showCameraSheet = true
                } else {
                    showCameraFullScreen = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(BabyTownTheme.accentIconBackdropGradient)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle().stroke(BabyTownTheme.accent.opacity(0.25), lineWidth: 1.5)
                        )
                        .shadow(color: BabyTownTheme.buttonShadow, radius: 12, y: 4)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea()
    }
    
    private var upButton: some View {
        VStack {
            Spacer()
                .allowsHitTesting(false)

            HStack {
                Spacer()
                    .allowsHitTesting(false)

                Button {
                    scrollToTop = true
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(BabyTownTheme.accentGradient)
                                .frame(width: 50, height: 50)
                        )
                        .shadow(color: BabyTownTheme.accent.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
    }

    private func clearMemoryPageViewerContext() {
        viewerMemoryPagePromptText = nil
        viewerImportantDate = nil
        viewerPromptMemoryId = nil
    }

    private func openPromptMemoryPage(memory: PromptMemory, photo: PromptPhoto) {
        let moments = memory.sortedViewerMoments
        guard !moments.isEmpty else { return }
        clearMemoryPageViewerContext()
        viewerMoments = moments
        viewerInitialIndex = moments.firstIndex(where: { $0.id == photo.id }) ?? 0
        viewerMemoryPagePromptText = memory.promptText
        viewerPromptMemoryId = memory.id
        withAnimation(.easeInOut(duration: 0.25)) {
            showingMomentViewer = true
        }
    }

    private func openImportantDateMemoryPage(
        title: String,
        date: Date,
        image: UIImage,
        itemId: String
    ) {
        clearMemoryPageViewerContext()
        viewerMoments = [
            MemoryPageMomentFactory.moment(
                image: image,
                importantDate: MemoryPageImportantDateInfo(title: title, date: date),
                itemId: itemId
            )
        ]
        viewerInitialIndex = 0
        viewerImportantDate = MemoryPageImportantDateInfo(title: title, date: date)
        withAnimation(.easeInOut(duration: 0.25)) {
            showingMomentViewer = true
        }
    }

    private var momentPhotoViewerOverlay: some View {
        MomentPhotoViewer(
            moments: viewerMoments,
            initialIndex: viewerInitialIndex,
            onDismiss: {
                withAnimation(.easeOut(duration: 0.25)) {
                    showingMomentViewer = false
                    clearMemoryPageViewerContext()
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
            },
            memoryPagePromptText: viewerMemoryPagePromptText,
            memoryPageImportantDate: viewerImportantDate,
            promptMemoryId: viewerPromptMemoryId,
            onEditPromptMemory: { memoryId, _, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                viewModel.updatePromptMemory(
                    memoryId: memoryId,
                    primaryPhotoId: viewerMoments.first?.id ?? UUID(),
                    loveNote: caption,
                    placeName: placeName,
                    latitude: latitude,
                    longitude: longitude,
                    isPlaceNameUserSet: isPlaceNameUserSet
                )
            },
            onAddPromptPhotos: { memoryId, images in
                viewModel.addPhotosToPromptMemory(memoryId: memoryId, images: images)
            },
            onRemovePromptPhoto: { memoryId, photoId in
                viewModel.removePhotoFromPromptMemory(memoryId: memoryId, photoId: photoId)
            },
            onSyncPromptMemoryPhotos: { memoryId, assetIds, orphanIds in
                await viewModel.syncPromptMemoryPhotos(
                    memoryId: memoryId,
                    selectedAssetIds: assetIds,
                    selectedOrphanMomentIds: orphanIds
                )
            },
            onReloadPromptMoments: {
                guard let memoryId = viewerPromptMemoryId,
                      let memory = viewModel.promptMemories.first(where: { $0.id == memoryId }) else {
                    return viewerMoments
                }
                return memory.sortedViewerMoments
            }
        )
    }
}

// MARK: - Pulsing Heart (Empty State)

private struct PulsingHeartView: View {

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 40))
            .foregroundStyle(
                BabyTownTheme.accent.opacity(0.3)
            )
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.6)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.18
                }
            }
    }
}

private struct TimelineYearFilterAnchorKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

// MARK: - Previews

#Preview("Filled") {
    HomeView(viewModel: .filledPreview)
}

#Preview("Empty") {
    HomeView(viewModel: .emptyPreview)
}
