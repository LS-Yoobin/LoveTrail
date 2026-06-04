import SwiftUI

struct OnThisDayCard: View {
    let section: DaySection
    let yearsAgo: Int
    var isFullWidth: Bool = false
    let onTap: () -> Void
    
    private var previewPhotos: [Moment] {
        Array(section.moments.prefix(3))
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: section.date)
    }
    
    private var yearsAgoText: String {
        yearsAgo == 1 ? "1 year ago" : "\(yearsAgo) years ago"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("On this day")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text(yearsAgoText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text(dateString)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                // Photo collage
                if previewPhotos.count == 1 {
                    singlePhotoView
                } else if previewPhotos.count == 2 {
                    twoPhotosView
                } else if previewPhotos.count >= 3 {
                    threePhotosView
                }
                
                // Location
                Group {
                    if let formatted = section.formattedPlaceName {
                        PlaceNameLabel(
                            rawPlaceName: section.moments.first?.placeName,
                            isUserSet: section.isPlaceNameUserSet,
                            font: .system(size: 12, weight: .regular),
                            foregroundStyle: .white.opacity(0.8)
                        )
                    } else {
                        Text(section.placeDisplay)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: isFullWidth ? .infinity : 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                BabyTownTheme.accent,
                                BabyTownTheme.accentDeep
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var singlePhotoView: some View {
        Image(uiImage: previewPhotos[0].thumbnail)
            .resizable()
            .scaledToFill()
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var twoPhotosView: some View {
        HStack(spacing: 4) {
            Image(uiImage: previewPhotos[0].thumbnail)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Image(uiImage: previewPhotos[1].thumbnail)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var threePhotosView: some View {
        HStack(spacing: 4) {
            Image(uiImage: previewPhotos[0].thumbnail)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(spacing: 4) {
                Image(uiImage: previewPhotos[1].thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Image(uiImage: previewPhotos[2].thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(minWidth: 0, maxWidth: .infinity)
        }
    }
}
