import SwiftUI

struct PinnedMemoryCard: View {

    let item: PinnedItem
    var onTap: (() -> Void)? = nil
    var onUnpin: (() -> Void)? = nil
    
    @State private var showMenu = false
    @State private var currentPhotoIndex = 0
    @State private var slideshowTimer: Timer?

    private var slides: [PinnedSlide] {
        item.slides
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                photoArea
                textArea
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .fill(BabyTownTheme.cardBackground)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            
            Menu {
                Button(role: .destructive) {
                    onUnpin?()
                } label: {
                    Label("Unpin Memory", systemImage: "pin.slash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                    )
                    .contentShape(Rectangle())
            }
            .padding(8)
        }
        .onAppear {
            startSlideshow()
        }
        .onDisappear {
            stopSlideshow()
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoArea: some View {
        ZStack {
            if !slides.isEmpty {
                let currentSlide = slides[currentPhotoIndex % slides.count]
                
                Image(uiImage: currentSlide.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 150)
                    .blur(radius: currentSlide.isLocked ? 20 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .id(currentSlide.id) // Use ID for better transitions
                    .transition(.opacity)
                
                if currentSlide.isLocked {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.black.opacity(0.4))
                    
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        if let unlockTime = currentSlide.unlockTime {
                            TimeUntilUnlockView(unlockTime: unlockTime)
                        }
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 150)
            }
        }
        .frame(height: 150)
    }

    // MARK: - Text

    private var textArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = item.title {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(2)
            }
            
            Text(formattedDate)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                Text("Pinned")
                    .font(.system(size: 10))
            }
            .foregroundStyle(BabyTownTheme.accent.opacity(0.7))

            if let placeName = item.placeName {
                Text("Near \(placeName)")
                    .font(.system(size: 10))
                    .foregroundStyle(BabyTownTheme.textTertiary)
                    .lineLimit(1)
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: item.date)
    }
    
    // MARK: - Slideshow
    
    private func startSlideshow() {
        guard slides.count > 1 else { return }
        
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPhotoIndex = (currentPhotoIndex + 1) % slides.count
            }
        }
    }
    
    private func stopSlideshow() {
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
}

#Preview {
    let moments = Moment.sampleMoments
    let promptMemory = PromptMemory(
        promptText: "Our First Date",
        date: Date(),
        loveNote: "It was magical!",
        photos: [
            PromptPhoto(dateTaken: Date(), thumbnail: moments[0].thumbnail),
            PromptPhoto(dateTaken: Date(), thumbnail: moments[1].thumbnail)
        ],
        isPinned: true
    )
    
    return ScrollView(.horizontal) {
        HStack(spacing: 14) {
            PinnedMemoryCard(
                item: .moment(moments[0], Array(moments.prefix(3))),
                onUnpin: { print("Unpin") }
            )
            PinnedMemoryCard(
                item: .prompt(promptMemory),
                onUnpin: { print("Unpin") }
            )
        }
        .padding(20)
    }
}
