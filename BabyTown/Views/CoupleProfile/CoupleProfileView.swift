import SwiftUI
import PhotosUI
import Photos
import GardenCore

/// The Couples Profile Page: a full-screen living-garden background with draggable
/// photo stickers, a floating header, and scrolling glass cards.
struct CoupleProfileView: View {
    var homeViewModel: HomeViewModel?
    var onBack: () -> Void = {}

    @ObservedObject private var store = StoreManager.shared
    @StateObject private var shareCoordinator = MemoryShareCoordinator()
    @State private var showPartnerPaywall = false
    @State private var showInviteFlow = false

    @State private var profile = CoupleProfile()
    @State private var userAvatar: UIImage?
    @State private var stickerImages: [UUID: UIImage] = [:]
    @State private var isCustomizing = false
    @State private var selectedStickerID: UUID?
    @State private var isNoteSelected = false
    @State private var isRecordPlayerSelected = false
    @State private var isWatchTogetherTVSelected = false
    @State private var isPreludeBookSelected = false
    @State private var showPreludeGiftBook = false
    @State private var showWatchTogetherSheet = false
    @State private var showWatchTogetherPaywall = false
    /// Sticker image files to delete from disk only when the user taps Save.
    @State private var pendingImageDeletions: Set<UUID> = []
    @State private var showEditProfile = false
    @State private var showVisitPet = false
    @State private var showStickerPicker = false
    @State private var showProfileNoteEditor = false
    @State private var showOurSongSheet = false

    @ObservedObject private var musicPlaybackState = CoupleMusicPlaybackState.shared
    @StateObject private var nightModeManager = NightModeManager()

    @State private var dateEditorPresentation: SpecialDateEditorPresentation?
    @State private var activeSubpage: CoupleProfileSubpage?

    @State private var showingPinnedViewer: PinnedMemoryType?
    @State private var firstMetPickerItem: PhotosPickerItem?
    @State private var officialPickerItem: PhotosPickerItem?
    @State private var showingMomentViewer = false
    @State private var viewerMoments: [Moment] = []
    @State private var viewerInitialIndex = 0
    @State private var viewerMemoryPagePromptText: String?
    @State private var viewerImportantDate: MemoryPageImportantDateInfo?
    @State private var viewerPromptMemoryId: UUID?

    private var dpm: DataPersistenceManager { .shared }

    private var stickerCanvasHeight: CGFloat { ProfileGardenLayout.stickerCanvasHeight }
    private var profileAvatarsBandHeight: CGFloat { ProfileGardenLayout.avatarBandHeight }
    private var profileAvatarsBandTopGap: CGFloat { ProfileGardenLayout.avatarBandTopGap }

    private var dateItems: [ImportantDateItem] {
        ImportantDatesComposer().compose(
            firstMet: dpm.loadFoundingPhotoDate(promptText: "When we first met"),
            official: dpm.loadFoundingPhotoDate(promptText: "When we became official"),
            special: profile.specialDates.map {
                SpecialDateInput(
                    id: $0.id,
                    title: $0.title,
                    date: $0.date,
                    isBirthday: $0.isBirthday
                )
            })
    }

    private var travelStats: TravelHistoryStats {
        let moments = (homeViewModel?.moments ?? dpm.loadMoments()).map { moment in
            TravelMemoryInput(
                dateTaken: moment.dateTaken,
                placeName: moment.placeName,
                country: moment.country,
                latitude: moment.latitude,
                longitude: moment.longitude,
                isPlaceNameUserSet: moment.isPlaceNameUserSet
            )
        }
        let prompts = (homeViewModel?.promptMemories ?? []).map { memory in
            TravelMemoryInput(
                dateTaken: memory.date,
                placeName: memory.placeName,
                country: nil,
                latitude: memory.latitude,
                longitude: memory.longitude,
                isPlaceNameUserSet: memory.isPlaceNameUserSet
            )
        }
        return TravelHistoryStatsComposer().compose(moments: moments, prompts: prompts)
    }

    private var displayName: String {
        profile.displayName ?? dpm.loadUserNickname() ?? "You"
    }

