import SwiftUI

struct PromptMemoryCard: View {

    let memory: PromptMemory
    var onTap: () -> Void
    var onOpenPhoto: ((PromptPhoto, [PromptPhoto]) -> Void)? = nil
    var onRemove: ((PromptMemory) -> Void)? = nil
    var onEditLoveNote: ((UUID, String) -> Void)? = nil
    var onEditMemory: ((UUID, UUID, String, String?, Double?, Double?, Bool) -> Void)? = nil
    var onAddPhotos: ((UUID, [UIImage]) -> Void)? = nil
    var onRemovePhoto: ((UUID, UUID) -> Void)? = nil
    var onSyncMemoryPhotos: ((UUID, Set<String>, Set<UUID>) -> Void)? = nil
    var onTogglePin: ((PromptMemory) -> Void)? = nil
    var onShare: ((MemorySharePayload) -> Void)? = nil
    var isLeftAligned: Bool = true
    var index: Int = 0

    @State private var showDeleteConfirmation = false
    @State private var showCaptionEditor = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d • h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                headerSection
                promptTextSection
                ZStack(alignment: isLeftAligned ? .bottomTrailing : .bottomLeading) {
                    photoCollage
                    catDecoration
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                loveNoteSection
            }
            .padding(12)
            .padding(.trailing, 28)

