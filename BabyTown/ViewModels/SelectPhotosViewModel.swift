import Foundation
import Combine
import SwiftUI
import Photos
import PhotosUI

@MainActor
final class SelectPhotosViewModel: ObservableObject {

    // MARK: - Filters

    @Published var selectedYear: Int {
        didSet {
            UserDefaults.standard.set(selectedYear, forKey: "SelectPhotos_SelectedYear")
            clampSelectedMonthIfNeeded()
        }
    }
    @Published var selectedMonth: Int {
        didSet {
            UserDefaults.standard.set(selectedMonth, forKey: "SelectPhotos_SelectedMonth")
        }
    }

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

    var availableMonths: [Int] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        if selectedYear > currentYear { return [] }
        if selectedYear < currentYear { return Array(1...12) }
        return Array(1...currentMonth)
    }

    var selectedCount: Int { selectedAssets.count }

    // MARK: - Init

    init() {
        let cal = Calendar.current
        let now = Date()
        
        // Load saved filter values or use current date as default
        if let savedYear = UserDefaults.standard.object(forKey: "SelectPhotos_SelectedYear") as? Int {
            selectedYear = savedYear
        } else {
            selectedYear = cal.component(.year, from: now)
        }
        
        if let savedMonth = UserDefaults.standard.object(forKey: "SelectPhotos_SelectedMonth") as? Int {
            selectedMonth = savedMonth
        } else {
            selectedMonth = cal.component(.month, from: now)
        }

        clampSelectedMonthIfNeeded()
    }

    // MARK: - Month availability

    func isMonthSelectable(_ month: Int, for year: Int? = nil) -> Bool {
        let year = year ?? selectedYear
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        if year > currentYear { return false }
        if year < currentYear { return true }
        return month >= 1 && month <= currentMonth
    }

    func clampSelectedMonthIfNeeded() {
        guard !isMonthSelectable(selectedMonth) else { return }
        let calendar = Calendar.current
        selectedMonth = calendar.component(.month, from: Date())
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
        
        let selectedPHAssets = fetchSelectedAssets()
        
        let factory = MomentFactory()
        let moments = await factory.createMoments(from: selectedPHAssets)
        
        selectedAssets.removeAll()
        selectionMode = false
        isSaving = false
        
        return moments
    }
    
    func convertToPromptPhotos() async -> [PromptPhoto] {
        guard !isSaving else { return [] }
        isSaving = true
        
        let selectedPHAssets = fetchSelectedAssets()
        
        var promptPhotos: [PromptPhoto] = []
        
        for asset in selectedPHAssets {
            guard let thumbnail = await loadFullSizeImage(for: asset) else { continue }
            let promptPhoto = PromptPhoto(
                dateTaken: asset.creationDate ?? Date(),
                thumbnail: thumbnail,
                assetIdentifier: asset.localIdentifier,
                isFromCamera: false,
                unlockTime: nil,
                latitude: asset.location?.coordinate.latitude,
                longitude: asset.location?.coordinate.longitude
            )
            promptPhotos.append(promptPhoto)
        }
        
        selectedAssets.removeAll()
        selectionMode = false
        isSaving = false
        
        return promptPhotos
    }
    
    func createMomentsFromPickerResults(_ results: [PHPickerResult]) async -> [Moment] {
        guard !results.isEmpty else { return [] }
        isSaving = true
        defer { isSaving = false }

        var assets: [PHAsset] = []
        var fallbackImages: [UIImage] = []

        for result in results {
            if let id = result.assetIdentifier {
                let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if let asset = fetched.firstObject {
                    assets.append(asset)
                    continue
                }
            }
            if let image = await loadImage(from: result.itemProvider) {
                fallbackImages.append(image)
            }
        }

        var moments = await MomentFactory().createMoments(from: assets)
        for image in fallbackImages {
            moments.append(Moment(
                id: UUID(),
                dateTaken: Date(),
                thumbnail: image
            ))
        }
        return moments
    }

    func createPromptPhotosFromPickerResults(_ results: [PHPickerResult]) async -> [PromptPhoto] {
        guard !results.isEmpty else { return [] }
        isSaving = true
        defer { isSaving = false }

        var promptPhotos: [PromptPhoto] = []

        for result in results {
            if let id = result.assetIdentifier {
                let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if let asset = fetched.firstObject,
                   let thumbnail = await loadFullSizeImage(for: asset) {
                    promptPhotos.append(PromptPhoto(
                        dateTaken: asset.creationDate ?? Date(),
                        thumbnail: thumbnail,
                        assetIdentifier: asset.localIdentifier,
                        latitude: asset.location?.coordinate.latitude,
                        longitude: asset.location?.coordinate.longitude
                    ))
                    continue
                }
            }
            if let image = await loadImage(from: result.itemProvider) {
                promptPhotos.append(PromptPhoto(
                    dateTaken: Date(),
                    thumbnail: image
                ))
            }
        }
        return promptPhotos
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    private func fetchSelectedAssets() -> [PHAsset] {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: Array(selectedAssets),
            options: nil
        )
        var fetched: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            fetched.append(asset)
        }
        return fetched
    }

    private func loadFullSizeImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 2000, height: 2000),
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
