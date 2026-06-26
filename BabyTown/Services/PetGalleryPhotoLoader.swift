import UIKit

/// A single photo tile for the memory-frame picker (moments + prompt memories).
struct PetGalleryPhoto: Identifiable, Equatable {
    let id: UUID
    let dateTaken: Date
    let thumbnail: UIImage
}

enum PetGalleryPhotoLoader {

    /// Every moment / prompt photo, newest first.
    static func loadAllPhotos() -> [PetGalleryPhoto] {
        var photos: [PetGalleryPhoto] = []

        for moment in DataPersistenceManager.shared.loadMoments() {
            photos.append(PetGalleryPhoto(id: moment.id, dateTaken: moment.dateTaken, thumbnail: moment.thumbnail))
        }

        for memory in DataPersistenceManager.shared.loadPromptMemories() {
            for photo in memory.photos {
                photos.append(PetGalleryPhoto(id: photo.id, dateTaken: photo.dateTaken, thumbnail: photo.thumbnail))
            }
        }

        return photos.sorted { $0.dateTaken > $1.dateTaken }
    }

    static func image(for momentID: UUID) -> UIImage? {
        guard let thumbnail = loadAllPhotos().first(where: { $0.id == momentID })?.thumbnail else {
            return nil
        }
        return thumbnail.normalizedForSpriteKit()
    }

    /// Upright image for a pet-room picture frame (center-cropped to 4:5).
    static func pictureFrameImage(for momentID: UUID) -> UIImage? {
        if let moment = DataPersistenceManager.shared.loadMoments().first(where: { $0.id == momentID }) {
            return moment.thumbnail.preparedForPictureFrame(assetIdentifier: moment.assetIdentifier)
        }
        if let promptPhoto = DataPersistenceManager.shared.loadPromptMemories()
            .flatMap(\.photos)
            .first(where: { $0.id == momentID }) {
            return promptPhoto.thumbnail.preparedForPictureFrame(assetIdentifier: promptPhoto.assetIdentifier)
        }
        return nil
    }

    static func assetIdentifierForDisplay(momentID: UUID) -> String? {
        assetIdentifier(for: momentID)
    }

    private static func assetIdentifier(for momentID: UUID) -> String? {
        if let moment = DataPersistenceManager.shared.loadMoments().first(where: { $0.id == momentID }) {
            return moment.assetIdentifier
        }
        return DataPersistenceManager.shared.loadPromptMemories()
            .flatMap(\.photos)
            .first(where: { $0.id == momentID })?
            .assetIdentifier
    }
}

extension UIImage {
    /// Portrait 4:5 (width ÷ height) for pet-room picture-frame windows.
    static let pictureFrameAspectRatio: CGFloat = 4 / 5

    /// Upright image for picture-frame placement; center-cropped to 4:5 so photos stay inside the frame window.
    func preparedForPictureFrame(assetIdentifier: String? = nil) -> UIImage {
        normalizedForSpriteKit().centerCropped(toAspectRatio: Self.pictureFrameAspectRatio)
    }

    /// Center-crops to `aspect` (width ÷ height).
    func centerCropped(toAspectRatio aspect: CGFloat) -> UIImage {
        guard aspect > 0 else { return self }
        let source = normalizedForSpriteKit()
        let w = source.size.width
        let h = source.size.height
        guard w > 1, h > 1 else { return source }

        let current = w / h
        let cropRect: CGRect
        if current > aspect + 0.001 {
            let cropW = h * aspect
            cropRect = CGRect(x: (w - cropW) / 2, y: 0, width: cropW, height: h)
        } else if current < aspect - 0.001 {
            let cropH = w / aspect
            cropRect = CGRect(x: 0, y: (h - cropH) / 2, width: w, height: cropH)
        } else {
            return source
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        return UIGraphicsImageRenderer(size: cropRect.size, format: format).image { _ in
            source.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
    }

    /// SpriteKit ignores `imageOrientation`; bake pixels upright before texturing.
    func normalizedForSpriteKit() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Aspect-fill `target` using the image's oriented pixel dimensions.
    func sizeAspectFilling(_ target: CGSize) -> CGSize {
        let source = size
        guard source.width > 0, source.height > 0 else { return target }
        let scale = max(target.width / source.width, target.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }
}
