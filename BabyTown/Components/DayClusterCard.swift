import SwiftUI

struct DayClusterCard: View {

    let section: DaySection
    var onOpenPhoto: (Moment, [Moment]) -> Void
    var onEditCaption: ((UUID, String, String?) -> Void)? = nil
    var onRemove: ((DaySection) -> Void)? = nil
    var onTogglePin: ((DaySection) -> Void)? = nil
    var onAddPhotos: ((DaySection, [UIImage]) -> Void)? = nil
    var onRemovePhoto: ((DaySection, UUID) -> Void)? = nil
    var isLeftAligned: Bool = true
    
    @State private var showCaptionEditor = false
    @State private var showMenu = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack(alignment: isLeftAligned ? .trailing : .leading) {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                collageView
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .fill(BabyTownTheme.cardBackground.opacity(0.75))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
            )
            
            connectorNode
                .offset(x: isLeftAligned ? 12 : -12)
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
    
    private var connectorNode: some View {
        ZStack {
            Circle()
                .fill(BabyTownTheme.accent.opacity(0.2))
                .frame(width: 24, height: 24)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.6))
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                
                if let promptText = section.moments.first?.promptText, !promptText.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(BabyTownTheme.accent)
                        Text(promptText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(BabyTownTheme.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accent.opacity(0.1))
                    )
                }

                Text(locationText)
                    .font(.system(size: 12))
                    .foregroundStyle(.black)
                
                captionView
            }
            
            Spacer()
            
            Menu {
                Button {
                    onTogglePin?(section)
                } label: {
                    Label(isPinned ? "Unpin Memory" : "Pin Memory", systemImage: isPinned ? "pin.slash" : "pin")
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
        }
        .sheet(isPresented: $showCaptionEditor) {
            CaptionEditorSheet(
                section: section,
                onSave: { momentId, newCaption, voicePath in
                    onEditCaption?(momentId, newCaption, voicePath)
                },
                onAddPhotos: { images in
                    onAddPhotos?(section, images)
                },
                onRemovePhoto: { momentId in
                    onRemovePhoto?(section, momentId)
                }
            )
        }
        .confirmationDialog(
            "Remove this memory?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Memory", role: .destructive) {
                onRemove?(section)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private var locationText: String {
        if let placeName = section.moments.first?.placeName, !placeName.isEmpty {
            return "Near \(placeName)"
        }
        return "Near Unknown Location"
    }
    
    private var captionText: String {
        if let caption = section.moments.first?.caption, !caption.isEmpty {
            return caption
        }
        return "Add Love Note or Spunky Will Bite"
    }
    
    private var isPinned: Bool {
        section.moments.first?.isPinned ?? false
    }
    
    @ViewBuilder
    private var captionView: some View {
        let hasCaption = section.moments.first?.caption != nil && !(section.moments.first?.caption?.isEmpty ?? true)
        
        Button {
            showCaptionEditor = true
        } label: {
            if hasCaption {
                // State 2: Caption exists - show text with edit icon
                HStack(spacing: 0) {
                    Text(captionText)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.4))
                        .frame(width: 32, height: 32)
                }
            } else {
                // State 1: Empty - appealing generate prompt
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
        }
        .buttonStyle(.plain)
    }

    // MARK: - Collage

    @ViewBuilder
    private var collageView: some View {
        let photos = Array(section.moments.prefix(6))

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

    // 1 photo — full width
    private func singleLayout(_ moment: Moment) -> some View {
        photoButton(moment)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 2 photos — side by side
    private func twoLayout(_ moments: [Moment]) -> some View {
        HStack(spacing: 3) {
            photoButton(moments[0])
            photoButton(moments[1])
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 3 photos — hero top, two below
    private func threeLayout(_ moments: [Moment]) -> some View {
        VStack(spacing: 3) {
            photoButton(moments[0])
                .frame(height: 120)

            HStack(spacing: 3) {
                photoButton(moments[1])
                photoButton(moments[2])
            }
            .frame(height: 85)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 4-6 photos — balanced rows
    private func gridLayout(_ moments: [Moment]) -> some View {
        let topCount = (moments.count + 1) / 2
        let topRow = Array(moments.prefix(topCount))
        let bottomRow = Array(moments.suffix(moments.count - topCount))

        return VStack(spacing: 3) {
            HStack(spacing: 3) {
                ForEach(topRow) { photoButton($0) }
            }
            .frame(height: 95)

            if !bottomRow.isEmpty {
                HStack(spacing: 3) {
                    ForEach(bottomRow) { photoButton($0) }
                }
                .frame(height: 95)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Photo Button

    private func photoButton(_ moment: Moment) -> some View {
        Button {
            if !moment.isLocked {
                onOpenPhoto(moment, section.moments)
            }
        } label: {
            ZStack {
                Image(uiImage: moment.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .blur(radius: moment.isLocked ? 20 : 0)
                    .contentShape(Rectangle())
                
                if moment.isLocked {
                    Rectangle()
                        .fill(.black.opacity(0.4))
                    
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        if let unlockTime = moment.unlockTime {
                            TimeUntilUnlockView(unlockTime: unlockTime)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(moment.isLocked)
    }
}

#Preview {
    let sections = DaySection.grouped(from: Moment.sampleMoments)
    ScrollView {
        VStack(spacing: 20) {
            ForEach(sections) { section in
                DayClusterCard(section: section) { moment, all in
                    print("Open \(moment.id) from \(all.count)")
                }
            }
        }
        .padding(20)
    }
}
