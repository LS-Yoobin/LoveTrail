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
    /// Sticker image files to delete from disk only when the user taps Save.
    @State private var pendingImageDeletions: Set<UUID> = []
    @State private var showEditProfile = false
    @State private var showVisitPet = false
    @State private var showStickerPicker = false
    @State private var showAddLoveStoryComingSoon = false

    @State private var showDateEditor = false
    @State private var editingDate: SpecialDate?
    @State private var editingDateImage: UIImage?
    @State private var photoViewerContext: ImportantDatePhotoViewerContext?
    @State private var activeSubpage: CoupleProfileSubpage?

    @State private var showingPinnedViewer: PinnedMemoryType?
    @State private var firstMetPickerItem: PhotosPickerItem?
    @State private var officialPickerItem: PhotosPickerItem?
    @State private var showingMomentViewer = false
    @State private var viewerMoments: [Moment] = []
    @State private var viewerInitialIndex = 0
    @State private var showingPromptPhotoViewer = false
    @State private var viewerPromptPhotos: [PromptPhoto] = []
    @State private var viewerPromptPhotoIndex = 0
    @State private var viewerPromptText: String?

    private var dpm: DataPersistenceManager { .shared }

    /// Open canvas height below the cards where stickers float (also the edit-mode
    /// scroll anchor target). Tall enough to arrange several stickers.
    private let stickerCanvasHeight: CGFloat = 820

    private var dateItems: [ImportantDateItem] {
        ImportantDatesComposer().compose(
            firstMet: dpm.loadFoundingPhotoDate(promptText: "When we first met"),
            official: dpm.loadFoundingPhotoDate(promptText: "When we became official"),
            special: profile.specialDates.map {
                SpecialDateInput(id: $0.id, title: $0.title, date: $0.date)
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
        store.isPartnerUnlocked ? "Send invite" : "Invite partner"
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

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color(red: 0.78, green: 0.90, blue: 0.98)
                    .ignoresSafeArea()

                GardenBackgroundView(
                    moments: gardenMoments,
                    letters: gardenLetters,
                    showsLivePet: !isCustomizing,
                    petSkins: gardenPetSkins
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Group {
                        if isCustomizing {
                            EditGardenHeaderView(
                                onBack: cancelCustomize,
                                onSave: finishCustomize
                            )
                        } else {
                            CoupleHeaderView(
                                onBack: onBack,
                                onInvite: { showPartnerPaywall = true }
                            )
                        }
                    }
                    .padding(.top, 4)

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                profileCardsSection
                                    .id("contentTop")

                                Color.clear
                                    .frame(height: stickerCanvasHeight)
                                    .id("stickerCanvasTop")
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .overlay {
                                GeometryReader { geo in
                                    ProfileStickersLayer(
                                        stickers: profile.stickers,
                                        images: stickerImages,
                                        userName: displayName,
                                        partnerTitle: partnerSlotTitle,
                                        isCustomizing: isCustomizing,
                                        selectedID: selectedStickerID,
                                        onSelect: { selectedStickerID = $0 },
                                        onDelete: deleteSticker,
                                        onTapUser: { showEditProfile = true },
                                        onTapPartner: handlePartnerSlotTap,
                                        onPositionChanged: updateStickerPosition,
                                        onScaleChanged: updateStickerScale
                                    )
                                    .frame(width: geo.size.width, height: geo.size.height)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: isCustomizing) { _, editing in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if editing {
                                    proxy.scrollTo("stickerCanvasTop", anchor: .top)
                                } else {
                                    proxy.scrollTo("contentTop", anchor: .top)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if isCustomizing {
                            EditGardenFooterBar(
                                onAddLoveStory: { showAddLoveStoryComingSoon = true },
                                onCreateStickers: { showStickerPicker = true }
                            )
                        } else {
                            CoupleProfileFooterBar(
                                onVisitPet: { showVisitPet = true },
                                onEditGarden: beginCustomize
                            )
                        }
                    }
                }

                pinnedMemoryOverlays
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: load)
        .sheet(isPresented: $showEditProfile) {
            ProfileEditorSheet(initialName: displayName, initialImage: userAvatar) { image, name in
                dpm.saveUserAvatar(image)
                profile.displayName = name
                dpm.saveCoupleProfile(profile)
                userAvatar = image
                refreshStickers()
            }
        }
        .sheet(isPresented: $showDateEditor) {
            SpecialDateEditorSheet(
                editing: editingDate,
                initialImage: editingDateImage,
                onSave: { saveSpecial($0, image: $1) },
                onDelete: editingDate == nil ? nil : { deleteSpecial($0) }
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
            case .pinnedMemories:
                if let homeViewModel {
                    PinnedMemoriesFeedView(
                        viewModel: homeViewModel,
                        specialDates: pinnedSpecialDates,
                        userAvatar: userAvatar,
                        userName: displayName,
                        partnerSlotTitle: partnerSlotTitle,
                        onBack: { activeSubpage = nil },
                        onPartnerTap: handlePartnerSlotTap,
                        onShare: shareMemory,
                        onEditSpecialDate: { beginEditSpecial(id: $0.id.uuidString) },
                        onDeleteSpecialDate: deleteSpecial,
                        onTogglePinSpecialDate: toggleSpecialDatePin
                    )
                }
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
        .alert("Coming Soon", isPresented: $showAddLoveStoryComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Love stories are on the way — stay tuned!")
        }
        .overlay {
            if activeSubpage == nil, let context = photoViewerContext {
                ImportantDatePhotoViewer(
                    title: context.title,
                    date: context.date,
                    image: context.image,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            photoViewerContext = nil
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: photoViewerContext != nil)
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

            if let homeViewModel {
                PinnedMemoriesPreviewCard(
                    pinnedItems: homeViewModel.pinnedItems,
                    specialDates: pinnedSpecialDates,
                    showsOfficialPlaceholder: showsOfficialPinnedPlaceholder,
                    showsFirstMetPlaceholder: showsFirstMetPinnedPlaceholder,
                    photoForSpecialDate: { dpm.loadSpecialDatePhoto(id: $0) },
                    onSeeMore: { activeSubpage = .pinnedMemories },
                    onTapOfficialPlaceholder: { showingPinnedViewer = .official },
                    onTapFirstMetPlaceholder: { showingPinnedViewer = .firstMet },
                    onTapSpecialDate: { openSpecialDate($0) },
                    onEditSpecialDate: { beginEditSpecial(id: $0.id.uuidString) },
                    onDeleteSpecialDate: deleteSpecial,
                    onUnpinSpecialDate: toggleSpecialDatePin,
                    onTapPinned: { openPinnedItem($0) },
                    onUnpinPinned: { unpinItem($0) },
                    onSharePinned: shareMemory
                )
            }
        }
        .allowsHitTesting(!isCustomizing)
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

        if showingMomentViewer, let homeViewModel {
            MomentPhotoViewer(
                moments: viewerMoments,
                initialIndex: viewerInitialIndex,
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showingMomentViewer = false
                    }
                },
                onUpdateMoments: { updatedMoments in
                    var newMoments = homeViewModel.moments
                    for moment in updatedMoments {
                        if let index = newMoments.firstIndex(where: { $0.id == moment.id }) {
                            newMoments[index] = moment
                        }
                    }
                    homeViewModel.moments = newMoments
                },
                onDeleteMoment: { moment in
                    withAnimation { homeViewModel.deleteMoment(moment) }
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
                    homeViewModel?.updatePromptMemoryPhotos(viewerPromptPhotos, with: updatedPhotos)
                },
                onDeletePhoto: { photo in
                    withAnimation {
                        homeViewModel?.deletePromptPhoto(photo, from: viewerPromptPhotos)
                    }
                },
                promptText: viewerPromptText
            )
            .transition(.opacity)
            .zIndex(12)
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
        withAnimation(.easeInOut(duration: 0.25)) {
            photoViewerContext = ImportantDatePhotoViewerContext(
                title: special.title,
                date: special.date,
                image: image
            )
        }
    }

    private func openPinnedItem(_ item: PinnedItem) {
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
        if store.isPartnerUnlocked {
            showInviteFlow = true
        } else {
            showPartnerPaywall = true
        }
    }

    // MARK: Data

    private func load() {
        profile = dpm.loadCoupleProfile()
        userAvatar = dpm.loadUserAvatar()
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
    }

    private func beginCustomize() {
        isCustomizing = true
    }

    private func cancelCustomize() {
        isCustomizing = false
        selectedStickerID = nil
        pendingImageDeletions.removeAll()
        load()
    }

    private func finishCustomize() {
        isCustomizing = false
        selectedStickerID = nil
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
        let rows: [CGFloat] = [0.72, 0.80, 0.88, 0.76, 0.84, 0.92]

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
            y: .random(in: 0.70...0.92)
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

    private func deleteSticker(_ id: UUID) {
        guard let idx = profile.stickers.firstIndex(where: { $0.id == id }) else { return }
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
        withAnimation(.easeInOut(duration: 0.25)) {
            photoViewerContext = ImportantDatePhotoViewerContext(
                title: item.title,
                date: item.date,
                image: image
            )
        }
    }

    private func beginEditSpecial(id: String) {
        guard let uid = UUID(uuidString: id),
              let match = profile.specialDates.first(where: { $0.id == uid }) else { return }
        photoViewerContext = nil
        editingDate = match
        editingDateImage = dpm.loadSpecialDatePhoto(id: uid)
        showDateEditor = true
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
