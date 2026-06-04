import SwiftUI

struct ImportantDatePhotoViewerContext {
    let title: String
    let date: Date
    let image: UIImage
}

/// Full-screen viewer for an important-date photo (foundational or special).
struct ImportantDatePhotoViewer: View {
    let title: String
    let date: Date
    let image: UIImage
    var onDismiss: () -> Void

    @State private var showChrome = true
    @StateObject private var shareCoordinator = MemoryShareCoordinator()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: handlePhotoTap)

            viewerChromeOverlay
        }
        .statusBarHidden(true)
        .memorySharePresentation(coordinator: shareCoordinator)
    }

    private func handlePhotoTap() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showChrome.toggle()
        }
    }

    private var viewerChromeOverlay: some View {
        VStack(spacing: 0) {
            topBar
                .allowsHitTesting(showChrome)

            Spacer()
                .allowsHitTesting(false)

            viewerChromeBottom
                .allowsHitTesting(showChrome)
        }
        .opacity(showChrome ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showChrome)
        .allowsHitTesting(showChrome)
        .background(alignment: .top) {
            if showChrome {
                PhotoViewerTopScrim()
            }
        }
        .background(alignment: .bottom) {
            if showChrome {
                photoViewerBottomGradient
            }
        }
    }

    private var topBar: some View {
        HStack {
            CircleBackdropCloseButton(action: onDismiss)

            Spacer()

            Button(action: sharePhoto) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }

    private var viewerChromeBottom: some View {
        VStack(spacing: 0) {
            PromptDisplayCard(prompt: title)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            photoMetadataDisplay
                .padding(.bottom, 8)
        }
    }

    private var photoMetadataDisplay: some View {
        HStack {
            Text(dateFormatter.string(from: date))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .photoViewerLegibleText()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(photoViewerMetadataBackground)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
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
        .frame(height: 200)
        .allowsHitTesting(false)
    }

    private func sharePhoto() {
        let payload = MemorySharePayload(
            date: date,
            placeName: nil,
            isPlaceNameUserSet: false,
            promptText: title,
            loveNote: nil,
            photoSources: [
                MemorySharePhotoSource(
                    id: UUID(),
                    thumbnail: image,
                    assetIdentifier: nil,
                    isLocked: false
                )
            ]
        )
        shareCoordinator.share(payload)
    }
}

private extension View {
    func photoViewerLegibleText() -> some View {
        self
            .shadow(color: .black.opacity(0.95), radius: 0, x: 0, y: 0.5)
            .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 3)
    }
}
