import SwiftUI
import PhotosUI
import Photos

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
    @State private var showPartnerPaywall = false
    @ObservedObject private var store = StoreManager.shared
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
    @State private var showingPromptPhotoViewer = false
    @State private var viewerPromptPhotos: [PromptPhoto] = []
    @State private var viewerPromptPhotoIndex = 0
    @State private var viewerPromptText: String? = nil
    @State private var showPromptSheet = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showUpButton = false
    @State private var scrollToNewMemory = false
    @State private var showNotifications = false
    @State private var hasUnreadNotifications = AppNotification.hasUnread()
    @State private var showOnThisDayViewer = false
    @State private var onThisDayPhotos: [Moment] = []
    @State private var onThisDayStartIndex = 0
    @State private var showScan = false
    @State private var showMapView = false
    @State private var showToC = false
    @State private var peakPullOffset: CGFloat = 0
    @State private var didCrossMapOpenThreshold = false
    @State private var mapThresholdHapticTick = 0
    @State private var mapOpenHapticTick = 0
    
    private let mapOpenThreshold: CGFloat = 110


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

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: isMemorySearchActive ? 16 : 28) {
                                if !isUsingMemorySearch {
                                    MapPullHintView(
                                        progress: min(currentPullProgress, 1),
                                        isVisible: scrollOffset > -24 && scrollOffset < 30 && !showMapView,
                                        isNightMode: nightModeManager.isNightMode
                                    )
                                }

                                if !isSearchBarPinned {
                                    memorySearchBarPlaceholder
                                }

                                if isMemorySearchActive {
                                    inlineMemorySearchResults
                                } else {
                                    if !store.isPartnerUnlocked {
                                        InvitePartnerBanner {
                                            showPartnerPaywall = true
                                        }
                                    }

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
                            if isMemorySearchActive {
                                rebuildMemorySearchRowsCache()
                            }
                        }
                        .onChange(of: viewModel.promptMemories.count) { _, _ in
                            if isMemorySearchActive {
                                rebuildMemorySearchRowsCache()
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
                    }
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: mapThresholdHapticTick)
                .sensoryFeedback(.success, trigger: mapOpenHapticTick)
                .onAppear {
                    viewModel.checkAndReleasePhotos()
                    viewModel.refreshOnThisDay()
                    AudioManager.shared.playHomeMusic()
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
                        }
                    )
                    .transition(.opacity)
                    .zIndex(11)
                }
                
                if showingPromptPhotoViewer {
                    PromptPhotoViewer(
                        photos: viewerPromptPhotos,
                        initialIndex: viewerPromptPhotoIndex,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showingPromptPhotoViewer = false
                            }
                        },
                        onUpdatePhotos: { updatedPhotos in
                            viewModel.updatePromptMemoryPhotos(viewerPromptPhotos, with: updatedPhotos)
                        },
                        onDeletePhoto: { photo in
                            withAnimation {
                                viewModel.deletePromptPhoto(photo, from: viewerPromptPhotos)
                            }
                        },
                        promptText: viewerPromptText
                    )
                    .transition(.opacity)
                    .zIndex(12)
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
                                latitude: moment.latitude, longitude: moment.longitude, isAddedFromOnThisDay: true
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

                if showVisitPet {
                    visitPetOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(25)
                        .transition(.opacity)
                }
            } // Close ZStack
            .animation(.easeInOut(duration: 0.3), value: showMapView)
            .animation(.easeInOut(duration: 0.3), value: showVisitPet)
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
                    onVisitPet: { showVisitPet = true }
                )
            }
            .fullScreenCover(isPresented: $showPartnerPaywall) {
                InvitePartnerPaywallView(
                    store: store,
                    onUnlock: { showPartnerPaywall = false },
                    onDismiss: { showPartnerPaywall = false }
                )
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
            .sheet(isPresented: $showToC) {
                TableOfContentsView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .memorySharePresentation(coordinator: shareCoordinator)
        }
    }

    private func shareMemory(_ payload: MemorySharePayload) {
        shareCoordinator.share(payload)
    }
    
    // MARK: - Map pull reveal

    @ViewBuilder
    private var visitPetOverlay: some View {
        NavigationStack {
            AdoptAPetRootView {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showVisitPet = false
                }
            }
        }
        .background(BabyTownTheme.background.ignoresSafeArea())
    }
    
    @ViewBuilder
    private var memoryMapOverlay: some View {
        ZStack {
            MapView(
                viewModel: viewModel,
                onOpenMemory: { section in
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
                    }
                )
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

        // Avoid re-rendering search results on every scroll frame (causes card recycling glitches).
        if !isMemorySearchActive {
            scrollOffset = topOffset
        }

        guard !isUsingMemorySearch else {
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
        guard !showVisitPet else { return }
        mapOpenHapticTick += 1
        withAnimation(.easeInOut(duration: 0.3)) {
            showVisitPet = true
        }
    }

    private func dismissSearchKeyboardIfScrolling(from previousOffset: CGFloat, to offset: CGFloat) {
        guard isMemorySearchFocused else { return }
        guard abs(offset - previousOffset) > 2 else { return }
        isMemorySearchFocused = false
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
                                withAnimation { viewModel.togglePin(for: section) }
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
                            onOpenPhoto: { photo, allPhotos in
                                if let photoIndex = allPhotos.firstIndex(where: { $0.id == photo.id }) {
                                    viewerPromptPhotos = allPhotos
                                    viewerPromptPhotoIndex = photoIndex
                                    viewerPromptText = memory.promptText
                                    withAnimation(.easeIn(duration: 0.25)) {
                                        showingPromptPhotoViewer = true
                                    }
                                }
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

    private var showsPinnedSection: Bool {
        !viewModel.pinnedItems.isEmpty || showsOfficialPinnedPlaceholder || showsFirstMetPinnedPlaceholder
    }

    private var pinnedSection: some View {
        VStack(spacing: 12) {
            sectionLabel("Pinned Memories", icon: "pin.fill")
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

                    ForEach(viewModel.pinnedItems) { item in
                        PinnedMemoryCard(
                            item: item,
                            onTap: {
                                switch item {
                                case .moment(_, let all):
                                    viewerMoments = all
                                    viewerInitialIndex = 0
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showingMomentViewer = true
                                    }
                                case .prompt(let p):
                                    viewerPromptPhotos = p.photos
                                    viewerPromptPhotoIndex = 0
                                    viewerPromptText = p.promptText
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showingPromptPhotoViewer = true
                                    }
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
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Section Helpers

    private func sectionLabel(_ text: String, icon: String, showToCButton: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(nightModeManager.isNightMode ? .white.opacity(0.9) : .black.opacity(0.9))
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(nightModeManager.isNightMode ? .white : .black)
            
            Spacer()
            
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

    private var timelineSection: some View {
        VStack(spacing: 12) {
            sectionLabel(
                nightModeManager.isNightMode ? "Our Dreams 🌙" : "Our Adventures",
                icon: "heart.text.square",
                showToCButton: true
            )
            .padding(.horizontal, 20)
            .id("timeline")

            ZStack(alignment: .top) {
                HeartTrailBackground(
                    sectionCount: viewModel.daySections.count + viewModel.promptMemories.count + (viewModel.processingMemoryForTimeline != nil ? 1 : 0) + viewModel.foundingTimelineSlots.count
                )

                let rows = timelineRows
                LazyVStack(spacing: 24) {
                    ForEach(rows) { row in
                        let index = row.displayIndex
                        if let year = row.yearHeader {
                            yearHeaderView(year)
                        }

                        switch row.item {
                        case .daySection(let section):
                            VStack(spacing: 16) {
                                DayClusterCard(
                                    section: section,
                                    onOpenPhoto: { moment, allMoments in
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
                                        withAnimation {
                                            viewModel.removeMoments(from: section)
                                        }
                                    },
                                    onTogglePin: { section in
                                        withAnimation {
                                            viewModel.togglePin(for: section)
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
                            }


                        case .promptMemory(let memory):
                            PromptMemoryCard(
                                memory: memory,
                                onTap: {
                                    // TODO: Open prompt memory detail view
                                },
                                onOpenPhoto: { photo, allPhotos in
                                    if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
                                        viewerPromptPhotos = allPhotos
                                        viewerPromptPhotoIndex = index
                                        viewerPromptText = memory.promptText
                                        withAnimation(.easeIn(duration: 0.25)) {
                                            showingPromptPhotoViewer = true
                                        }
                                    }
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
                        }
                    }

                    // "The Beginning..." after the last regular item
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
                    ForEach(Array(viewModel.foundingTimelineSlots.enumerated()), id: \.offset) { _, slot in
                        if let section = slot.section, let moment = slot.moment {
                        VStack(spacing: 12) {
                            DayClusterCard(
                                section: section,
                                onOpenPhoto: { moment, allMoments in
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
                                        viewModel.togglePin(for: section)
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
        
        var date: Date {
            switch self {
            case .daySection(let section):
                return section.timelineSortDate
            case .promptMemory(let memory):
                return memory.date
            case .processingMemory(let memory):
                return memory.date
            }
        }

        var stableId: String {
            switch self {
            case .daySection(let section):
                return "day-\(section.id)"
            case .promptMemory(let memory):
                return "prompt-\(memory.id.uuidString)"
            case .processingMemory(let memory):
                return "processing-\(memory.id.uuidString)"
            }
        }

        var stableSortKey: String { stableId }
    }
    
    private var combinedTimelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        
        items += viewModel.daySections.map { .daySection($0) }
        items += viewModel.promptMemories.map { .promptMemory($0) }
        if let processingMemory = viewModel.processingMemoryForTimeline {
            items.append(.processingMemory(processingMemory))
        }
        
        // Sort with processing memories at the top until 9:00 PM
        return items.sorted { item1, item2 in
            let isProcessing1 = isProcessingMemory(item1)
            let isProcessing2 = isProcessingMemory(item2)
            
            // If one is processing and the other isn't, processing comes first
            if isProcessing1 && !isProcessing2 {
                return true
            } else if !isProcessing1 && isProcessing2 {
                return false
            }
            
            // Otherwise sort by date (newest first), with stable tiebreaker
            if item1.date != item2.date {
                return item1.date > item2.date
            }
            return item1.stableSortKey < item2.stableSortKey
        }
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

    /// Builds the sorted timeline once and precomputes year-header boundaries in a single
    /// pass. Replaces the old per-item `yearHeaderForItem`, which re-sorted the whole list
    /// for every row (O(N²) per render).
    private var timelineRows: [TimelineRow] {
        let items = combinedTimelineItems
        let calendar = Calendar.current
        var rows: [TimelineRow] = []
        rows.reserveCapacity(items.count)

        var previousYear: Int? = nil
        for (displayIndex, item) in items.enumerated() {
            let year = calendar.component(.year, from: item.date)
            let header: String? = (year != previousYear) ? String(year) : nil
            previousYear = year
            rows.append(TimelineRow(
                id: item.stableId,
                item: item,
                yearHeader: header,
                displayIndex: displayIndex
            ))
        }
        return rows
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
                        .foregroundStyle(BabyTownTheme.accentIconGradient)
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea()
    }
    
    private var upButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button {
                    scrollToNewMemory = true
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

// MARK: - Founding Placeholder Card

private struct FoundingPlaceholderCard: View {

    let title: String
    var showsPinnedLabel: Bool = false
    var onTap: () -> Void
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [BabyTownTheme.accent.opacity(0.12), BabyTownTheme.accent.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 150)

                VStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(BabyTownTheme.accent.opacity(0.4))
                        .scaleEffect(pulse ? 1.1 : 1.0)

                    Text("Add Photo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(2)

                if showsPinnedLabel {
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
                .strokeBorder(BabyTownTheme.accent.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Filled") {
    HomeView(viewModel: .filledPreview)
}

#Preview("Empty") {
    HomeView(viewModel: .emptyPreview)
}
