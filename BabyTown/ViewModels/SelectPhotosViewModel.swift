import Foundation
import Combine
import SwiftUI
import Photos

@MainActor
final class SelectPhotosViewModel: ObservableObject {

    // MARK: - Filters

    @Published var selectedYear: Int
    @Published var selectedMonth: Int

    // MARK: - Data

    @Published var assets: [PHAsset] = []
    @Published var thumbnails: [String: UIImage] = [:]
    @Published var isLoading = false

    // MARK: - Selection

    @Published var selectionMode = false
    @Published var selectedAssets: Set<String> = []
    @Published var isSaving = false

    // MARK: - Viewer

    @Published var viewerIndex: Int?

    // MARK: - Authorization

    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    let imageManager = PHCachingImageManager()

    // MARK: - Computed

    var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 10)...current).reversed()
    }

    var selectedCount: Int { selectedAssets.count }

    // MARK: - Init

    init() {
        let cal = Calendar.current
        let now = Date()
        selectedYear = cal.component(.year, from: now)
        selectedMonth = cal.component(.month, from: now)
    }

    // MARK: - Authorization

    func checkAuthorization() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            authorizationStatus = granted
        } else {
            authorizationStatus = status
        }

        if authorizationStatus == .authorized || authorizationStatus == .limited {
            await fetchAssets()
        }
    }

    // MARK: - Fetch

    func fetchAssets() async {
        isLoading = true
        imageManager.stopCachingImagesForAllAssets()
        thumbnails.removeAll()
        assets = []

        await Task.yield()

        let calendar = Calendar.current
        var start = DateComponents()
        start.year = selectedYear
        start.month = selectedMonth
        start.day = 1

        guard let startDate = calendar.date(from: start),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            isLoading = false
            return
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            startDate as NSDate,
            endDate as NSDate
        )
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetched.append(asset)
        }

        assets = fetched
        isLoading = false
    }

    // MARK: - Thumbnails

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
            DispatchQueue.main.async {
                self?.thumbnails[id] = image
            }
        }
    }

    // MARK: - Selection

    func toggleSelection(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedAssets.contains(id) {
            selectedAssets.remove(id)
        } else {
            selectedAssets.insert(id)
        }
    }
    
    func saveMoments() async -> [Moment] {
        guard !isSaving else { return [] }
        isSaving = true
        
        let selectedIds = selectedAssets
        let selectedPHAssets = assets.filter { selectedIds.contains($0.localIdentifier) }
        
        let factory = MomentFactory()
        let moments = await factory.createMoments(from: selectedPHAssets)
        
        selectedAssets.removeAll()
        selectionMode = false
        isSaving = false
        
        return moments
    }
}
