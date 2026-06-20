import SwiftUI
import PhotosUI

/// Pick a saved Baby Town moment to turn into a draggable garden sticker.
/// Same grid + Open Gallery flow as the pet-room picture frame picker, without the frame preview.
struct GardenStickerPickerSheet: View {

    var onSelect: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var photos: [PetGalleryPhoto] = []
    @State private var highlightedPhotoID: UUID?
    @State private var showSystemGallery = false
    @State private var isImportingPhotos = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerCopy
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                Group {
                    if photos.isEmpty {
                        emptyGridState
                    } else {
                        photoGrid
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(BabyTownTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                openGalleryBottomBar
            }
            .fullScreenCover(isPresented: $showSystemGallery) {
                PhotoPickerView(
                    selectedImages: .constant([]),
                    selectionLimit: 0,
                    onFinish: { results in
                        showSystemGallery = false
                        Task { await handleSystemGalleryPicks(results) }
                    }
                )
                .ignoresSafeArea()
            }
            .onAppear { reloadPhotos() }
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BABYTOWN GALLERY OF MOMENTS THEY SAVED")
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
                .tracking(0.4)
            Text("Pick a photo to turn into a sticker for your garden.")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos) { photo in
                    Button {
                        highlightedPhotoID = photo.id
                        onSelect(photo.id)
                        dismiss()
                    } label: {
                        gridCell(for: photo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .padding(.bottom, 16)
        }
    }

    private func gridCell(for photo: PetGalleryPhoto) -> some View {
        let isHighlighted = highlightedPhotoID == photo.id

        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(uiImage: photo.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(BabyTownTheme.accentDeep, lineWidth: 3)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 4))
    }

    private var emptyGridState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38, weight: .thin))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.35))
            Text("No moments yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Use Open Gallery to add photos to Covela")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var openGalleryBottomBar: some View {
        Button {
            showSystemGallery = true
        } label: {
            HStack(spacing: 10) {
                if isImportingPhotos {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(isImportingPhotos ? "Adding photos…" : "Open Gallery")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(BabyTownTheme.accentGradient)
                    .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 12, y: 6)
            )
        }
        .disabled(isImportingPhotos)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .safeAreaPadding(.bottom, 12)
        .background {
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func reloadPhotos() {
        photos = PetGalleryPhotoLoader.loadAllPhotos()
        if let highlightedPhotoID,
           !photos.contains(where: { $0.id == highlightedPhotoID }) {
            self.highlightedPhotoID = photos.first?.id
        }
    }

    private func handleSystemGalleryPicks(_ results: [PHPickerResult]) async {
        guard !results.isEmpty else { return }
        isImportingPhotos = true
        defer { isImportingPhotos = false }

        let newMoments = await SelectPhotosViewModel().createMomentsFromPickerResults(results)
        guard !newMoments.isEmpty else { return }

        mergeMomentsIntoBabyTown(newMoments)
        reloadPhotos()

        if let newest = newMoments.sorted(by: { $0.dateTaken > $1.dateTaken }).first {
            highlightedPhotoID = newest.id
        }
    }

    private func mergeMomentsIntoBabyTown(_ newMoments: [Moment]) {
        var combined = DataPersistenceManager.shared.loadMoments() + newMoments

        var seen = Set<UUID>()
        combined = combined.filter { moment in
            if seen.contains(moment.id) { return false }
            seen.insert(moment.id)
            return true
        }

        combined.sort { $0.dateTaken > $1.dateTaken }
        DataPersistenceManager.shared.saveMoments(combined)
    }
}
