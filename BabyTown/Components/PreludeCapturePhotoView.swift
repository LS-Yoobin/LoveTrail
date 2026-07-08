import SwiftUI

/// Displays a prelude capture photo, loading from local storage or covela-fs when needed.
struct PreludeCapturePhotoView: View {
    let capture: PreludeCapture
    var height: CGFloat = 150
    var cornerRadius: CGFloat = 12

    @State private var image: UIImage?
    @State private var isLoading = true
    #if DEBUG
    @AppStorage("debugPreludePhotoLoadSource") private var debugPhotoLoadSource = PreludePhotoLoader.PhotoLoadSource.localFirst.rawValue
    #endif

    private var hasPhotoSource: Bool {
        capture.firstPhotoId != nil || capture.notePhotoId != nil || capture.remotePhotoPath != nil
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else if isLoading && hasPhotoSource {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BabyTownTheme.accent.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .overlay { ProgressView() }
            } else if hasPhotoSource {
                Image(systemName: capture.typeIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(BabyTownTheme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            }
        }
        .task(id: loadKey) {
            isLoading = true
            image = await PreludePhotoLoader.loadImage(for: capture)
            isLoading = false
        }
    }

    private var loadKey: String {
        var parts = [
            capture.id.uuidString,
            capture.firstPhotoId?.uuidString,
            capture.notePhotoId?.uuidString,
            capture.remotePhotoPath,
        ]
        #if DEBUG
        parts.append(debugPhotoLoadSource)
        #endif
        return parts.compactMap { $0 }.joined(separator: "|")
    }
}
