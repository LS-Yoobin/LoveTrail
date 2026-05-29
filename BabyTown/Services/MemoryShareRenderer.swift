import Photos
import SwiftUI
import UIKit

enum MemoryShareImageLoader {

    private static let imageManager = PHImageManager.default()
    private static let targetSize = CGSize(width: 2000, height: 2000)

    static func loadImages(for sources: [MemorySharePhotoSource]) async -> [UIImage] {
        var results: [UIImage] = []
        for source in sources {
            if let image = await loadImage(for: source) {
                results.append(image)
            }
        }
        return results
    }

    private static func loadImage(for source: MemorySharePhotoSource) async -> UIImage? {
        if let assetId = source.assetIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = fetchResult.firstObject,
               let full = await requestFullImage(for: asset) {
                return full
            }
        }
        return source.thumbnail
    }

    private static func requestFullImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded, !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
}

enum MemoryShareRenderer {

    @MainActor
    static func render(payload: MemorySharePayload, images: [UIImage]) -> UIImage? {
        let view = MemoryShareCardView(payload: payload, images: images)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(
            width: MemoryShareCardView.exportSize.width,
            height: MemoryShareCardView.exportSize.height
        )
        return renderer.uiImage
    }
}
