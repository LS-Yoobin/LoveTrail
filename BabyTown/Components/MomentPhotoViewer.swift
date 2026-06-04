import SwiftUI

struct MomentPhotoViewer: View {

    let moments: [Moment]
    let initialIndex: Int
    var onDismiss: () -> Void
    var onUpdateMoments: ([Moment]) -> Void
    var onDeleteMoment: ((Moment) -> Void)? = nil
    var onEditMemory: ((DaySection, UUID, String, String?, Double?, Double?, Bool) -> Void)? = nil
    var onEditCaption: ((UUID, String, String?) -> Void)? = nil
    var onAddPhotos: ((DaySection, [UIImage]) -> Void)? = nil
    var onRemovePhoto: ((DaySection, UUID) -> Void)? = nil
    var onSyncMemoryPhotos: ((DaySection, Set<String>, Set<UUID>) async -> Void)? = nil
    var onReloadMemoryMoments: (() -> [Moment])? = nil
    /// Prompt-memory scrapbook page: always show this prompt card (not founding-slot logic).
    var memoryPagePromptText: String? = nil
    /// Important-date scrapbook page: title + calendar date for the occasion.
    var memoryPageImportantDate: MemoryPageImportantDateInfo? = nil
    var promptMemoryId: UUID? = nil
    var onEditPromptMemory: ((UUID, UUID, String, String?, Double?, Double?, Bool) -> Void)? = nil
    var onAddPromptPhotos: ((UUID, [UIImage]) -> Void)? = nil
    var onRemovePromptPhoto: ((UUID, UUID) -> Void)? = nil
    var onSyncPromptMemoryPhotos: ((UUID, Set<String>, Set<UUID>) async -> Void)? = nil
    var onReloadPromptMoments: (() -> [Moment])? = nil

    @State private var currentIndex: Int
    @State private var updatedMoments: [Moment]
    @State private var canvas: MemoryCanvas
    @State private var stickerImages: [UUID: UIImage] = [:]
    @State private var isImmersivePhotoMode = false
    @State private var isComposingNote = false
    @State private var isEditingStickers = false
    @State private var selectedStickerID: UUID?
    @State private var noteDraft = ""
    @State private var composingNotePosition: NormalizedPoint?
    @State private var isCanvasDragActive = false
    @State private var metadataBottomY: CGFloat = 0
    @State private var pageContentHeight: CGFloat = 0
    @State private var showCaptionEditor = false
    @State private var showStickerPicker = false
    @State private var pendingNewStickerIDs: Set<UUID> = []
    @State private var pendingStickerImageDeletions: Set<UUID> = []
    @State private var showMapsChooser = false
    @StateObject private var shareCoordinator = MemoryShareCoordinator()
    @FocusState private var isNoteFocused: Bool

    @Environment(\.openURL) private var openURL

    private let dpm = DataPersistenceManager.shared

    private static let foundingPrompts: Set<String> = [
        "When we first met",
        "When we became official"
    ]

