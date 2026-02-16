import UIKit
import CoreLocation
import Photos


struct PotentialMemoryCard: Identifiable {
    let id: UUID
    let locationName: String
    let coordinate: CLLocationCoordinate2D
    let dateRange: DateInterval
    let photoCount: Int
    let coverPhoto: UIImage
    let secondaryThumbnails: [UIImage]
    let assetIdentifiers: [String]
    var isAdded: Bool
    
    init(
        id: UUID = UUID(),
        locationName: String,
        coordinate: CLLocationCoordinate2D,
        dateRange: DateInterval,
        photoCount: Int,
        coverPhoto: UIImage,
        secondaryThumbnails: [UIImage] = [],
        assetIdentifiers: [String],
        isAdded: Bool = false
    ) {
        self.id = id
        self.locationName = locationName
        self.coordinate = coordinate
        self.dateRange = dateRange
        self.photoCount = photoCount
        self.coverPhoto = coverPhoto
        self.secondaryThumbnails = secondaryThumbnails
        self.assetIdentifiers = assetIdentifiers
        self.isAdded = isAdded
    }
    
    var dateRangeDisplay: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startDay = calendar.startOfDay(for: dateRange.start)
        let endDay = calendar.startOfDay(for: dateRange.end)
        
        if startDay == endDay {
            // Single day
            return formatter.string(from: dateRange.start)
        } else {
            // Date range
            let startStr = formatter.string(from: dateRange.start)
            formatter.dateFormat = "d"
            let endStr = formatter.string(from: dateRange.end)
            return "\(startStr)–\(endStr)"
        }
    }
}

struct PhotoMetadata {
    let asset: PHAsset
    let coordinate: CLLocationCoordinate2D
    let creationDate: Date
    let pixelWidth: Int
    let pixelHeight: Int
}

struct PhotoCluster {
    var photos: [PhotoMetadata]
    var centerCoordinate: CLLocationCoordinate2D
    var dateRange: DateInterval
    
    var firstPhoto: PhotoMetadata? { photos.first }
    var lastPhoto: PhotoMetadata? { photos.last }
}