    private var partnerSlotTitle: String {
        if isPartnerAccount {
            return dpm.loadInviterName() ?? "Justin"
        }
        return store.isPartnerUnlocked ? "Send invite" : "Invite partner"
    }

    private var isPartnerAccount: Bool {
        dpm.isPartnerAccount()
    }

    private var hasUserProfileSticker: Bool {
        profile.stickers.contains { $0.kind == .userAvatar }
    }

    private var userStickerImage: UIImage? {
        guard let id = profile.stickers.first(where: { $0.kind == .userAvatar })?.id else { return nil }
        return stickerImages[id]
    }

    private var sortedSpecialDates: [SpecialDate] {
        profile.specialDates.sorted { $0.date < $1.date }
    }

    private var pinnedSpecialDates: [SpecialDate] {
        sortedSpecialDates.filter(\.isPinned)
    }

    private var gardenMoments: [Moment] {
        homeViewModel?.moments ?? dpm.loadMoments()
    }

    private var gardenLetters: [UserLetter] {
        dpm.loadUserLetters()
    }

    /// Every owned pet roams the profile garden; a single pet shows only that cat.
    private var gardenPetSkins: [CatSkin] {
        let state = dpm.loadPetState()
        if !state.ownedSkins.isEmpty { return state.ownedSkins }
        if let adopted = state.adoptedSkin { return [adopted] }
        return []
    }

    private var userStickerScale: CGFloat {
        profile.stickers.first(where: { $0.kind == .userAvatar })?.scale ?? ProfileSticker.defaultScale
    }

    private var isFullPhotoViewerPresented: Bool {
        showingPinnedViewer != nil
            || showingMomentViewer
    }

