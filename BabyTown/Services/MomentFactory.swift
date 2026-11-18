import Foundation
import UIKit
import Photos

@MainActor
final class MomentFactory {

    private let imageManager = PHCachingImageManager()
    private let locationResolver = LocationNameResolver.shared

    func createMoments(from assets: [PHAsset]) async -> [Moment] {
        // Step 1: Load all thumbnails concurrently
        let thumbnailResults: [(Int, UIImage)] = await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    let thumb = await self.loadThumbnail(for: asset)
                    return (index, thumb)
                }
            }
            var results: [(Int, UIImage)] = []
            for await (index, image) in group {
                if let image {
                    results.append((index, image))
                }
            }
            return results
        }

        // Step 2: Resolve locations (cached, so duplicates are instant)
        var moments: [Moment] = []
        for (index, thumbnail) in thumbnailResults.sorted(by: { $0.0 < $1.0 }) {
            let asset = assets[index]
            let dateTaken = asset.creationDate ?? Date()

            // Extract location coordinates from asset
            let latitude = asset.location?.coordinate.latitude
            let longitude = asset.location?.coordinate.longitude

            var placeName: String? = nil
            var country: String? = nil
            if let location = asset.location {
                let details = await locationResolver.resolveNameAndCountry(from: location)
                placeName = details.name
                country = details.country
            }

            moments.append(Moment(
                id: UUID(),
                dateTaken: dateTaken,
                assetIdentifier: asset.localIdentifier,
                thumbnail: thumbnail,
                placeName: placeName,
                latitude: latitude,
                longitude: longitude,
                country: country,
                dateAddedToApp: Date()
            ))
        }

        return moments
    }

    private func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let size = CGSize(width: 400, height: 400)
            let options = PHImageRequestOptions()
            // `.highQualityFormat` delivers a single final callback, so the continuation
            // is resumed exactly once (`.opportunistic` can fire twice → EXC_BAD_ACCESS).
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            var hasResumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                guard !isDegraded else { return }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: isCancelled ? nil : image)
            }
        }
    }
}
