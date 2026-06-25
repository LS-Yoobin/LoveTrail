import Foundation
import Combine
import SwiftUI
import PhotosUI
import Photos
import ImageIO

@MainActor
final class FirstMemoriesViewModel: ObservableObject {

    @Published var firstMetImage: UIImage?
    @Published var officialImage: UIImage?
    @Published var heroImage: UIImage?
    @Published var firstMetDate: Date?
    @Published var officialDate: Date?

    @Published var firstMetItem: PhotosPickerItem?
    @Published var officialItem: PhotosPickerItem?

    var canFinish: Bool {
        officialImage != nil
    }

    func reset() {
        firstMetImage = nil
        officialImage = nil
        heroImage = nil
        firstMetDate = nil
        officialDate = nil
        firstMetItem = nil
        officialItem = nil
    }

    func handleFirstMetSelection() async {
        guard let item = firstMetItem else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        firstMetImage = UIImage(data: data)
        heroImage = firstMetImage
        
        if let exifDate = extractDateFromEXIF(data) {
            firstMetDate = exifDate
        } else {
            firstMetDate = await loadPhotoDateFromAsset(item)
        }
    }

    func handleOfficialSelection() async {
        guard let item = officialItem else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        officialImage = UIImage(data: data)
        heroImage = officialImage
        
        if let exifDate = extractDateFromEXIF(data) {
            officialDate = exifDate
        } else {
            officialDate = await loadPhotoDateFromAsset(item)
        }
    }

    private func extractDateFromEXIF(_ data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        
        // Try EXIF DateTimeOriginal first
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String,
           let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try EXIF DateTimeDigitized
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeDigitized as String] as? String,
           let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try TIFF DateTime
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateString = tiff[kCGImagePropertyTIFFDateTime as String] as? String,
           let date = formatter.date(from: dateString) {
            return date
        }
        
        return nil
    }

    private func loadPhotoDateFromAsset(_ item: PhotosPickerItem) async -> Date? {
        guard let assetId = item.itemIdentifier else { return nil }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }
        return asset.creationDate
    }
}
