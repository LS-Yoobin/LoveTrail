import Photos
import CoreLocation
import UIKit

class PhotoScanService {
    
    func fetchPhotosForYear(_ year: Int) async -> [PhotoMetadata] {
        // Request authorization if needed
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized else { return [] }
        
        // Create date range for the year
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        
        let startDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        
        // Fetch options
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@ AND mediaType == %d",
            startDate as NSDate,
            endDate as NSDate,
            PHAssetMediaType.image.rawValue
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        // Fetch assets
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        // Filter and extract metadata
        var photoMetadata: [PhotoMetadata] = []
        
        assets.enumerateObjects { asset, _, _ in
            // Filter out screenshots
            guard !asset.mediaSubtypes.contains(.photoScreenshot) else { return }
            
            // Filter out photos without location
            guard let location = asset.location else { return }
            
            // Filter out photos without creation date
            guard let creationDate = asset.creationDate else { return }
            
            let metadata = PhotoMetadata(
                asset: asset,
                coordinate: location.coordinate,
                creationDate: creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight
            )
            photoMetadata.append(metadata)
        }
        
        return photoMetadata
    }
    
    func loadImage(for asset: PHAsset, targetSize: CGSize = CGSize(width: 300, height: 300)) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