    var body: some View {
        NavigationStack {
            profileGardenBody
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { profileGardenToolbar }
        .toolbar(isFullPhotoViewerPresented ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var profileGardenBody: some View {
        ZStack(alignment: .top) {
            Group {
                if nightModeManager.isNightMode {
                    HomeBackgroundView(isNightMode: true)
                } else {
                    Color(red: 0.78, green: 0.90, blue: 0.98)
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: nightModeManager.isNightMode)

            GardenBackgroundView(
                moments: gardenMoments,
                promptMemories: homeViewModel?.promptMemories ?? dpm.loadPromptMemories(),
                letters: gardenLetters,
                specialDates: profile.specialDates,
                officialDate: dpm.loadFoundingPhotoDate(promptText: "When we became official"),
                firstMetDate: dpm.loadFoundingPhotoDate(promptText: "When we first met"),
                showsLivePet: true,
                petSkins: gardenPetSkins,
                isNightMode: nightModeManager.isNightMode
            )
            .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        profileCardsSection
                            .id("contentTop")
                            .overlay(alignment: .bottom) {
                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .id("editGardenScrollAnchor")
                            }

                        Color.clear
                            .frame(height: profileAvatarsBandTopGap)

                        Color.clear
                            .frame(height: profileAvatarsBandHeight)

                        Color.clear
                            .frame(height: stickerCanvasHeight)
                    }
                    .padding(.horizontal, ProfileGardenLayout.contentTopPadding)
                    .padding(.top, ProfileGardenLayout.contentTopPadding)
                    .padding(.bottom, 16)
                    .overlay {
                        GeometryReader { contentGeo in
                            ProfileStickersLayer(
                                stickers: profile.stickers,
                                images: stickerImages,
                                profileNote: profile.profileNote,
                                profileNoteMood: profile.profileNoteMood,
                                profileNotePosition: profile.profileNotePosition,
                                recordPlayerPosition: profile.recordPlayerPosition,
                                recordPlayerScale: profile.recordPlayerScale,
                                isRecordPlayerPlaying: musicPlaybackState.isPlaying,
                                watchTogetherTVPosition: profile.watchTogetherTVPosition,
                                watchTogetherTVScale: profile.watchTogetherTVScale,
                                preludeBookPosition: profile.preludeBookPosition,
                                preludeBookScale: profile.preludeBookScale,
                                userName: displayName,
                                partnerTitle: partnerSlotTitle,
                                isCustomizing: isCustomizing,
                                selectedID: selectedStickerID,
                                isNoteSelected: isNoteSelected,
                                isRecordPlayerSelected: isRecordPlayerSelected,
                                isWatchTogetherTVSelected: isWatchTogetherTVSelected,
                                isPreludeBookSelected: isPreludeBookSelected,
                                onSelect: { id in
                                    selectedStickerID = id
                                    isNoteSelected = false
                                    isRecordPlayerSelected = false
                                    isWatchTogetherTVSelected = false
                                    isPreludeBookSelected = false
                                },
                                onSelectNote: {
                                    isNoteSelected = true
                                    selectedStickerID = nil
                                    isRecordPlayerSelected = false
                                    isWatchTogetherTVSelected = false
                                    isPreludeBookSelected = false
                                },
                                onSelectRecordPlayer: {
                                    isRecordPlayerSelected = true
                                    selectedStickerID = nil
                                    isNoteSelected = false
                                    isWatchTogetherTVSelected = false
                                    isPreludeBookSelected = false
                                },
                                onSelectWatchTogetherTV: {
                                    isWatchTogetherTVSelected = true
                                    selectedStickerID = nil
                                    isNoteSelected = false
                                    isRecordPlayerSelected = false
                                    isPreludeBookSelected = false
                                },
                                onSelectPreludeBook: {
                                    isPreludeBookSelected = true
                                    selectedStickerID = nil
                                    isNoteSelected = false
                                    isRecordPlayerSelected = false
                                    isWatchTogetherTVSelected = false
                                },
                                onDelete: deleteSticker,
                                onDeleteNote: deleteProfileNote,
                                onTapUser: { showEditProfile = true },
                                onTapPartner: handlePartnerSlotTap,
                                onTapNote: { showProfileNoteEditor = true },
                                onTapRecordPlayer: { showOurSongSheet = true },
                                onTapWatchTogetherTV: handleWatchTogetherTap,
                                onTapPreludeBook: { showPreludeGiftBook = true },
                                onLongPressWatchTogetherTV: { showWatchTogetherSheet = true },
                                onTapPhotoSticker: handlePhotoStickerTap,
                                onNotePositionChanged: updateProfileNotePosition,
                                onRecordPlayerPositionChanged: updateRecordPlayerPosition,
                                onRecordPlayerScaleChanged: updateRecordPlayerScale,
                                onWatchTogetherTVPositionChanged: updateWatchTogetherTVPosition,
                                onWatchTogetherTVScaleChanged: updateWatchTogetherTVScale,
                                onPreludeBookPositionChanged: updatePreludeBookPosition,
                                onPreludeBookScaleChanged: updatePreludeBookScale,
                                onPositionChanged: updateStickerPosition,
                                onScaleChanged: updateStickerScale,
                                onRotationChanged: updateStickerRotation
                            )
                            .frame(width: contentGeo.size.width, height: contentGeo.size.height)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isCustomizing {
                        EditGardenFooterBar(
                            onAddNote: { showProfileNoteEditor = true },
                            onCreateStickers: { showStickerPicker = true }
                        )
                    } else {
                        CoupleProfileFooterBar(
                            onVisitPet: { showVisitPet = true },
                            onEditGarden: beginCustomize
                        )
                    }
                }
                .onAppear {
                    scrollToBrowseTop(proxy: proxy)
                }
                .onChange(of: isCustomizing) { _, editing in
                    if editing {
                        scrollToEditGardenFocus(proxy: proxy)
                    } else {
                        scrollToBrowseTop(proxy: proxy)
                    }
                }
            }

            pinnedMemoryOverlays
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            load()
            AudioManager.shared.setGardenActive(true)
        }
        .onDisappear {
            AudioManager.shared.setGardenActive(false)
        }
        .sheet(isPresented: $showOurSongSheet) {
            OurSongSheet()
        }
        .fullScreenCover(isPresented: $showPreludeGiftBook) {
            PreludeGiftBookView(
                onComplete: { showPreludeGiftBook = false },
                completeButtonTitle: "Done"
            )
        }
        .sheet(isPresented: $showWatchTogetherSheet) {
            WatchTogetherEntryView()
        }
        .fullScreenCover(isPresented: $showWatchTogetherPaywall) {
            InvitePartnerPaywallView(
                store: store,
                onUnlock: {
                    showWatchTogetherPaywall = false
                    showWatchTogetherSheet = true
                },
                onDismiss: { showWatchTogetherPaywall = false }
            )
        }
        .sheet(isPresented: $showEditProfile) {
            ProfileEditorSheet(initialName: displayName, initialImage: userAvatar) { image, name in
                if isPartnerAccount {
                    if let image {
                        dpm.savePartnerProfilePhoto(image)
                    }
                    dpm.saveUserNickname(name)
                } else {
                    dpm.saveUserAvatar(image)
                    profile.displayName = name
                    if image != nil {
                        ProfileStickerSync.addUserAvatarStickerIfMissing(profile: &profile, dpm: dpm)
                    }
                    dpm.saveCoupleProfile(profile)
                }
                userAvatar = image
                refreshStickers()
            }
        }
        .sheet(item: $dateEditorPresentation) { presentation in
            SpecialDateEditorSheet(
                editing: presentation.editing,
                initialImage: presentation.initialImage,
                onSave: { saveSpecial($0, image: $1) },
                onDelete: presentation.editing == nil ? nil : { deleteSpecial($0) }
            )
        }
        .fullScreenCover(isPresented: $showVisitPet) {
            NavigationStack {
                AdoptAPetRootView(onDismiss: { showVisitPet = false })
            }
        }
        .fullScreenCover(item: $activeSubpage) { subpage in
            switch subpage {
            case .importantDates:
                ImportantDatesListView(
                    items: dateItems,
                    specialDates: sortedSpecialDates,
                    photoForItem: { photo(for: $0) },
                    userAvatar: userAvatar,
                    userName: displayName,
                    partnerSlotTitle: partnerSlotTitle,
                    onBack: { activeSubpage = nil },
                    onPartnerTap: handlePartnerSlotTap,
                    onSaveSpecial: saveSpecial,
                    onDeleteSpecial: deleteSpecial
                )
            }
        }
        .onChange(of: showVisitPet) { _, showing in
            if !showing { refreshStickers() }
        }
        .onChange(of: firstMetPickerItem) { _, newItem in
            guard let newItem, let homeViewModel else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    var creationDate = Date()
                    var latitude: Double?
                    var longitude: Double?
                    if let identifier = newItem.itemIdentifier {
                        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                        if let asset = result.firstObject {
                            creationDate = asset.creationDate ?? Date()
                            latitude = asset.location?.coordinate.latitude
                            longitude = asset.location?.coordinate.longitude
                        }
                    }
                    homeViewModel.pinnedFirstMet = image
                    homeViewModel.upsertFoundingMoment(
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
            guard let newItem, let homeViewModel else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    var creationDate = Date()
                    var latitude: Double?
                    var longitude: Double?
                    if let identifier = newItem.itemIdentifier {
                        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                        if let asset = result.firstObject {
                            creationDate = asset.creationDate ?? Date()
                            latitude = asset.location?.coordinate.latitude
                            longitude = asset.location?.coordinate.longitude
                        }
                    }
                    homeViewModel.pinnedOfficial = image
                    homeViewModel.upsertFoundingMoment(
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
        .fullScreenCover(isPresented: $showPartnerPaywall) {
            InvitePartnerPaywallView(
                store: store,
                onUnlock: {
                    showPartnerPaywall = false
                    showInviteFlow = true
                },
                onDismiss: { showPartnerPaywall = false }
            )
        }
        .sheet(isPresented: $showInviteFlow) {
            InvitePartnerFlowView(onDone: { showInviteFlow = false })
        }
        .sheet(isPresented: $showStickerPicker) {
            GardenStickerPickerSheet { momentID in
                createStickerFromMoment(momentID)
            }
        }
        .fullScreenCover(isPresented: $showProfileNoteEditor) {
            ProfileNoteEditorSheet(
                initialText: profile.profileNote ?? "",
                initialMood: profile.profileNoteMood
            ) { note, mood in
                saveProfileNote(note, mood: mood)
            }
        }
    }

    @ViewBuilder
    private var profileCardsSection: some View {
        VStack(spacing: 16) {
            OurHistoryCard(stats: travelStats)

            ImportantDatesPreviewCard(
                items: dateItems,
                photoForItem: { photo(for: $0) },
                onSeeMore: { activeSubpage = .importantDates },
                onTapSpecial: { beginEditSpecial(id: $0) },
                onTapPhoto: { presentPhotoViewer(for: $0) }
            )
        }
        .allowsHitTesting(!isCustomizing)
    }

    @ToolbarContentBuilder
    private var profileGardenToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isCustomizing {
                Button(action: cancelCustomize) {
                    Text("Back")
                        .font(.system(size: 17, weight: .semibold))
                }
            } else {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isCustomizing {
                Button(action: finishCustomize) {
                    SavePillLabel(
                        title: "Save",
                        font: .system(size: 17, weight: .semibold),
                        horizontalPadding: 16,
                        verticalPadding: 8
                    )
                }
                .buttonStyle(.plain)
            } else if !isPartnerAccount {
                Button(action: { showPartnerPaywall = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Invite")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(BabyTownTheme.buttonGradient, in: Capsule())
                    .shadow(color: BabyTownTheme.buttonShadow, radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var pinnedMemoryOverlays: some View {
        if let viewerType = showingPinnedViewer, let homeViewModel {
            FullScreenPinnedMemoryViewer(
                title: viewerType == .firstMet ? "First Photo Taken Together" : "First Photo As Official Jinkies",
                date: "Pinned",
                image: viewerType == .firstMet ? homeViewModel.pinnedFirstMet : homeViewModel.pinnedOfficial,
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

        if showingMomentViewer {
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
                    guard let homeViewModel else { return }
                    var newMoments = homeViewModel.moments
                    for moment in updatedMoments {
                        if let index = newMoments.firstIndex(where: { $0.id == moment.id }) {
                            newMoments[index] = moment
                        }
                    }
                    homeViewModel.moments = newMoments
                },
                onDeleteMoment: { moment in
                    guard let homeViewModel else { return }
                    withAnimation { homeViewModel.deleteMoment(moment) }
                },
                memoryPagePromptText: viewerMemoryPagePromptText,
                memoryPageImportantDate: viewerImportantDate,
                promptMemoryId: viewerPromptMemoryId,
                onEditPromptMemory: { memoryId, _, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                    homeViewModel?.updatePromptMemory(
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
                    homeViewModel?.addPhotosToPromptMemory(memoryId: memoryId, images: images)
                },
                onRemovePromptPhoto: { memoryId, photoId in
                    homeViewModel?.removePhotoFromPromptMemory(memoryId: memoryId, photoId: photoId)
                },
                onSyncPromptMemoryPhotos: { memoryId, assetIds, orphanIds in
                    await homeViewModel?.syncPromptMemoryPhotos(
                        memoryId: memoryId,
                        selectedAssetIds: assetIds,
                        selectedOrphanMomentIds: orphanIds
                    )
                },
                onReloadPromptMoments: {
                    guard let memoryId = viewerPromptMemoryId else { return viewerMoments }
                    let memories = homeViewModel?.promptMemories ?? dpm.loadPromptMemories()
                    guard let memory = memories.first(where: { $0.id == memoryId }) else {
                        return viewerMoments
                    }
                    return memory.sortedViewerMoments
                }
            )
            .transition(.opacity)
            .zIndex(11)
        }
    }

    private func clearMemoryPageViewerContext() {
        viewerMemoryPagePromptText = nil
        viewerImportantDate = nil
        viewerPromptMemoryId = nil
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

    // MARK: - Pinned preview helpers

    private var hasOfficialPinned: Bool {
        homeViewModel?.pinnedItems.contains { item in
            switch item {
            case .moment(let m, _): return m.promptText == "When we became official"
            case .prompt(let p): return p.promptText == "When we became official"
            }
        } ?? false
    }

    private var hasFirstMetPinned: Bool {
        homeViewModel?.pinnedItems.contains { item in
            switch item {
            case .moment(let m, _): return m.promptText == "When we first met"
            case .prompt(let p): return p.promptText == "When we first met"
            }
        } ?? false
    }

    private var hasOfficialFoundingPhoto: Bool {
        homeViewModel?.moments.contains { $0.promptText == "When we became official" } ?? false
    }

    private var hasFirstMetFoundingPhoto: Bool {
        homeViewModel?.moments.contains { $0.promptText == "When we first met" } ?? false
    }

    private var showsOfficialPinnedPlaceholder: Bool {
        !hasOfficialPinned && !hasOfficialFoundingPhoto
    }

    private var showsFirstMetPinnedPlaceholder: Bool {
        !hasFirstMetPinned && !hasFirstMetFoundingPhoto
    }

    private func openSpecialDate(_ special: SpecialDate) {
        guard let image = dpm.loadSpecialDatePhoto(id: special.id) else { return }
        openImportantDateMemoryPage(
            title: special.title,
            date: special.date,
            image: image,
            itemId: special.id.uuidString
        )
    }

    private func handlePhotoStickerTap(_ sticker: ProfileSticker) {
        guard !isCustomizing else { return }
        switch sticker.kind {
        case .specialDate:
            guard let id = UUID(uuidString: sticker.sourceKey),
                  let special = profile.specialDates.first(where: { $0.id == id }) else { return }
            openSpecialDate(special)
        case .moment:
            openMomentSticker(id: sticker.sourceKey)
        default:
            break
        }
    }

    private func openMomentSticker(id sourceKey: String) {
        guard let id = UUID(uuidString: sourceKey) else { return }

        let moments = gardenMoments
        if let moment = moments.first(where: { $0.id == id }) {
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: moment.dateTaken)
            let dayMoments = moments
                .filter { calendar.startOfDay(for: $0.dateTaken) == day }
                .sorted { $0.dateTaken < $1.dateTaken }
            clearMemoryPageViewerContext()
            viewerMoments = dayMoments
            viewerInitialIndex = dayMoments.firstIndex(where: { $0.id == id }) ?? 0
            withAnimation(.easeInOut(duration: 0.25)) {
                showingMomentViewer = true
            }
            return
        }

        for memory in homeViewModel?.promptMemories ?? dpm.loadPromptMemories() {
            guard let photo = memory.photos.first(where: { $0.id == id }) else { continue }
            openPromptMemoryPage(memory: memory, photo: photo)
            return
        }
    }

    private func openPinnedItem(_ item: PinnedItem) {
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
    }

    private func unpinItem(_ item: PinnedItem) {
        guard let homeViewModel else { return }
        withAnimation {
            switch item {
            case .moment(let m, _):
                homeViewModel.unpinMoment(m)
            case .prompt(let p):
                homeViewModel.togglePromptMemoryPin(p)
            }
        }
    }

    private func shareMemory(_ payload: MemorySharePayload) {
        shareCoordinator.share(payload)
    }

    private func handlePartnerSlotTap() {
        if isPartnerAccount { return }
        if store.isPartnerUnlocked {
            showInviteFlow = true
        } else {
            showPartnerPaywall = true
        }
    }

    private func handleWatchTogetherTap() {
        if isPartnerAccount || store.isPartnerUnlocked {
            showWatchTogetherSheet = true
        } else {
            showWatchTogetherPaywall = true
        }
    }

    private func saveProfileNote(_ note: String, mood: ProfileNoteMood?) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            profile.profileNote = nil
            profile.profileNoteMood = nil
            profile.profileNotePosition = nil
        } else {
            profile.profileNote = trimmed
            profile.profileNoteMood = mood
            if profile.profileNotePosition == nil {
                profile.profileNotePosition = ProfileGardenNoteLayout.defaultPosition(
                    stickers: profile.stickers,
                    canvasSize: ProfileGardenLayout.stickerLayerCanvasSize()
                )
            }
        }
        dpm.saveCoupleProfile(profile)
    }

    private func updateProfileNotePosition(_ position: NormalizedPoint) {
        profile.profileNotePosition = position
    }

    private func updateRecordPlayerPosition(_ position: NormalizedPoint) {
        profile.recordPlayerPosition = position
    }

    private func updateRecordPlayerScale(_ scale: CGFloat) {
        profile.recordPlayerScale = max(scale, VinylRecordPlayerView.gardenMinScale)
    }

    private func updateWatchTogetherTVPosition(_ position: NormalizedPoint) {
        profile.watchTogetherTVPosition = position
    }

    private func updateWatchTogetherTVScale(_ scale: CGFloat) {
        profile.watchTogetherTVScale = max(scale, WatchTogetherTVView.gardenMinScale)
    }

    private func updatePreludeBookPosition(_ position: NormalizedPoint) {
        profile.preludeBookPosition = position
    }

    private func updatePreludeBookScale(_ scale: CGFloat) {
        profile.preludeBookScale = max(scale, PreludeBookView.gardenMinScale)
    }

    private func deleteProfileNote() {
        profile.profileNote = nil
        profile.profileNoteMood = nil
        profile.profileNotePosition = nil
        isNoteSelected = false
        isRecordPlayerSelected = false
        isPreludeBookSelected = false
    }

    // MARK: Data

    private func load() {
        profile = dpm.loadCoupleProfile()
        userAvatar = isPartnerAccount ? dpm.loadPartnerProfilePhoto() : dpm.loadUserAvatar()
        refreshStickers()
    }

    private func refreshStickers() {
        var updated = profile
        ProfileStickerSync.sync(
            profile: &updated,
            dpm: dpm
        )
        profile = updated
        stickerImages = Dictionary(
            uniqueKeysWithValues: profile.stickers.compactMap { sticker in
                dpm.loadStickerImage(id: sticker.id).map { (sticker.id, $0) }
            }
        )
        #if DEBUG
        print("🟣[Garden] refreshStickers — \(profile.stickers.count) sticker(s):")
        for s in profile.stickers {
            let hasImg = stickerImages[s.id] != nil
            print(String(format: "🟣[Garden]   kind=%@ pos=(%.2f, %.2f) scale=%.2f hasImage=%@ id=%@",
                         "\(s.kind)", s.position.x, s.position.y, s.scale,
                         hasImg ? "YES" : "NO", String(s.id.uuidString.prefix(8))))
        }
        #endif
    }

    private func beginCustomize() {
        isCustomizing = true
    }

    /// Default browse position: card stack flush under the toolbar (matches side padding).
    private func scrollToBrowseTop(proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo("contentTop", anchor: .top)
            }
        }
    }

    /// Scrolls just past the three cards so edit mode opens on the garden band.
    private func scrollToEditGardenFocus(proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeInOut(duration: 0.32)) {
                proxy.scrollTo("editGardenScrollAnchor", anchor: .top)
            }
        }
    }

    private func cancelCustomize() {
        isCustomizing = false
        selectedStickerID = nil
        isNoteSelected = false
        isRecordPlayerSelected = false
        isWatchTogetherTVSelected = false
        isPreludeBookSelected = false
        pendingImageDeletions.removeAll()
        load()
    }

    private func finishCustomize() {
        isCustomizing = false
        selectedStickerID = nil
        isNoteSelected = false
        isRecordPlayerSelected = false
        isWatchTogetherTVSelected = false
        isPreludeBookSelected = false
        for id in pendingImageDeletions {
            dpm.deleteStickerImage(id: id)
        }
        pendingImageDeletions.removeAll()
        dpm.saveCoupleProfile(profile)
    }

    private func createStickerFromMoment(_ momentID: UUID) {
        let sourceImage =
            PetGalleryPhotoLoader.image(for: momentID)
            ?? dpm.loadMoments().first(where: { $0.id == momentID })?.thumbnail
            ?? dpm.loadPromptMemories()
                .flatMap(\.photos)
                .first(where: { $0.id == momentID })?
                .thumbnail
        guard let sourceImage else { return }

        let processed = SubjectLiftService.stickerImage(from: sourceImage)
        let sticker = ProfileSticker(
            kind: .moment,
            sourceKey: momentID.uuidString,
            position: nextPhotoStickerPosition(),
            rotation: Double.random(in: -10...10),
            scale: ProfileSticker.newStickerScale,
            usedSubjectLift: processed.usedSubjectLift
        )
        dpm.saveStickerImage(processed.image, id: sticker.id)
        profile.stickers.append(sticker)
        stickerImages[sticker.id] = processed.image
    }

    /// A spot below the profile photos that clears every sticker already on the
    /// wall, so each newly added photo frame lands in its own place. Scans a
    /// staggered grid first, then falls back to a random open-canvas spot.
    private func nextPhotoStickerPosition() -> NormalizedPoint {
        let existing = profile.stickers.map(\.position)
        let minDistance: CGFloat = 0.13
        let columns: [CGFloat] = [0.25, 0.45, 0.65, 0.35, 0.55]
        let rows: [CGFloat] = [0.58, 0.66, 0.74, 0.62, 0.70, 0.78]

        for row in rows {
            for col in columns {
                let candidate = NormalizedPoint(x: col, y: row)
                let isClear = existing.allSatisfy { other in
                    hypot(other.x - candidate.x, other.y - candidate.y) > minDistance
                }
                if isClear { return candidate }
            }
        }
        return NormalizedPoint(
            x: .random(in: 0.20...0.80),
            y: .random(in: 0.56...0.78)
        )
    }

    private func updateStickerPosition(id: UUID, position: NormalizedPoint) {
        guard let idx = profile.stickers.firstIndex(where: { $0.id == id }) else { return }
        profile.stickers[idx].position = position
    }

    private func updateStickerScale(id: UUID, scale: CGFloat) {
        guard let idx = profile.stickers.firstIndex(where: { $0.id == id }) else { return }
        profile.stickers[idx].scale = scale
    }

    private func updateStickerRotation(id: UUID, rotation: Double) {
        guard let idx = profile.stickers.firstIndex(where: { $0.id == id }) else { return }
        profile.stickers[idx].rotation = rotation
    }

    private func deleteSticker(_ id: UUID) {
        guard let idx = profile.stickers.firstIndex(where: { $0.id == id }) else { return }
        switch profile.stickers[idx].kind {
        case .userAvatar, .partnerInvite:
            return
        case .moment, .specialDate, .pet:
            break
        }
        profile.stickers.remove(at: idx)
        stickerImages[id] = nil
        pendingImageDeletions.insert(id)
        if selectedStickerID == id { selectedStickerID = nil }
    }

    private func photo(for item: ImportantDateItem) -> UIImage? {
        switch item.kind {
        case .firstMet: return dpm.loadPinnedFirstMet()
        case .official: return dpm.loadPinnedOfficial()
        case .special:
            guard let id = UUID(uuidString: item.id) else { return nil }
            return dpm.loadSpecialDatePhoto(id: id)
        }
    }

    private func presentPhotoViewer(for item: ImportantDateItem) {
        guard let image = photo(for: item) else { return }
        openImportantDateMemoryPage(
            title: item.title,
            date: item.date,
            image: image,
            itemId: item.id
        )
    }

    private func beginEditSpecial(id: String) {
        guard let uid = UUID(uuidString: id),
              let match = profile.specialDates.first(where: { $0.id == uid }) else { return }
        showingMomentViewer = false
        clearMemoryPageViewerContext()
        dateEditorPresentation = .edit(match, image: dpm.loadSpecialDatePhoto(id: uid))
    }

    private func saveSpecial(_ date: SpecialDate, image: UIImage?) {
        if let idx = profile.specialDates.firstIndex(where: { $0.id == date.id }) {
            profile.specialDates[idx] = date
        } else {
            profile.specialDates.append(date)
        }
        if let image {
            dpm.saveSpecialDatePhoto(image, id: date.id)
        }
        dpm.saveCoupleProfile(profile)
        refreshStickers()
    }

    private func deleteSpecial(_ date: SpecialDate) {
        profile.specialDates.removeAll { $0.id == date.id }
        dpm.deleteSpecialDatePhoto(id: date.id)
        dpm.saveCoupleProfile(profile)
        refreshStickers()
    }

    private func toggleSpecialDatePin(_ date: SpecialDate) {
        guard let idx = profile.specialDates.firstIndex(where: { $0.id == date.id }) else { return }
        profile.specialDates[idx].isPinned.toggle()
        profile.specialDates[idx].pinnedAt = profile.specialDates[idx].isPinned ? Date() : nil
        dpm.saveCoupleProfile(profile)
    }
}
