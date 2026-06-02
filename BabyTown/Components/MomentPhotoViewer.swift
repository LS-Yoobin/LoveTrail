import SwiftUI
import Photos
import PhotosUI

struct MomentPhotoViewer: View {
    
    let moments: [Moment]
    let initialIndex: Int
    var onDismiss: () -> Void
    var onUpdateMoments: ([Moment]) -> Void
    var onDeleteMoment: ((Moment) -> Void)? = nil
    
    @State private var currentIndex: Int
    @State private var editMode = false
    @State private var momentsBeforeEdit: [Moment]?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var updatedMoments: [Moment]
    @State private var showDeleteConfirmation = false
    @State private var showFoundingDeleteBlockedAlert = false
    @State private var showChrome = true
    @State private var showMapsChooser = false
    @StateObject private var shareCoordinator = MemoryShareCoordinator()

    @Environment(\.openURL) private var openURL
    
    init(
        moments: [Moment],
        initialIndex: Int,
        onDismiss: @escaping () -> Void,
        onUpdateMoments: @escaping ([Moment]) -> Void,
        onDeleteMoment: ((Moment) -> Void)? = nil
    ) {
        self.moments = moments
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self.onUpdateMoments = onUpdateMoments
        self.onDeleteMoment = onDeleteMoment
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
    
    var isFromCamera: Bool {
        currentMoment.assetIdentifier == nil
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
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                await handlePhotoSelection(newItems)
            }
        }
        .alert(
            isFromCamera ? "Remove Photo Permanently?" : "Remove Photo?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                deleteCurrentPhoto()
            }
        } message: {
            Text(isFromCamera 
                ? "This photo was taken with the in-app camera and will be removed permanently from the app."
                : "Would you like to remove this photo from the app?")
        }
        .alert("Keep this founding photo", isPresented: $showFoundingDeleteBlockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This memory needs a photo. Use the picker below to replace it instead of removing it.")
        }
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
        if editMode {
            cancelEditing()
            return
        }
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
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: editMode)
        .allowsHitTesting(showChrome)
        .background(alignment: .top) {
            if showChrome {
                PhotoViewerTopScrim()
            }
        }
        .background(alignment: .bottom) {
            if showChrome && !editMode {
                photoViewerBottomGradient
            }
        }
    }

    @ViewBuilder
    private var viewerChromeBottom: some View {
        if !editMode {
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
        }

        if editMode {
            PhotoViewerPolaroidEditTray(
                selectedPhotos: $selectedPhotos,
                onRemove: { showDeleteConfirmation = true }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if updatedMoments.count > 1 {
            photoPreviewStrip
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Group {
                if editMode {
                    Button(action: cancelEditing) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                } else {
                    CircleBackdropCloseButton(action: onDismiss)
                }
            }
            
            Spacer()

            if !editMode {
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
            }

            Button(action: finishEditing) {
                Text(editMode ? "Done" : "Edit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(editMode ? Color.green.opacity(0.3) : Color.white.opacity(0.2))
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

    private func finishEditing() {
        if editMode {
            commitEditingChanges()
        } else {
            momentsBeforeEdit = updatedMoments
            editMode = true
        }
    }

    private func commitEditingChanges() {
        onUpdateMoments(updatedMoments)
        momentsBeforeEdit = nil
        editMode = false
    }

    private func cancelEditing() {
        if let snapshot = momentsBeforeEdit {
            updatedMoments = snapshot
        }
        momentsBeforeEdit = nil
        editMode = false
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
    
    // MARK: - Photo Selection
    
    private func handlePhotoSelection(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            // Replace only the photo; preserve every other field so the moment
            // keeps its identity (prompt, pin state, location, voice note, etc.).
            // Dropping these previously turned founding prompt moments into
            // ordinary, prompt-less timeline entries.
            let existing = updatedMoments[currentIndex]
            updatedMoments[currentIndex] = Moment(
                id: existing.id,
                dateTaken: existing.dateTaken,
                assetIdentifier: nil,
                thumbnail: image,
                placeName: existing.placeName,
                caption: existing.caption,
                voiceNotePath: existing.voiceNotePath,
                promptText: existing.promptText,
                isPinned: existing.isPinned,
                pinnedAt: existing.pinnedAt,
                isLocked: existing.isLocked,
                unlockTime: existing.unlockTime,
                latitude: existing.latitude,
                longitude: existing.longitude,
                isAddedFromOnThisDay: existing.isAddedFromOnThisDay,
                isPlaceNameUserSet: existing.isPlaceNameUserSet,
                country: existing.country
            )

            selectedPhotos = []
            commitEditingChanges()
        } else {
            selectedPhotos = []
        }
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

    // MARK: - Delete Photo

    private func requestRemoveCurrentPhoto() {
        if foundingPromptText != nil, updatedMoments.count == 1 {
            showFoundingDeleteBlockedAlert = true
            return
        }
        showDeleteConfirmation = true
    }
    
    private func deleteCurrentPhoto() {
        let momentToDelete = currentMoment
        
        // Remove from local array
        updatedMoments.remove(at: currentIndex)
        
        // Adjust current index if needed
        if updatedMoments.isEmpty {
            // If no photos left, call delete callback and dismiss
            onDeleteMoment?(momentToDelete)
            onDismiss()
        } else {
            // Adjust index if we deleted the last photo
            if currentIndex >= updatedMoments.count {
                currentIndex = updatedMoments.count - 1
            }
            
            // Update the moments and call delete callback
            onUpdateMoments(updatedMoments)
            onDeleteMoment?(momentToDelete)
        }
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
