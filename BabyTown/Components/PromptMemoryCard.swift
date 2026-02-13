import SwiftUI

struct PromptMemoryCard: View {
    
    let memory: PromptMemory
    var onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                headerSection
                loveNotePreview
                photoCollage
                promptTextSection
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .fill(BabyTownTheme.cardBackground.opacity(0.75))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .strokeBorder(BabyTownTheme.accent.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.accent)
                
                Text("Prompt Memory")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .textCase(.uppercase)
            }
            
            HStack(spacing: 4) {
                Text(dateFormatter.string(from: memory.date))
                    .font(.system(size: 12))
                    .foregroundStyle(.black)
                
                if let place = memory.placeName {
                    Text("•")
                        .foregroundStyle(.black.opacity(0.5))
                    Text("Near \(place)")
                        .font(.system(size: 12))
                        .foregroundStyle(.black)
                }
            }
        }
    }
    
    // MARK: - Love Note Preview
    
    private var loveNotePreview: some View {
        Text(memory.loveNote)
            .font(.system(size: 13))
            .foregroundStyle(.black.opacity(0.8))
            .lineLimit(2)
            .padding(.vertical, 4)
    }
    
    // MARK: - Prompt Text Section
    
    private var promptTextSection: some View {
        Text(memory.promptText)
            .font(.system(size: 14, weight: .medium, design: .serif))
            .foregroundStyle(.black.opacity(0.85))
            .lineLimit(3)
            .padding(.top, 4)
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
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func twoLayout(_ photos: [PromptPhoto]) -> some View {
        HStack(spacing: 3) {
            ForEach(photos) { photo in
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
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func threeLayout(_ photos: [PromptPhoto]) -> some View {
        VStack(spacing: 3) {
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
            
            HStack(spacing: 3) {
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
            }
            .frame(height: 80)
            
            if !bottomRow.isEmpty {
                HStack(spacing: 3) {
                    ForEach(bottomRow) { photo in
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
