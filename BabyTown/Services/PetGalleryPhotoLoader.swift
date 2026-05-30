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
        loadAllPhotos().first { $0.id == momentID }?.thumbnail
    }
}