            memoryMenu
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .fill(BabyTownTheme.cardBackground.opacity(0.75))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .strokeBorder(BabyTownTheme.accent.opacity(0.15), lineWidth: 1)
        )
        .confirmationDialog(
            "Remove this memory?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Memory", role: .destructive) {
                onRemove?(memory)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showCaptionEditor) {
            CaptionEditorSheet(
                section: memory.asEditingDaySection(),
                onSave: { photoId, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                    if let onEditMemory {
                        onEditMemory(
                            memory.id,
                            photoId,
                            caption,
                            placeName,
                            latitude,
                            longitude,
                            isPlaceNameUserSet
                        )
                    } else {
                        onEditLoveNote?(memory.id, caption)
                    }
                },
                onAddPhotos: { images in
                    onAddPhotos?(memory.id, images)
                },
                onRemovePhoto: { photoId in
                    onRemovePhoto?(memory.id, photoId)
                },
                onSyncMemoryPhotos: { assetIds, orphanIds in
                    onSyncMemoryPhotos?(memory.id, assetIds, orphanIds)
                }
            )
        }
    }
    
    private var catDecoration: some View {
        // Loop 1-5
        let variant = (index % 5) + 1
        return Image("cat_variant_\(variant)")
            .resizable()
            .scaledToFit()
            .frame(width: 110, height: 110)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .allowsHitTesting(false)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateFormatter.string(from: memory.date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)

            Text(locationText)
                .font(.system(size: 12))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memoryMenu: some View {
        Menu {
            Button {
                onShare?(MemorySharePayload(memory: memory))
            } label: {
                Label("Share Memory", systemImage: "square.and.arrow.up")
            }

            Button {
                onTogglePin?(memory)
            } label: {
                Label(memory.isPinned ? "Unpin Memory" : "Pin Memory", systemImage: memory.isPinned ? "pin.slash" : "pin")
            }

            Button {
                showCaptionEditor = true
            } label: {
                Label("Edit Memory", systemImage: "pencil")
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Remove Memory", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private var locationText: String {
        if let placeName = memory.placeName, !placeName.isEmpty {
            return "Near \(placeName)"
        }
        return "No location data"
    }
    
    // MARK: - Love Note Section
    
    @ViewBuilder
    private var loveNoteSection: some View {
        let hasLoveNote = !memory.loveNote.isEmpty
        
        if hasLoveNote {
            Text(memory.loveNote)
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.8))
                .lineLimit(2)
                .padding(.vertical, 4)
        } else {
            Button {
                showCaptionEditor = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accent)

                    Text("Generate Love Note")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BabyTownTheme.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(BabyTownTheme.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(BabyTownTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Prompt Text Section
    
    private var promptTextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.accent)

                Text("Prompt Memory")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .textCase(.uppercase)
            }

            Text(memory.promptText)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(3)
        }
    }
    
    // MARK: - Photo Collage
    
    @ViewBuilder
    private var photoCollage: some View {
        let photos = Array(memory.photos.prefix(6))
        
        switch photos.count {
        case 1:
            singleLayout(photos[0])
        case 2:
            twoLayout(photos)
        case 3:
            threeLayout(photos)
        default:
            gridLayout(photos)
        }
    }
    
    private func singleLayout(_ photo: PromptPhoto) -> some View {
        Button {
            if !isPhotoLocked(photo) {
                onOpenPhoto?(photo, memory.photos)
            }
        } label: {
            ZStack {
                Image(uiImage: photo.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .blur(radius: isPhotoLocked(photo) ? 20 : 0)
                
                if isPhotoLocked(photo) {
                    lockOverlay
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isPhotoLocked(photo))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func twoLayout(_ photos: [PromptPhoto]) -> some View {
        HStack(spacing: 3) {
            ForEach(photos) { photo in
                Button {
                    if !isPhotoLocked(photo) {
                        onOpenPhoto?(photo, memory.photos)
                    }
                } label: {
                    ZStack {
                        Image(uiImage: photo.thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .blur(radius: isPhotoLocked(photo) ? 20 : 0)
                        
                        if isPhotoLocked(photo) {
                            lockOverlay
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPhotoLocked(photo))
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func threeLayout(_ photos: [PromptPhoto]) -> some View {
        VStack(spacing: 3) {
            Button {
                if !isPhotoLocked(photos[0]) {
                    onOpenPhoto?(photos[0], memory.photos)
                }
            } label: {
                ZStack {
                    Image(uiImage: photos[0].thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .blur(radius: isPhotoLocked(photos[0]) ? 20 : 0)
                    
                    if isPhotoLocked(photos[0]) {
                        lockOverlay
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isPhotoLocked(photos[0]))
            
            HStack(spacing: 3) {
                Button {
                    if !isPhotoLocked(photos[1]) {
                        onOpenPhoto?(photos[1], memory.photos)
                    }
                } label: {
                    ZStack {
                        Image(uiImage: photos[1].thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .blur(radius: isPhotoLocked(photos[1]) ? 20 : 0)
                        
                        if isPhotoLocked(photos[1]) {
                            lockOverlay
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPhotoLocked(photos[1]))
                
                Button {
                    if !isPhotoLocked(photos[2]) {
                        onOpenPhoto?(photos[2], memory.photos)
                    }
                } label: {
                    ZStack {
                        Image(uiImage: photos[2].thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .blur(radius: isPhotoLocked(photos[2]) ? 20 : 0)
                        
                        if isPhotoLocked(photos[2]) {
                            lockOverlay
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPhotoLocked(photos[2]))
            }
            .frame(height: 75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func gridLayout(_ photos: [PromptPhoto]) -> some View {
        let topCount = (photos.count + 1) / 2
        let topRow = Array(photos.prefix(topCount))
        let bottomRow = Array(photos.suffix(photos.count - topCount))
        
        return VStack(spacing: 3) {
            HStack(spacing: 3) {
                ForEach(topRow) { photo in
                    Button {
                        if !isPhotoLocked(photo) {
                            onOpenPhoto?(photo, memory.photos)
                        }
                    } label: {
                        ZStack {
                            Image(uiImage: photo.thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .blur(radius: isPhotoLocked(photo) ? 20 : 0)
                            
                            if isPhotoLocked(photo) {
                                lockOverlay
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isPhotoLocked(photo))
                }
            }
            .frame(height: 80)
            
            if !bottomRow.isEmpty {
                HStack(spacing: 3) {
                    ForEach(bottomRow) { photo in
                        Button {
                            if !isPhotoLocked(photo) {
                                onOpenPhoto?(photo, memory.photos)
                            }
                        } label: {
                            ZStack {
                                Image(uiImage: photo.thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .blur(radius: isPhotoLocked(photo) ? 20 : 0)
                                
                                if isPhotoLocked(photo) {
                                    lockOverlay
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isPhotoLocked(photo))
                    }
                }
                .frame(height: 80)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Helpers
    
    private func isPhotoLocked(_ photo: PromptPhoto) -> Bool {
        guard photo.isFromCamera, let unlockTime = photo.unlockTime else {
            return false
        }
        return Date() < unlockTime
    }
    
    private var lockOverlay: some View {
        VStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Locked")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.6))
        )
    }
}
