import Foundation
import UIKit
import Photos
import CoreLocation
import MapKit

@MainActor
final class MomentFactory {
    
    private let imageManager = PHCachingImageManager()
    
    func createMoments(from assets: [PHAsset]) async -> [Moment] {
        var moments: [Moment] = []
        
        for asset in assets {
            if let moment = await createMoment(from: asset) {
                moments.append(moment)
            }
        }
        
        return moments
    }
    
    private func createMoment(from asset: PHAsset) async -> Moment? {
        guard let thumbnail = await loadThumbnail(for: asset) else {
            return nil
        }
        
        let dateTaken = asset.creationDate ?? Date()
        let placeName = await extractPlaceName(from: asset)
        
        return Moment(
            id: UUID(),
            dateTaken: dateTaken,
            assetIdentifier: asset.localIdentifier,
            thumbnail: thumbnail,
            placeName: placeName
        )
    }
    
    private func extractPlaceName(from asset: PHAsset) async -> String? {
        guard let location = asset.location else {
            return nil
        }
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "location"
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 100,
            longitudinalMeters: 100
        )
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            if let mapItem = response.mapItems.first {
                return mapItem.name 
                    ?? mapItem.placemark.locality 
                    ?? mapItem.placemark.subLocality 
                    ?? mapItem.placemark.administrativeArea
            }
            return nil
        } catch {
            print("Reverse geocoding failed: \(error)")
            return nil
        }
    }
    
    private func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let size = CGSize(width: 400, height: 400)
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
