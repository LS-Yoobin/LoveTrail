import SwiftUI
import Photos
import Combine

@MainActor
class ScanViewModel: ObservableObject {
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var potentialCards: [PotentialMemoryCard] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    var existingAssetIdentifiers: Set<String> = []
    
    private let photoScanService = PhotoScanService()
    private let clusteringService = PhotoClusteringService()
    private let photoSelector = BestPhotoSelector()
    private let locationResolver = LocationNameResolver()
    
    func checkPhotoPermission() async {
        authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
    
    func scanPhotosForYear(_ year: Int) async {
        isScanning = true
        scanProgress = 0.0
        potentialCards = []
        errorMessage = nil
        
        // Step 1: Fetch photos (30% of progress)
        let photos = await photoScanService.fetchPhotosForYear(year)
        scanProgress = 0.3
        
        guard !photos.isEmpty else {
            isScanning = false
            return
        }
        
        // Step 2: Cluster photos (50% of progress)
        let clusters = await clusteringService.clusterPhotos(photos)
        scanProgress = 0.5
        
        // Step 3: Process each cluster (50% to 100%)
        let progressPerCluster = 0.5 / Double(max(clusters.count, 1))
        
        for cluster in clusters {
            let card = await processCluster(cluster)
            potentialCards.append(card)
            scanProgress += progressPerCluster
        }
        
        scanProgress = 1.0
        isScanning = false
    }
    
    private func processCluster(_ cluster: PhotoCluster) async -> PotentialMemoryCard {
        // Select best photo
        guard let bestPhoto = await photoSelector.selectBestPhoto(from: cluster) else {
            fatalError("Cluster must have at least one photo")
        }
        
        // Select secondary photos
        let secondaryPhotos = await photoSelector.selectSecondaryPhotos(
            from: cluster,
            excluding: bestPhoto,
            limit: 3
        )
        
        // Load images
        let coverImage = await photoScanService.loadImage(for: bestPhoto.asset) ?? UIImage()
        let secondaryImages = await withTaskGroup(of: UIImage?.self) { group in
            for photo in secondaryPhotos {
                group.addTask {
                    await self.photoScanService.loadImage(
                        for: photo.asset,
                        targetSize: CGSize(width: 100, height: 100)
                    )
                }
            }
            
            var images: [UIImage] = []
            for await image in group {
                if let image = image {
                    images.append(image)
                }
            }
            return images
        }
        
        // Reverse geocode location
        let locationName = await locationResolver.reverseGeocode(cluster.centerCoordinate)
        
        // Create card
        return PotentialMemoryCard(
            id: UUID(),
            locationName: locationName,
            coordinate: cluster.centerCoordinate,
            dateRange: cluster.dateRange,
            photoCount: cluster.photos.count,
            coverPhoto: coverImage,
            secondaryThumbnails: secondaryImages,
            assetIdentifiers: cluster.photos.map { $0.asset.localIdentifier },
            isAdded: cluster.photos.contains { existingAssetIdentifiers.contains($0.asset.localIdentifier) }
        )
    }
    
    func addCardToHome(_ card: PotentialMemoryCard) async -> [Moment] {
        // Mark card as added
        if let index = potentialCards.firstIndex(where: { $0.id == card.id }) {
            potentialCards[index].isAdded = true
        }
        
        // Convert to Moments
        var moments: [Moment] = []
        
        for assetId in card.assetIdentifiers {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else { continue }
            
            if let image = await photoScanService.loadImage(for: asset),
               let creationDate = asset.creationDate {
                
                let moment = Moment(
                    id: UUID(),
                    dateTaken: creationDate,
                    assetIdentifier: assetId,
                    thumbnail: image,
                    placeName: card.locationName,
                    caption: nil,
                    voiceNotePath: nil,
                    promptText: nil,
                    isPinned: false,
                    pinnedAt: nil,
                    isLocked: false,
                    unlockTime: nil,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
                moments.append(moment)
            }
        }
        
        return moments
    }
}
