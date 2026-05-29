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
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var updatedMoments: [Moment]
    @State private var showDeleteConfirmation = false
    
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
            
            
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    
                    photoMetadataDisplay
                        .padding(.bottom, 8)
                    
                    if editMode {
                        editControls
                    } else if updatedMoments.count > 1 {
                        photoPreviewStrip
                    }
                }
                .background(alignment: .bottom) {
                    photoViewerBottomGradient
                }
            }
        }
        .statusBarHidden(true)
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
    }
    
    // MARK: - Photo View
    
    private func photoView(for moment: Moment) -> some View {
        Image(uiImage: moment.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: {
                if editMode {
                    onUpdateMoments(updatedMoments)
                }
                onDismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.85))
            }
            
            Spacer()
            
            Button(action: {
                editMode.toggle()
            }) {
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
    
    // MARK: - Edit Controls
    
    private var editControls: some View {
        VStack(spacing: 16) {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 1,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16))
                    Text("Replace Photo")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                )
            }
            
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                    Text("Remove Photo")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.3))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 60)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.horizontal, -20)
        )
    }
    
    // MARK: - Photo Selection
    
    private func handlePhotoSelection(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            updatedMoments[currentIndex] = Moment(
                id: updatedMoments[currentIndex].id,
                dateTaken: updatedMoments[currentIndex].dateTaken,
                assetIdentifier: nil,
                thumbnail: image,
                placeName: updatedMoments[currentIndex].placeName,
                caption: updatedMoments[currentIndex].caption
            )
        }
        
        selectedPhotos = []
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

    private var photoViewerBottomGradient: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0),
                Color.black.opacity(0.35),
                Color.black.opacity(0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity)
        .frame(height: loveNoteText == nil ? 140 : 220)
        .allowsHitTesting(false)
    }

    // MARK: - Delete Photo
    
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
