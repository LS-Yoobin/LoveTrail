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
    
    @State private var currentIndex: Int
    @State private var updatedMoments: [Moment]
    @State private var showCaptionEditor = false
    @State private var showChrome = true
    @State private var showMapsChooser = false
    @StateObject private var shareCoordinator = MemoryShareCoordinator()

    @Environment(\.openURL) private var openURL
    
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
        onReloadMemoryMoments: (() -> [Moment])? = nil
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
        _currentIndex = State(initialValue: initialIndex)
        _updatedMoments = State(initialValue: moments)
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
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter
    }
    
    private var loveNoteText: String? {
        let note = updatedMoments
            .compactMap { moment -> String? in
                guard let caption = moment.caption?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !caption.isEmpty else { return nil }
                return caption
            }
            .first
        return note
    }

    private static let foundingPrompts: Set<String> = [
        "When we first met",
        "When we became official"
    ]

    private var foundingPromptText: String? {
        guard let prompt = updatedMoments.first?.promptText,
              Self.foundingPrompts.contains(prompt) else { return nil }
        return prompt
    }

    private var foundingMomentWithPlaceName: Moment? {
        guard foundingPromptText != nil else { return nil }
        return updatedMoments.first(where: {
            guard let name = $0.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return !name.isEmpty
        })
    }

    private var photoMetadataDisplay: some View {
        HStack {
            VStack(alignment: .leading, spacing: loveNoteText == nil ? 0 : 8) {
                Text(dateFormatter.string(from: currentMoment.dateTaken))
                    .font(.system(size: 15, weight: .semibold))

                if let loveNote = loveNoteText {
                    Text(loveNote)
                        .font(.system(size: 15, weight: .regular))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(.white)
            .photoViewerLegibleText()
            .padding(.horizontal, 16)
            .padding(.vertical, loveNoteText == nil ? 10 : 14)
            .background(photoViewerMetadataBackground)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if updatedMoments.isEmpty {
                VStack {
                    Text("No photos to display")
                        .foregroundStyle(.white)
                    Button("Dismiss") { onDismiss() }
                        .padding()
                }
            } else {
                TabView(selection: $currentIndex) {
                ForEach(Array(updatedMoments.enumerated()), id: \.element.id) { index, moment in
                    photoView(for: moment)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            
                viewerChromeOverlay
            }
        }
        .statusBarHidden(true)
        .memorySharePresentation(coordinator: shareCoordinator)
        .sheet(isPresented: $showCaptionEditor) {
            CaptionEditorSheet(
                section: editingSection,
                onSave: { momentId, newCaption, placeName, latitude, longitude, isPlaceNameUserSet in
                    if let onEditMemory {
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
                    onAddPhotos?(editingSection, images)
                    reloadMemoryMoments()
                },
                onRemovePhoto: { momentId in
                    onRemovePhoto?(editingSection, momentId)
                    reloadMemoryMoments()
                },
                onSyncMemoryPhotos: { assetIds, orphanIds in
                    let section = editingSection
                    Task {
                        await onSyncMemoryPhotos?(section, assetIds, orphanIds)
                        reloadMemoryMoments()
                    }
                }
            )
        }
    }

    private var editingSection: DaySection {
        let sorted = updatedMoments.sorted { $0.dateTaken < $1.dateTaken }
        let first = sorted.first ?? moments.first ?? Moment.sampleMoment
        return DaySection(date: first.dateTaken, placeName: first.placeName, moments: sorted)
    }

    private func reloadMemoryMoments() {
        guard let reload = onReloadMemoryMoments else { return }
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
    }
    
    // MARK: - Photo View
    
    private func photoView(for moment: Moment) -> some View {
        Image(uiImage: moment.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: handlePhotoTap)
    }

    private func handlePhotoTap() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showChrome.toggle()
        }
    }

    private var viewerChromeOverlay: some View {
        VStack(spacing: 0) {
            topBar
                .allowsHitTesting(showChrome)

            Spacer()
                .allowsHitTesting(false)

            viewerChromeBottom
                .allowsHitTesting(showChrome)
        }
        .opacity(showChrome ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showChrome)
        .allowsHitTesting(showChrome)
        .background(alignment: .top) {
            if showChrome {
                PhotoViewerTopScrim()
            }
        }
        .background(alignment: .bottom) {
            if showChrome {
                photoViewerBottomGradient
            }
        }
    }

    @ViewBuilder
    private var viewerChromeBottom: some View {
        if let foundingPromptText {
            PromptDisplayCard(prompt: foundingPromptText)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }

        if let foundingMoment = foundingMomentWithPlaceName {
            foundingPlaceNameDisplay(moment: foundingMoment)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }

        photoMetadataDisplay
            .padding(.bottom, 8)

        if updatedMoments.count > 1 {
            photoPreviewStrip
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            CircleBackdropCloseButton(action: onDismiss)

            Spacer()

            Button(action: shareCurrentMoment) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .padding(.trailing, 4)

            if hasNavigationDestination {
                Button {
                    showMapsChooser = true
                } label: {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(45))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.green))
                }
                .padding(.trailing, 4)
                .confirmationDialog("Open this place in", isPresented: $showMapsChooser, titleVisibility: .visible) {
                    Button("Apple Maps") { openInMaps(useGoogle: false) }
                    Button("Google Maps") { openInMaps(useGoogle: true) }
                    Button("Cancel", role: .cancel) {}
                }
            }

            Button {
                showCaptionEditor = true
            } label: {
                Text("Edit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }

    // MARK: - Share

    private func shareCurrentMoment() {
        let moment = currentMoment
        let payload = MemorySharePayload(
            id: moment.id,
            date: moment.dateTaken,
            placeName: moment.placeName,
            isPlaceNameUserSet: moment.isPlaceNameUserSet,
            promptText: moment.promptText,
            loveNote: moment.caption,
            photoSources: [
                MemorySharePhotoSource(
                    id: moment.id,
                    thumbnail: moment.thumbnail,
                    assetIdentifier: moment.assetIdentifier,
                    isLocked: moment.isLocked
                )
            ]
        )
        shareCoordinator.share(payload)
    }

    // MARK: - Navigation (open place in Maps)

    private var hasNavigationDestination: Bool {
        (currentMoment.latitude != nil && currentMoment.longitude != nil)
            || !(currentMoment.placeName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Search query: prefer the place name, fall back to coordinates.
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
            // Universal link: opens the Google Maps app if installed, else the web.
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

    // MARK: - Photo Preview Strip
    
    private var photoPreviewStrip: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(updatedMoments.enumerated()), id: \.element.id) { index, moment in
                            thumbnailView(for: moment, at: index)
                                .id(index)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(.bottom, 20)
    }
    
    private func thumbnailView(for moment: Moment, at index: Int) -> some View {
        let isSelected = index == currentIndex
        
        return Image(uiImage: moment.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 1.5)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .shadow(color: .black.opacity(isSelected ? 0.5 : 0.3), radius: isSelected ? 8 : 4, y: 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var photoViewerMetadataBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.black.opacity(0.68))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
    }

    private func foundingPlaceNameDisplay(moment: Moment) -> some View {
        HStack(spacing: 8) {
            PlaceNameLabel(
                rawPlaceName: moment.placeName,
                isUserSet: moment.isPlaceNameUserSet,
                font: .system(size: 14, weight: .medium),
                foregroundStyle: .white,
                iconSize: 14,
                spacing: 6,
                lineLimit: 2
            )

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .photoViewerLegibleText()
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(photoViewerMetadataBackground)
    }

    private var photoViewerBottomGradient: some View {
        let hasFoundingExtras = foundingPromptText != nil
        let baseHeight: CGFloat = loveNoteText == nil ? 140 : 220
        let foundingExtra: CGFloat = hasFoundingExtras ? (foundingMomentWithPlaceName != nil ? 160 : 80) : 0

        return LinearGradient(
            colors: [
                Color.black.opacity(0),
                Color.black.opacity(0.35),
                Color.black.opacity(0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity)
        .frame(height: baseHeight + foundingExtra)
        .allowsHitTesting(false)
    }

}

// MARK: - Legible overlay text (light or dark photos)

private extension View {
    func photoViewerLegibleText() -> some View {
        self
            .shadow(color: .black.opacity(0.95), radius: 0, x: 0, y: 0.5)
            .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 3)
    }
}
