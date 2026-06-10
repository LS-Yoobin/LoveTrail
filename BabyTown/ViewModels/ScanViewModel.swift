import SwiftUI
import Photos
import Combine

@MainActor
class ScanViewModel: ObservableObject {
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @Published var potentialCards: [PotentialMemoryCard] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var processedClusterCount: Int = 0
    @Published var totalClusterCount: Int = 0
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    var existingAssetIdentifiers: Set<String> = []

    var availableMonths: [Int] {
        let calendar = Calendar.current
        let months = Set(potentialCards.map { calendar.component(.month, from: $0.dateRange.start) })
        return months.sorted()
    }

    var filteredPotentialCards: [PotentialMemoryCard] {
        let calendar = Calendar.current
        return potentialCards.filter {
            calendar.component(.month, from: $0.dateRange.start) == selectedMonth
        }
    }
    
    private let photoScanService = PhotoScanService()
    private let clusteringService = PhotoClusteringService()
    private let photoSelector = BestPhotoSelector()
    private let locationResolver = LocationNameResolver.shared
    private var scanTask: Task<Void, Never>?
    
    func checkPhotoPermission() async {
        authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
    
    func scanPhotosForYear(_ year: Int) {
        scanTask?.cancel()
        scanTask = Task {
            await performScan(for: year)
        }
    }
    
    private func performScan(for year: Int) async {
        isScanning = true
        scanProgress = 0.0
        processedClusterCount = 0
        totalClusterCount = 0
        potentialCards = []
        errorMessage = nil
        
        // Step 1: Fetch photos
        let photos = await photoScanService.fetchPhotosForYear(year)
        guard !Task.isCancelled else { return finishScan() }
        scanProgress = 0.15
        
        guard !photos.isEmpty else {
            finishScan()
            return
        }
        
        // Step 2: Cluster photos into location/time groups
        let clusters = await clusteringService.clusterPhotos(photos)
        guard !Task.isCancelled else { return finishScan() }
        scanProgress = 0.2
        
        guard !clusters.isEmpty else {
            finishScan()
            return
        }

        let sortedClusters = clusters.sorted { lhs, rhs in
            if lhs.dateRange.start != rhs.dateRange.start {
                return lhs.dateRange.start < rhs.dateRange.start
            }
            return lhs.dateRange.end < rhs.dateRange.end
        }
        totalClusterCount = sortedClusters.count

        // Step 3: Process each photo group progressively — one geocode lookup per group (cache-backed)
        for (index, cluster) in sortedClusters.enumerated() {
            guard !Task.isCancelled else { break }

            let card = await processCluster(cluster)
            potentialCards.append(card)
            processedClusterCount = index + 1
            scanProgress = 0.2 + (0.8 * Double(processedClusterCount) / Double(totalClusterCount))

            if potentialCards.count == 1 {
                syncSelectedMonthAfterFirstCard(card)
            }
        }

        finishScan()
    }

    private func finishScan() {
        scanProgress = 1.0
        isScanning = false
    }

    private func syncSelectedMonthAfterFirstCard(_ card: PotentialMemoryCard) {
        let calendar = Calendar.current
        selectedMonth = calendar.component(.month, from: card.dateRange.start)
    }
    
    private func processCluster(_ cluster: PhotoCluster) async -> PotentialMemoryCard {
        guard let bestPhoto = await photoSelector.selectBestPhoto(from: cluster) else {
            fatalError("Cluster must have at least one photo")
        }

        async let coverImage = photoScanService.loadImage(for: bestPhoto.asset)
        async let locationName = locationResolver.placeName(for: cluster.centerCoordinate)

        return PotentialMemoryCard(
            id: UUID(),
            locationName: await locationName,
            coordinate: cluster.centerCoordinate,
            dateRange: cluster.dateRange,
            photoCount: cluster.photos.count,
            coverPhoto: await coverImage ?? UIImage(),
            secondaryThumbnails: [],
            assetIdentifiers: cluster.photos.map { $0.asset.localIdentifier },
            coverAssetIdentifier: bestPhoto.asset.localIdentifier,
            isAdded: cluster.photos.contains { existingAssetIdentifiers.contains($0.asset.localIdentifier) }
        )
    }

    func addCardToHome(_ card: PotentialMemoryCard) async -> [Moment] {
        if let index = potentialCards.firstIndex(where: { $0.id == card.id }) {
            potentialCards[index].isAdded = true
        }
        
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