    init(
        moments: [Moment],
        initialIndex: Int,
        onDismiss: @escaping () -> Void,
        onUpdateMoments: @escaping ([Moment]) -> Void,
        onDeleteMoment: ((Moment) -> Void)? = nil,
        onEditMemory: ((DaySection, UUID, String, String?, Double?, Double?, Bool) -> Void)? = nil,
        onEditCaption: ((UUID, String, String?) -> Void)? = nil,
        onAddPhotos: ((DaySection, [UIImage]) -> Void)? = nil,
        onRemovePhoto: ((DaySection, UUID) -> Void)? = nil,
        onSyncMemoryPhotos: ((DaySection, Set<String>, Set<UUID>) async -> Void)? = nil,
        onReloadMemoryMoments: (() -> [Moment])? = nil,
        memoryPagePromptText: String? = nil,
        memoryPageImportantDate: MemoryPageImportantDateInfo? = nil,
        promptMemoryId: UUID? = nil,
        onEditPromptMemory: ((UUID, UUID, String, String?, Double?, Double?, Bool) -> Void)? = nil,
        onAddPromptPhotos: ((UUID, [UIImage]) -> Void)? = nil,
        onRemovePromptPhoto: ((UUID, UUID) -> Void)? = nil,
        onSyncPromptMemoryPhotos: ((UUID, Set<String>, Set<UUID>) async -> Void)? = nil,
        onReloadPromptMoments: (() -> [Moment])? = nil
    ) {
        self.moments = moments
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self.onUpdateMoments = onUpdateMoments
        self.onDeleteMoment = onDeleteMoment
        self.onEditMemory = onEditMemory
        self.onEditCaption = onEditCaption
        self.onAddPhotos = onAddPhotos
        self.onRemovePhoto = onRemovePhoto
        self.onSyncMemoryPhotos = onSyncMemoryPhotos
        self.onReloadMemoryMoments = onReloadMemoryMoments
        self.memoryPagePromptText = memoryPagePromptText
        self.memoryPageImportantDate = memoryPageImportantDate
        self.promptMemoryId = promptMemoryId
        self.onEditPromptMemory = onEditPromptMemory
        self.onAddPromptPhotos = onAddPromptPhotos
        self.onRemovePromptPhoto = onRemovePromptPhoto
        self.onSyncPromptMemoryPhotos = onSyncPromptMemoryPhotos
        self.onReloadPromptMoments = onReloadPromptMoments
        _currentIndex = State(initialValue: initialIndex)
        _updatedMoments = State(initialValue: moments)
        let anchor = moments.sorted { $0.dateTaken < $1.dateTaken }.first?.id ?? UUID()
        let key = MemoryCanvas.memoryKey(anchorMomentId: anchor)
        let stored = DataPersistenceManager.shared.loadMemoryCanvases()[key]
        _canvas = State(initialValue: stored ?? MemoryCanvas(memoryKey: key))
    }

    private var sortedMoments: [Moment] {
        updatedMoments.sorted { $0.dateTaken < $1.dateTaken }
    }

    private var anchorMomentId: UUID {
        sortedMoments.first?.id ?? UUID()
    }

    private var allowedMomentIDs: Set<UUID> {
        Set(updatedMoments.map(\.id))
    }

    var currentMoment: Moment {
        if updatedMoments.isEmpty {
            return moments.first ?? Moment.sampleMoment
        }
        guard currentIndex < updatedMoments.count else {
            return updatedMoments.last ?? moments.first ?? Moment.sampleMoment
        }
        return updatedMoments[currentIndex]
    }

    private var loveNoteText: String? {
        let note = sortedMoments
            .compactMap { moment -> String? in
                guard let caption = moment.caption?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !caption.isEmpty else { return nil }
                return caption
            }
            .first
        return note
    }

    private var foundingPromptText: String? {
        guard let prompt = sortedMoments.first?.promptText,
              Self.foundingPrompts.contains(prompt) else { return nil }
        return prompt
    }

    private var foundingMomentWithPlaceName: Moment? {
        guard foundingPromptText != nil else { return nil }
        return sortedMoments.first(where: {
            guard let name = $0.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return !name.isEmpty
        })
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter
    }

    private var memoryNoteButtonTitle: String {
        canvas.localUserNote?.hasContent == true ? "Edit Note" : "Add Note"
    }

    private var stickerFooterButtonTitle: String {
        canvas.stickers.isEmpty ? "Create Sticker" : "Edit Stickers"
    }

    var body: some View {
        Group {
            if updatedMoments.isEmpty {
                emptyState
            } else if isImmersivePhotoMode {
                immersivePhotoView
            } else {
                scrapbookView
            }
        }
        .statusBarHidden(isImmersivePhotoMode)
        .memorySharePresentation(coordinator: shareCoordinator)
        .sheet(isPresented: $showCaptionEditor) {
            captionEditorSheet
        }
        .sheet(isPresented: $showStickerPicker) {
            MomentCanvasStickerPickerSheet(allowedMomentIDs: allowedMomentIDs) { momentID in
                createSticker(from: momentID)
            }
        }
        .onAppear {
            reloadCanvasFromDisk()
            refreshStickerImages()
        }
    }

