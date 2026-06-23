import Foundation
import Combine
import Photos
import PhotosUI
import CoreLocation
import UIKit

@MainActor
final class MemoryMomentPhotoGalleryViewModel: ObservableObject {

    @Published var assets: [PHAsset] = []
    @Published var thumbnails: [String: UIImage] = [:]
    @Published var selectedAssetIds: Set<String> = []
    @Published var selectedOrphanMomentIds: Set<UUID> = []
    @Published var orphanMoments: [Moment] = []
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    let imageManager = PHCachingImageManager()

    private let timePadding: TimeInterval = 6 * 3600
    private let distanceThreshold: CLLocationDistance = 300

    func prepare(from section: DaySection) {
        selectedAssetIds = Set(section.moments.compactMap(\.assetIdentifier))
        orphanMoments = section.moments.filter { $0.assetIdentifier == nil }
        selectedOrphanMomentIds = Set(orphanMoments.map(\.id))
    }

    func checkAuthorizationAndLoad(for section: DaySection) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            authorizationStatus = status
        }

        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            assets = []
            return
        }

        await loadPhotos(for: section)
    }

    func loadPhotos(for section: DaySection) async {
        isLoading = true
        imageManager.stopCachingImagesForAllAssets()
        thumbnails = [:]

        await Task.yield()

        assets = fetchAssets(for: section)
        isLoading = false
        prefetchThumbnails(for: assets)
    }

    func loadThumbnail(for asset: PHAsset) {
        let id = asset.localIdentifier
        guard thumbnails[id] == nil else { return }

        let size = CGSize(width: 200, height: 200)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: opts
        ) { [weak self] image, _ in
            guard let image else { return }
            Task { @MainActor in
                self?.storeThumbnail(image, for: id)
            }
        }
    }

    private func prefetchThumbnails(for assets: [PHAsset]) {
        for asset in assets {
            loadThumbnail(for: asset)
        }
    }

    private func storeThumbnail(_ image: UIImage, for id: String) {
        guard thumbnails[id] == nil else { return }
        var updated = thumbnails
        updated[id] = image
        thumbnails = updated
    }

    func toggleSelection(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedAssetIds.contains(id) {
            selectedAssetIds.remove(id)
        } else {
            selectedAssetIds.insert(id)
        }
    }

    func toggleOrphanMoment(_ moment: Moment) {
        if selectedOrphanMomentIds.contains(moment.id) {
            selectedOrphanMomentIds.remove(moment.id)
        } else {
            selectedOrphanMomentIds.insert(moment.id)
        }
    }

    func removeMomentFromEditingSelection(_ moment: Moment) {
        if let assetId = moment.assetIdentifier {
            selectedAssetIds.remove(assetId)
        } else {
            selectedOrphanMomentIds.remove(moment.id)
            orphanMoments.removeAll { $0.id == moment.id }
        }
    }

    func incorporatePickerResults(_ results: [PHPickerResult], from section: DaySection) async {
        guard !results.isEmpty else { return }
        guard let template = section.moments.first else { return }

        var newlyAdded: [PHAsset] = []
        for result in results {
            if let id = result.assetIdentifier {
                let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if let asset = fetched.firstObject {
                    selectedAssetIds.insert(id)
                    if !assets.contains(where: { $0.localIdentifier == id }) {
                        assets.append(asset)
                        newlyAdded.append(asset)
                    }
                    continue
                }
            }

            guard let image = await loadImage(from: result.itemProvider) else { continue }
            let moment = Moment(
                id: UUID(),
                dateTaken: Date(),
                assetIdentifier: nil,
                thumbnail: image,
                placeName: template.placeName,
                caption: template.caption,
                voiceNotePath: template.voiceNotePath,
                promptText: template.promptText,
                isPinned: template.isPinned,
                pinnedAt: template.pinnedAt,
                isLocked: template.isLocked,
                unlockTime: template.unlockTime,
                latitude: template.latitude,
                longitude: template.longitude,
                isPlaceNameUserSet: template.isPlaceNameUserSet,
                country: template.country,
                dateAddedToApp: Date()
            )
            orphanMoments.append(moment)
            selectedOrphanMomentIds.insert(moment.id)
        }

        if !newlyAdded.isEmpty {
            assets.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            prefetchThumbnails(for: newlyAdded)
        }
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    var selectedCount: Int {
        selectedAssetIds.count + selectedOrphanMomentIds.count
    }

    /// Moments to show on the Edit Memory screen while the sheet is open (before Save).
    func previewMoments(from section: DaySection) -> [Moment] {
        guard let template = section.moments.first else { return [] }

        var result: [Moment] = []

        for moment in section.moments {
            if let assetId = moment.assetIdentifier {
                if selectedAssetIds.contains(assetId) {
                    result.append(moment)
                }
            } else if selectedOrphanMomentIds.contains(moment.id) {
                result.append(moment)
            }
        }

        let existingAssetIds = Set(section.moments.compactMap(\.assetIdentifier))
        let addedAssetIds = selectedAssetIds.subtracting(existingAssetIds)

        for asset in assets where addedAssetIds.contains(asset.localIdentifier) {
            let thumb = thumbnails[asset.localIdentifier] ?? Moment.placeholder(.systemGray5)
            result.append(
                Moment(
                    id: UUID(),
                    dateTaken: asset.creationDate ?? template.dateTaken,
                    assetIdentifier: asset.localIdentifier,
                    thumbnail: thumb,
                    placeName: template.placeName,
                    caption: template.caption,
                    voiceNotePath: template.voiceNotePath,
                    promptText: template.promptText,
                    isPinned: template.isPinned,
                    pinnedAt: template.pinnedAt,
                    isLocked: template.isLocked,
                    unlockTime: template.unlockTime,
                    latitude: asset.location?.coordinate.latitude ?? template.latitude,
                    longitude: asset.location?.coordinate.longitude ?? template.longitude,
                    isPlaceNameUserSet: template.isPlaceNameUserSet,
                    country: template.country,
                    dateAddedToApp: Date()
                )
            )
        }

        return result.sorted { $0.dateTaken < $1.dateTaken }
    }

    // MARK: - Fetch

    private func fetchAssets(for section: DaySection) -> [PHAsset] {
        let moments = section.moments
        guard !moments.isEmpty else { return [] }

        let dates = moments.map(\.dateTaken)
        let start = (dates.min() ?? Date()).addingTimeInterval(-timePadding)
        let end = (dates.max() ?? Date()).addingTimeInterval(timePadding)

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            start as NSDate,
            end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            guard !asset.mediaSubtypes.contains(.photoScreenshot) else { return }
            fetched.append(asset)
        }

        if let anchor = representativeCoordinate(from: section) {
            let anchorLocation = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
            fetched = fetched.filter { asset in
                guard let location = asset.location else { return true }
                return anchorLocation.distance(from: location) <= distanceThreshold
            }
        }

        var byId: [String: PHAsset] = [:]
        for asset in fetched {
            byId[asset.localIdentifier] = asset
        }

        for id in section.moments.compactMap(\.assetIdentifier) where byId[id] == nil {
            let match = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            if let asset = match.firstObject {
                byId[id] = asset
            }
        }

        return byId.values.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
    }

    private func representativeCoordinate(from section: DaySection) -> CLLocationCoordinate2D? {
        for moment in section.moments {
            if let lat = moment.latitude, let lon = moment.longitude {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        for moment in section.moments {
            guard let assetId = moment.assetIdentifier else { continue }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let location = assets.firstObject?.location {
                return location.coordinate
            }
        }
        return nil
    }
}
