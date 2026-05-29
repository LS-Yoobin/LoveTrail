import SwiftUI

struct PromptPhotoViewer: View {
    
    let photos: [PromptPhoto]
    let initialIndex: Int
    var onDismiss: () -> Void
    var onUpdatePhotos: (([PromptPhoto]) -> Void)? = nil
    var onDeletePhoto: ((PromptPhoto) -> Void)? = nil
    var promptText: String? = nil
    
    @State private var currentIndex: Int
    @State private var editMode = false
    @State private var photosBeforeEdit: [PromptPhoto]?
    @State private var updatedPhotos: [PromptPhoto]
    @State private var showDeleteConfirmation = false
    @State private var showChrome = true
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter
    }
    
    init(
        photos: [PromptPhoto],
        initialIndex: Int,
        onDismiss: @escaping () -> Void,
        onUpdatePhotos: (([PromptPhoto]) -> Void)? = nil,
        onDeletePhoto: ((PromptPhoto) -> Void)? = nil,
        promptText: String? = nil
    ) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self.onUpdatePhotos = onUpdatePhotos
        self.onDeletePhoto = onDeletePhoto
        self.promptText = promptText
        _currentIndex = State(initialValue: initialIndex)
        _updatedPhotos = State(initialValue: photos)
    }
    
    var currentPhoto: PromptPhoto {
        if updatedPhotos.isEmpty {
            return photos.first ?? PromptPhoto(id: UUID(), dateTaken: Date(), thumbnail: UIImage(systemName: "photo")!)
        }
        guard currentIndex < updatedPhotos.count else {
            return updatedPhotos.last ?? photos.first ?? PromptPhoto(id: UUID(), dateTaken: Date(), thumbnail: UIImage(systemName: "photo")!)
        }
        return updatedPhotos[currentIndex]
    }
    
    var isFromCamera: Bool {
        currentPhoto.isFromCamera
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if updatedPhotos.isEmpty {
                VStack {
                    Text("No photos to display")
                        .foregroundStyle(.white)
                    Button("Dismiss") { onDismiss() }
                        .padding()
                }
            } else {
                TabView(selection: $currentIndex) {
                ForEach(Array(updatedPhotos.enumerated()), id: \.element.id) { index, photo in
                    photoView(for: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

                viewerChromeOverlay
            }
        }
        .statusBarHidden(true)
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
    }
    
    private func photoView(for photo: PromptPhoto) -> some View {
        Image(uiImage: photo.thumbnail)
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
    }

    @ViewBuilder
    private var viewerChromeBottom: some View {
        if !editMode {
            if let promptText {
                PromptDisplayCard(prompt: promptText)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            photoDateDisplay
                .padding(.bottom, 8)
        }

        if editMode {
            PhotoViewerPolaroidEditTray(
                selectedPhotos: .constant([]),
                showsReplace: false,
                onRemove: { showDeleteConfirmation = true }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if updatedPhotos.count > 1 {
            photoPreviewStrip
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: editMode ? cancelEditing : onDismiss) {
                if editMode {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            
            Spacer()
            
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

    private func finishEditing() {
        if editMode {
            onUpdatePhotos?(updatedPhotos)
            photosBeforeEdit = nil
            editMode = false
        } else {
            photosBeforeEdit = updatedPhotos
            editMode = true
        }
    }

    private func cancelEditing() {
        if let snapshot = photosBeforeEdit {
            updatedPhotos = snapshot
        }
        photosBeforeEdit = nil
        editMode = false
    }
    
    private var photoPreviewStrip: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(updatedPhotos.enumerated()), id: \.element.id) { index, photo in
                            thumbnailView(for: photo, at: index)
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
    
    private func thumbnailView(for photo: PromptPhoto, at index: Int) -> some View {
        let isSelected = index == currentIndex
        
        return Image(uiImage: photo.thumbnail)
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
    
    // MARK: - Delete Photo
    
    private func deleteCurrentPhoto() {
        let photoToDelete = currentPhoto
        
        // Remove from local array
        updatedPhotos.remove(at: currentIndex)
        
        // Adjust current index if needed
        if updatedPhotos.isEmpty {
            // If no photos left, call delete callback and dismiss
            onDeletePhoto?(photoToDelete)
            onDismiss()
        } else {
            // Adjust index if we deleted the last photo
            if currentIndex >= updatedPhotos.count {
                currentIndex = updatedPhotos.count - 1
            }
            
            // Update the photos and call delete callback
            onUpdatePhotos?(updatedPhotos)
            onDeletePhoto?(photoToDelete)
        }
    }
    
    // MARK: - Photo Date Display
    
    private var photoDateDisplay: some View {
        HStack {
            Text(dateFormatter.string(from: currentPhoto.dateTaken))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                )
            Spacer()
        }
        .padding(.leading, 20)
    }
    
}