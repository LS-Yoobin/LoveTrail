import SwiftUI

struct MemoryBottomSheet: View {
    let section: DaySection
    let onOpenMemory: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    private static let openMemoryDragThreshold: CGFloat = 72
    private static let dismissDragThreshold: CGFloat = 100

    private var coverPhoto: UIImage {
        section.moments.first?.thumbnail ?? UIImage(systemName: "photo")!
    }
    
    private var photoCount: Int {
        section.moments.count
    }
    
    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: section.date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            HStack(spacing: 16) {
                // Cover photo
                Image(uiImage: coverPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Memory details
                VStack(alignment: .leading, spacing: 6) {
                    Group {
                        if let formatted = section.formattedPlaceName {
                            PlaceNameLabel(
                                rawPlaceName: section.moments.first?.placeName,
                                isUserSet: section.isPlaceNameUserSet,
                                font: .system(size: 18, weight: .semibold),
                                foregroundStyle: BabyTownTheme.textPrimary,
                                iconSize: 14,
                                spacing: 5
                            )
                        } else {
                            Text("Memory")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(BabyTownTheme.textPrimary)
                        }
                    }
                    .lineLimit(1)
                    
                    Text(dateRange)
                        .font(.system(size: 14))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.6))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 12))
                        Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(BabyTownTheme.accent)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Open Memory button
            Button(action: onOpenMemory) {
                Text("Open Memory")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(BabyTownTheme.accentGradient)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .safeAreaPadding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            Color.white
                .ignoresSafeArea(edges: .bottom)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                topTrailingRadius: 20
            )
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        .offset(y: dragOffset)
        .gesture(dragGesture)
        .ignoresSafeArea(edges: .bottom)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                if value.translation.height < -Self.openMemoryDragThreshold {
                    onOpenMemory()
                } else if value.translation.height > Self.dismissDragThreshold {
                    onDismiss()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    dragOffset = 0
                }
            }
    }
}

#Preview {
    let sampleMoment = Moment(
        id: UUID(),
        dateTaken: Date(),
        thumbnail: UIImage(systemName: "photo")!,
        placeName: "Santa Cruz Beach",
        dateAddedToApp: Date()
    )
    
    let sampleSection = DaySection(
        date: Date(),
        placeName: "Santa Cruz Beach",
        moments: [sampleMoment, sampleMoment, sampleMoment]
    )
    
    return MemoryBottomSheet(
        section: sampleSection,
        onOpenMemory: { print("Open memory") },
        onDismiss: { print("Dismiss") }
    )
    .background(Color.gray.opacity(0.3))
}
