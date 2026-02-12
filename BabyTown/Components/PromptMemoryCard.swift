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
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                BabyTownTheme.accentSoft.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: BabyTownTheme.cardShadow, radius: 8, y: 4)
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
            
            Text(memory.promptText)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(.black)
                .lineLimit(2)
            
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
        Image(uiImage: photo.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func twoLayout(_ photos: [PromptPhoto]) -> some View {
        HStack(spacing: 3) {
            ForEach(photos) { photo in
                Image(uiImage: photo.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func threeLayout(_ photos: [PromptPhoto]) -> some View {
        VStack(spacing: 3) {
            Image(uiImage: photos[0].thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 100)
            
            HStack(spacing: 3) {
                Image(uiImage: photos[1].thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                
                Image(uiImage: photos[2].thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
                    Image(uiImage: photo.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
            
            if !bottomRow.isEmpty {
                HStack(spacing: 3) {
                    ForEach(bottomRow) { photo in
                        Image(uiImage: photo.thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 80)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
