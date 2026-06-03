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
}

extension UIImage {
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