    // MARK: - Scrapbook layout

    private var scrapbookView: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .bottom) {
                Color(red: 0.96, green: 0.95, blue: 0.93)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        heroPhotoSection
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        metadataSection
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            .background(Color(red: 0.96, green: 0.95, blue: 0.93))
                            .zIndex(2)
                            .contentShape(Rectangle())
                            .onTapGesture { dismissNoteKeyboardIfNeeded() }
                            .background {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: MemoryPageMetadataBottomKey.self,
                                        value: proxy.frame(in: .named("memoryPageScrollContent")).maxY
                                    )
                                }
                            }

                        Color.clear
                            .frame(height: MemoryPageLayout.noteScrollContentOffset(canvasWidth: scrapbookCanvasWidth))
                            .contentShape(Rectangle())
                            .onTapGesture { dismissNoteKeyboardIfNeeded() }
                            .id("memoryNoteScrollAnchor")

                        Color.clear
                            .frame(height: MemoryPageLayout.sandboxBelowNoteHeight(canvasWidth: scrapbookCanvasWidth))
                            .contentShape(Rectangle())
                            .onTapGesture { dismissNoteKeyboardIfNeeded() }
                            .id("stickerSandbox")
                    }
                    .coordinateSpace(name: "memoryPageScrollContent")
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: MemoryPageContentHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                    .overlay {
                        GeometryReader { geo in
                            MemoryCanvasLayer(
                                stickers: canvas.stickers,
                                images: stickerImages,
                                notes: canvas.displayedNotes,
                                composingAuthor: isComposingNote ? .localUser : nil,
                                composingNotePosition: composingNotePosition,
                                metadataBottomY: metadataBottomY,
                                isComposingNote: isComposingNote,
                                isEditingStickers: isEditingStickers,
                                selectedStickerID: selectedStickerID,
                                noteDraft: $noteDraft,
                                isNoteFocused: $isNoteFocused,
                                onNotePositionChanged: { author, pos in
                                    let clamped = MemoryPageLayout.clampNotePosition(
                                        pos,
                                        metadataBottomY: metadataBottomY,
                                        contentHeight: geo.size.height,
                                        canvasWidth: geo.size.width
                                    )
                                    if isComposingNote, author == .localUser {
                                        composingNotePosition = clamped
                                    } else {
                                        canvas.setNotePosition(clamped, for: author)
                                    }
                                },
                                onStickerPositionChanged: updateStickerPosition,
                                onStickerScaleChanged: updateStickerScale,
                                onStickerRotationChanged: updateStickerRotation,
                                onSelectSticker: { selectedStickerID = $0 },
                                onDeleteSticker: deleteSticker,
                                onCanvasDragEnded: persistCanvasUnlessEditingStickers,
                                onCanvasDragActiveChanged: { isCanvasDragActive = $0 }
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                            .mask(alignment: .top) {
                                if metadataBottomY > 0 {
                                    Rectangle()
                                        .frame(height: max(geo.size.height - metadataBottomY, 0))
                                        .offset(y: metadataBottomY)
                                } else {
                                    Rectangle()
                                }
                            }
                            .zIndex(1)
                        }
                    }
                }
                .onPreferenceChange(MemoryPageMetadataBottomKey.self) { metadataBottomY = $0 }
                .onPreferenceChange(MemoryPageContentHeightKey.self) { pageContentHeight = $0 }
                .scrollDisabled(isCanvasDragActive && (isComposingNote || isEditingStickers))
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .top, spacing: 0) {
                    browseTopBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .background {
                            Color(red: 0.96, green: 0.95, blue: 0.93)
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                                .ignoresSafeArea(edges: .top)
                        }
                }

                Group {
                    if isEditingStickers {
                        MemoryStickerEditFooterBar(onAddMore: { showStickerPicker = true })
                    } else if !isComposingNote {
                        EditGardenFooterBar(
                            noteButtonTitle: memoryNoteButtonTitle,
                            stickerButtonTitle: stickerFooterButtonTitle,
                            onAddNote: { beginNoteComposing(using: scrollProxy) },
                            onCreateStickers: { handleStickerFooterTap(using: scrollProxy) }
                        )
                    }
                }
                .background {
                    if isEditingStickers || !isComposingNote {
                        Color(red: 0.96, green: 0.95, blue: 0.93)
                            .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isComposingNote)
            }
            .onChange(of: isEditingStickers) { _, editing in
                if editing {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        scrollProxy.scrollTo("stickerSandbox", anchor: .top)
                    }
                }
            }
            .onChange(of: isComposingNote) { _, composing in
                if composing {
                    scrollToNoteForComposing(using: scrollProxy, animated: true)
                }
            }
            .onChange(of: metadataBottomY) { _, bottomY in
                guard bottomY > 0 else { return }
                for note in canvas.displayedNotes {
                    guard let pos = note.position else { continue }
                    let clamped = MemoryPageLayout.clampNotePosition(
                        pos,
                        metadataBottomY: bottomY,
                        contentHeight: layoutContentHeight,
                        canvasWidth: scrapbookCanvasWidth
                    )
                    if clamped != pos {
                        canvas.setNotePosition(clamped, for: note.author)
                    }
                }
                guard isComposingNote else { return }
                if composingNotePosition == nil {
                    composingNotePosition = defaultNotePositionForLayout(author: .localUser)
                } else if let pos = composingNotePosition {
                    composingNotePosition = MemoryPageLayout.clampNotePosition(
                        pos,
                        metadataBottomY: bottomY,
                        contentHeight: layoutContentHeight,
                        canvasWidth: scrapbookCanvasWidth
                    )
                }
                scrollToNoteForComposing(using: scrollProxy, animated: false)
            }
        }
    }

    private var scrapbookCanvasWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    private func dismissNoteKeyboardIfNeeded() {
        guard isComposingNote, isNoteFocused else { return }
        isNoteFocused = false
    }

    private func scrollToNoteForComposing(using scrollProxy: ScrollViewProxy, animated: Bool) {
        let scroll = {
            scrollProxy.scrollTo(
                "memoryNoteScrollAnchor",
                anchor: UnitPoint(
                    x: 0.5,
                    y: MemoryPageLayout.noteComposeScrollAnchorUnitY
                )
            )
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.32), scroll)
        } else {
            scroll()
        }
    }

    private var heroPhotoSection: some View {
        let aspect: CGFloat = 4 / 5

        return TabView(selection: $currentIndex) {
            ForEach(Array(updatedMoments.enumerated()), id: \.element.id) { index, moment in
                Image(uiImage: moment.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .aspectRatio(aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if updatedMoments.count > 1 {
                heroThumbnailStrip
                    .padding(12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isComposingNote {
                dismissNoteKeyboardIfNeeded()
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isImmersivePhotoMode = true
                }
            }
        }
    }

    private var heroThumbnailStrip: some View {
        let thumbSize: CGFloat = 52
        let spacing: CGFloat = 8
        let pad: CGFloat = 8

        let row = HStack(spacing: spacing) {
            ForEach(Array(updatedMoments.enumerated()), id: \.element.id) { index, moment in
                Image(uiImage: moment.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbSize, height: thumbSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                index == currentIndex ? Color.white : Color.white.opacity(0.5),
                                lineWidth: index == currentIndex ? 2.5 : 1
                            )
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentIndex = index
                        }
                    }
            }
        }

        return Group {
            if updatedMoments.count > 5 {
                ScrollView(.horizontal, showsIndicators: false) {
                    row
                }
                .frame(width: thumbSize * 5 + spacing * 4 + pad * 2)
            } else {
                row
            }
        }
        .padding(pad)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .fixedSize(horizontal: true, vertical: true)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let memoryPagePromptText {
                PromptDisplayCard(prompt: memoryPagePromptText, variant: .momentPage)
            } else if let foundingPromptText {
                PromptDisplayCard(prompt: foundingPromptText, variant: .momentPage)
            }

            if let importantDate = memoryPageImportantDate {
                ImportantDateMetadataCard(title: importantDate.title, date: importantDate.date)
            }

            if memoryPageImportantDate == nil,
               let foundingMoment = foundingMomentWithPlaceName,
               let formatted = foundingPlaceDisplay(for: foundingMoment) {
                Text(formatted)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            } else if memoryPageImportantDate == nil, let place = primaryPlaceDisplay {
                Text(place)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }

            if memoryPageImportantDate == nil {
                Text(dateFormatter.string(from: currentMoment.dateTaken))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
            }

            if let loveNote = loveNoteText {
                Text(loveNote)
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Immersive photo

    private var immersivePhotoView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(updatedMoments.enumerated()), id: \.element.id) { index, moment in
                    Image(uiImage: moment.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    CircleBackdropCloseButton {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isImmersivePhotoMode = false
                        }
                    }
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.horizontal, 20)
                Spacer()
            }
        }
    }

    // MARK: - Chrome

    private var browseTopBar: some View {
        HStack {
            if !isComposingNote && !isEditingStickers {
                CircleBackdropCloseButton(action: onDismiss)
            }

            if isComposingNote {
                Button("Cancel") { cancelNoteComposing() }
                    .font(.body.weight(.bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9), in: Capsule())
                    .buttonStyle(.plain)
            } else if isEditingStickers {
                Button("Cancel") { cancelStickerEditing() }
                    .font(.body.weight(.bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9), in: Capsule())
                    .buttonStyle(.plain)
            }

            Spacer()

            if isComposingNote {
                Button("SAVE") { saveNoteComposing() }
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(BabyTownTheme.savePillFill, in: Capsule())
                    .buttonStyle(.plain)
            } else if isEditingStickers {
                Button("SAVE") { finishStickerEditing() }
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(BabyTownTheme.savePillFill, in: Capsule())
                    .buttonStyle(.plain)
            } else {
                browseActionButtons
            }
        }
    }

    private var showsCaptionEditor: Bool {
        memoryPageImportantDate == nil
    }

    private var browseActionButtons: some View {
        HStack {
            if showsCaptionEditor {
            Button {
                showCaptionEditor = true
            } label: {
                Text("Edit")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.9)))
            }
            }

            if hasNavigationDestination {
                Button {
                    showMapsChooser = true
                } label: {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(45))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.green))
                }
                .confirmationDialog("Open this place in", isPresented: $showMapsChooser, titleVisibility: .visible) {
                    Button("Apple Maps") { openInMaps(useGoogle: false) }
                    Button("Google Maps") { openInMaps(useGoogle: true) }
                    Button("Cancel", role: .cancel) {}
                }
            }

            Button(action: shareCurrentMoment) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.9)))
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("No photos to display")
                    .foregroundStyle(.white)
                Button("Dismiss") { onDismiss() }
                    .padding()
            }
        }
    }

    // MARK: - Caption editor

    private var captionEditorSheet: some View {
        CaptionEditorSheet(
            section: editingSection,
            onSave: { momentId, newCaption, placeName, latitude, longitude, isPlaceNameUserSet in
                if let memoryId = promptMemoryId, let onEditPromptMemory {
                    onEditPromptMemory(
                        memoryId,
                        momentId,
                        newCaption,
                        placeName,
                        latitude,
                        longitude,
                        isPlaceNameUserSet
                    )
                } else if let onEditMemory {
                    onEditMemory(
                        editingSection,
                        momentId,
                        newCaption,
                        placeName,
                        latitude,
                        longitude,
                        isPlaceNameUserSet
                    )
                } else {
                    onEditCaption?(momentId, newCaption, nil)
                }
                reloadMemoryMoments()
            },
            onAddPhotos: { images in
                if let memoryId = promptMemoryId, let onAddPromptPhotos {
                    onAddPromptPhotos(memoryId, images)
                } else {
                    onAddPhotos?(editingSection, images)
                }
                reloadMemoryMoments()
            },
            onRemovePhoto: { momentId in
                if let memoryId = promptMemoryId, let onRemovePromptPhoto {
                    onRemovePromptPhoto(memoryId, momentId)
                } else {
                    onRemovePhoto?(editingSection, momentId)
                }
                reloadMemoryMoments()
            },
            onSyncMemoryPhotos: { assetIds, orphanIds in
                if let memoryId = promptMemoryId, let onSyncPromptMemoryPhotos {
                    Task {
                        await onSyncPromptMemoryPhotos(memoryId, assetIds, orphanIds)
                        reloadMemoryMoments()
                    }
                } else {
                    let section = editingSection
                    Task {
                        await onSyncMemoryPhotos?(section, assetIds, orphanIds)
                        reloadMemoryMoments()
                    }
                }
            }
        )
    }

    private var editingSection: DaySection {
        DaySection(date: sortedMoments.first?.dateTaken ?? Date(), placeName: sortedMoments.first?.placeName, moments: sortedMoments)
    }

    // MARK: - Metadata helpers

    private var primaryPlaceDisplay: String? {
        guard let moment = sortedMoments.first else { return nil }
        let raw = moment.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return PlaceNameFormatting.displayName(raw: moment.placeName, isUserSet: moment.isPlaceNameUserSet) ?? raw
    }

    private func foundingPlaceDisplay(for moment: Moment) -> String? {
        let raw = moment.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return PlaceNameFormatting.displayName(raw: moment.placeName, isUserSet: moment.isPlaceNameUserSet) ?? raw
    }

    // MARK: - Canvas persistence

    private func reloadCanvasFromDisk() {
        let key = MemoryCanvas.memoryKey(anchorMomentId: anchorMomentId)
        if var stored = dpm.loadMemoryCanvases()[key] {
            stored.stickers.removeAll { sticker in
                guard sticker.kind == .moment else { return true }
                if allowedMomentIDs.contains(UUID(uuidString: sticker.sourceKey) ?? UUID()) { return false }
                dpm.deleteStickerImage(id: sticker.id)
                return true
            }
            canvas = stored
        } else {
            canvas = MemoryCanvas(memoryKey: key)
        }
    }

    private func persistCanvas() {
        dpm.saveMemoryCanvas(canvas)
    }

    private func persistCanvasUnlessEditingStickers() {
        guard !isEditingStickers else { return }
        persistCanvas()
    }

    private func refreshStickerImages() {
        var images: [UUID: UIImage] = [:]
        for sticker in canvas.stickers {
            if let img = dpm.loadStickerImage(id: sticker.id) {
                images[sticker.id] = img
            }
        }
        stickerImages = images
    }

    private func handleStickerFooterTap(using scrollProxy: ScrollViewProxy) {
        if canvas.stickers.isEmpty {
            showStickerPicker = true
        } else {
            isEditingStickers = true
            selectedStickerID = nil
            withAnimation(.easeInOut(duration: 0.32)) {
                scrollProxy.scrollTo("stickerSandbox", anchor: .top)
            }
        }
    }

    private func cancelStickerEditing() {
        for id in pendingNewStickerIDs {
            dpm.deleteStickerImage(id: id)
        }
        pendingNewStickerIDs.removeAll()
        pendingStickerImageDeletions.removeAll()
        reloadCanvasFromDisk()
        refreshStickerImages()
        isEditingStickers = false
        selectedStickerID = nil
    }

    private func finishStickerEditing() {
        for id in pendingStickerImageDeletions {
            dpm.deleteStickerImage(id: id)
        }
        pendingNewStickerIDs.removeAll()
        pendingStickerImageDeletions.removeAll()
        isEditingStickers = false
        selectedStickerID = nil
        persistCanvas()
    }

    private var layoutContentHeight: CGFloat {
        max(pageContentHeight, metadataBottomY + MemoryPageLayout.stickerSandboxHeight, 1)
    }

    private func defaultNotePositionForLayout(author: MemoryNoteAuthor = .localUser) -> NormalizedPoint {
        MemoryPageLayout.defaultNotePosition(
            for: author,
            existingNotes: canvas.displayedNotes,
            metadataBottomY: metadataBottomY,
            contentHeight: layoutContentHeight,
            canvasWidth: UIScreen.main.bounds.width
        )
    }

    private func beginNoteComposing(using scrollProxy: ScrollViewProxy) {
        let noteWidth = ProfileGardenNoteLayout.noteWidth(for: scrapbookCanvasWidth)
        noteDraft = canvas.localUserNote.map {
            ProfileGardenNoteLayout.clampedNoteText($0.text, noteWidth: noteWidth)
        } ?? ""
        composingNotePosition = canvas.localUserNote?.position
        selectedStickerID = nil
        isComposingNote = true
        scrollToNoteForComposing(using: scrollProxy, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if metadataBottomY > 0, composingNotePosition == nil {
                composingNotePosition = defaultNotePositionForLayout(author: .localUser)
            }
            scrollToNoteForComposing(using: scrollProxy, animated: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollToNoteForComposing(using: scrollProxy, animated: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            scrollToNoteForComposing(using: scrollProxy, animated: false)
            isNoteFocused = true
        }
    }

    private func cancelNoteComposing() {
        let noteWidth = ProfileGardenNoteLayout.noteWidth(for: scrapbookCanvasWidth)
        noteDraft = canvas.localUserNote.map {
            ProfileGardenNoteLayout.clampedNoteText($0.text, noteWidth: noteWidth)
        } ?? ""
        composingNotePosition = nil
        isComposingNote = false
        isNoteFocused = false
        selectedStickerID = nil
    }

    private func saveNoteComposing() {
        let noteWidth = ProfileGardenNoteLayout.noteWidth(for: scrapbookCanvasWidth)
        let trimmed = ProfileGardenNoteLayout.clampedNoteText(noteDraft, noteWidth: noteWidth)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let position = composingNotePosition
            ?? canvas.localUserNote?.position
            ?? defaultNotePositionForLayout(author: .localUser)
        canvas.upsertNote(
            author: .localUser,
            text: trimmed.isEmpty ? nil : trimmed,
            position: trimmed.isEmpty ? nil : position
        )
        persistCanvas()
        composingNotePosition = nil
        isComposingNote = false
        isNoteFocused = false
        selectedStickerID = nil
    }

    private func createSticker(from momentID: UUID) {
        let sourceImage =
            PetGalleryPhotoLoader.image(for: momentID)
            ?? dpm.loadMoments().first(where: { $0.id == momentID })?.thumbnail
            ?? updatedMoments.first(where: { $0.id == momentID })?.thumbnail
        guard let sourceImage else { return }

        let processed = SubjectLiftService.stickerImage(from: sourceImage)
        let sticker = ProfileSticker(
            kind: .moment,
            sourceKey: momentID.uuidString,
            position: nextStickerPosition(),
            rotation: Double.random(in: -10...10),
            scale: ProfileSticker.memoryPageNewStickerScale,
            usedSubjectLift: processed.usedSubjectLift
        )
        dpm.saveStickerImage(processed.image, id: sticker.id)
        canvas.stickers.append(sticker)
        stickerImages[sticker.id] = processed.image
        pendingNewStickerIDs.insert(sticker.id)
        isEditingStickers = true
        selectedStickerID = sticker.id
    }

    private func nextStickerPosition() -> NormalizedPoint {
        let contentHeight = layoutContentHeight
        let existing = canvas.stickers.map(\.position)
        let minDistance: CGFloat = 0.14
        let candidates = (0..<6).map {
            MemoryPageLayout.defaultStickerPosition(
                metadataBottomY: metadataBottomY,
                contentHeight: contentHeight,
                index: $0
            )
        }
        for candidate in candidates {
            let isClear = existing.allSatisfy {
                hypot($0.x - candidate.x, $0.y - candidate.y) > minDistance
            }
            if isClear { return candidate }
        }
        let bounds = MemoryPageLayout.stickerDragBounds(
            metadataBottomY: metadataBottomY,
            contentHeight: contentHeight
        )
        return NormalizedPoint(
            x: .random(in: bounds.minX...bounds.maxX),
            y: .random(in: bounds.minY...bounds.maxY)
        )
    }

    private func updateStickerPosition(id: UUID, position: NormalizedPoint) {
        guard let idx = canvas.stickers.firstIndex(where: { $0.id == id }) else { return }
        canvas.stickers[idx].position = position
    }

    private func updateStickerScale(id: UUID, scale: CGFloat) {
        guard let idx = canvas.stickers.firstIndex(where: { $0.id == id }) else { return }
        canvas.stickers[idx].scale = scale
    }

    private func updateStickerRotation(id: UUID, rotation: Double) {
        guard let idx = canvas.stickers.firstIndex(where: { $0.id == id }) else { return }
        canvas.stickers[idx].rotation = rotation
    }

    private func deleteSticker(_ id: UUID) {
        guard let idx = canvas.stickers.firstIndex(where: { $0.id == id }) else { return }
        canvas.stickers.remove(at: idx)
        stickerImages[id] = nil
        if pendingNewStickerIDs.contains(id) {
            dpm.deleteStickerImage(id: id)
            pendingNewStickerIDs.remove(id)
        } else {
            pendingStickerImageDeletions.insert(id)
        }
        if selectedStickerID == id { selectedStickerID = nil }
    }

    private func reloadMemoryMoments() {
        let reload = onReloadPromptMoments ?? onReloadMemoryMoments
        guard let reload else { return }
        let fresh = reload()
        guard !fresh.isEmpty else {
            onDismiss()
            return
        }
        updatedMoments = fresh
        if currentIndex >= fresh.count {
            currentIndex = max(0, fresh.count - 1)
        }
        onUpdateMoments(fresh)
        reloadCanvasFromDisk()
        refreshStickerImages()
    }

    // MARK: - Share & maps

    private func shareCurrentMoment() {
        let moment = currentMoment
        let payload = MemorySharePayload(
            id: moment.id,
            date: memoryPageImportantDate?.date ?? moment.dateTaken,
            placeName: moment.placeName,
            isPlaceNameUserSet: moment.isPlaceNameUserSet,
            promptText: memoryPageImportantDate?.title ?? memoryPagePromptText ?? moment.promptText,
            loveNote: moment.caption,
            photoSources: sortedMoments.map {
                MemorySharePhotoSource(
                    id: $0.id,
                    thumbnail: $0.thumbnail,
                    assetIdentifier: $0.assetIdentifier,
                    isLocked: $0.isLocked
                )
            }
        )
        shareCoordinator.share(payload)
    }

    private var hasNavigationDestination: Bool {
        (currentMoment.latitude != nil && currentMoment.longitude != nil)
            || !(currentMoment.placeName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var navigationQuery: String {
        if let name = currentMoment.placeName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let lat = currentMoment.latitude, let lon = currentMoment.longitude {
            return "\(lat),\(lon)"
        }
        return ""
    }

    private func openInMaps(useGoogle: Bool) {
        let query = navigationQuery
        guard !query.isEmpty else { return }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let urlString: String
        if useGoogle {
            urlString = "https://www.google.com/maps/search/?api=1&query=\(encoded)"
        } else {
            var apple = "http://maps.apple.com/?q=\(encoded)"
            if let lat = currentMoment.latitude, let lon = currentMoment.longitude {
                apple += "&ll=\(lat),\(lon)"
            }
            urlString = apple
        }

        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}
