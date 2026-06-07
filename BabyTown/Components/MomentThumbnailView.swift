import SwiftUI

/// Async, downsampled thumbnail for the home feed. Loads from `ThumbnailStore` off the main
/// thread so scrolling never decodes on the main thread, and reuses cached results instantly
/// (no placeholder flash on re-appearance). Resets cleanly when `id` changes so reused cells
/// never show a stale photo.
struct MomentThumbnailView: View {

    let id: UUID
    var maxPixel: CGFloat = 700
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var loadedId: UUID?

    var body: some View {
        Group {
            if let image, loadedId == id {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(BabyTownTheme.accentSoft)
            }
        }
        .task(id: id) {
            if image != nil, loadedId == id { return }

            let targetId = id
            let target = maxPixel
            let loaded: UIImage? = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(
                        returning: ThumbnailStore.shared.downsampledImage(for: targetId, maxPixel: target)
                    )
                }
            }

            guard !Task.isCancelled else { return }
            image = loaded
            loadedId = loaded != nil ? targetId : nil
        }
    }
}
