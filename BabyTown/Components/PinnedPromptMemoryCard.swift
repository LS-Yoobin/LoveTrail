import SwiftUI

struct PinnedPromptMemoryCard: View {

    let memory: PromptMemory
    var onTap: (() -> Void)? = nil
    var onUnpin: (() -> Void)? = nil
    var onShare: ((MemorySharePayload) -> Void)? = nil
    
    @State private var currentPhotoIndex = 0
    @State private var slideshowTimer: Timer?

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
                Button {
                    onShare?(MemorySharePayload(memory: memory))
                } label: {
                    Label("Share Memory", systemImage: "square.and.arrow.up")
                }

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
            .offset(x: -5, y: 5)
        }
        .onAppear {
            startSlideshow()
        }
        .onDisappear {
            stopSlideshow()
        }
    }

    // MARK: - Photo Area

    @ViewBuilder
    private var photoArea: some View {
        ZStack {
            if !memory.photos.isEmpty {
                let activeIndex = currentPhotoIndex % memory.photos.count
                let currentPhoto = memory.photos[activeIndex]

                Image(uiImage: currentPhoto.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 150)
                    .blur(radius: isPhotoLocked(currentPhoto) ? 20 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .animation(nil, value: activeIndex)

                if isPhotoLocked(currentPhoto) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.black.opacity(0.4))
                    
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        if let unlockTime = currentPhoto.unlockTime {
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
        .animation(nil, value: currentPhotoIndex)
    }

    // MARK: - Text Area

    private var textArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memory.promptText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .lineLimit(2)
            
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

            if let placeName = memory.placeName, !placeName.isEmpty {
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
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: memory.date)
    }
    
    private func isPhotoLocked(_ photo: PromptPhoto) -> Bool {
        guard photo.isFromCamera, let unlockTime = photo.unlockTime else {
            return false
        }
        return Date() < unlockTime
    }

    // MARK: - Slideshow
    
    private func startSlideshow() {
        guard memory.photos.count > 1 else { return }
        
        let timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPhotoIndex = (currentPhotoIndex + 1) % memory.photos.count
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        slideshowTimer = timer
    }
    
    private func stopSlideshow() {
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
}
