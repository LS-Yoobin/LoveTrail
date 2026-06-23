import Foundation
import UIKit

struct PromptItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    
    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

struct PromptPhoto: Identifiable, Codable {
    let id: UUID
    let dateTaken: Date
    var assetIdentifier: String?
    var isFromCamera: Bool
    var unlockTime: Date?
    var latitude: Double?
    var longitude: Double?

    /// Thumbnail bytes live on disk via `ThumbnailStore`, not in this struct.
    var thumbnail: UIImage {
        ThumbnailStore.shared.image(for: id) ?? Moment.missingThumbnailPlaceholder
    }

    enum CodingKeys: String, CodingKey {
        case id, dateTaken, thumbnailData, assetIdentifier, isFromCamera, unlockTime, latitude, longitude
    }
    
    init(id: UUID = UUID(), dateTaken: Date, thumbnail: UIImage, assetIdentifier: String? = nil, isFromCamera: Bool = false, unlockTime: Date? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.dateTaken = dateTaken
        ThumbnailStore.shared.cache(thumbnail, for: id)
        self.assetIdentifier = assetIdentifier
        self.isFromCamera = isFromCamera
        self.unlockTime = unlockTime
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dateTaken = try container.decode(Date.self, forKey: .dateTaken)
        assetIdentifier = try container.decodeIfPresent(String.self, forKey: .assetIdentifier)
        isFromCamera = try container.decodeIfPresent(Bool.self, forKey: .isFromCamera) ?? false
        unlockTime = try container.decodeIfPresent(Date.self, forKey: .unlockTime)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        
        // Legacy inline JPEG → migrate to disk immediately (and cache for display).
        if let thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData) {
            ThumbnailStore.shared.importLegacyData(thumbnailData, for: id)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dateTaken, forKey: .dateTaken)
        try container.encodeIfPresent(assetIdentifier, forKey: .assetIdentifier)
        try container.encode(isFromCamera, forKey: .isFromCamera)
        try container.encodeIfPresent(unlockTime, forKey: .unlockTime)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        // Thumbnail bytes are persisted separately by `ThumbnailStore`, not inline here.
    }
}

struct PromptMemory: Identifiable, Codable {
    let id: UUID
    let promptText: String
    let date: Date
    var placeName: String?
    var loveNote: String
    var photos: [PromptPhoto]
    var isPinned: Bool
    var pinnedAt: Date?
    var latitude: Double?
    var longitude: Double?
    var isPlaceNameUserSet: Bool

    init(
        id: UUID = UUID(),
        promptText: String,
        date: Date,
        placeName: String? = nil,
        loveNote: String,
        photos: [PromptPhoto],
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isPlaceNameUserSet: Bool = false
    ) {
        self.id = id
        self.promptText = promptText
        self.date = date
        self.placeName = placeName
        self.loveNote = loveNote
        self.photos = photos
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.latitude = latitude
        self.longitude = longitude
        self.isPlaceNameUserSet = isPlaceNameUserSet
    }

    enum CodingKeys: String, CodingKey {
        case id, promptText, date, placeName, loveNote, photos, isPinned, pinnedAt
        case latitude, longitude, isPlaceNameUserSet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        promptText = try container.decode(String.self, forKey: .promptText)
        date = try container.decode(Date.self, forKey: .date)
        placeName = try container.decodeIfPresent(String.self, forKey: .placeName)
        loveNote = try container.decode(String.self, forKey: .loveNote)
        photos = try container.decode([PromptPhoto].self, forKey: .photos)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedAt = try container.decodeIfPresent(Date.self, forKey: .pinnedAt)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        isPlaceNameUserSet = try container.decodeIfPresent(Bool.self, forKey: .isPlaceNameUserSet) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(promptText, forKey: .promptText)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(placeName, forKey: .placeName)
        try container.encode(loveNote, forKey: .loveNote)
        try container.encode(photos, forKey: .photos)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encodeIfPresent(pinnedAt, forKey: .pinnedAt)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(isPlaceNameUserSet, forKey: .isPlaceNameUserSet)
    }

    /// Adapts this prompt memory for `CaptionEditorSheet`, which is built around `DaySection` / `Moment`.
    func asEditingDaySection() -> DaySection {
        let caption = loveNote.isEmpty ? nil : loveNote
        let moments = photos.map { photo in
            let locked = photo.isFromCamera
                && photo.unlockTime.map { Date() < $0 } == true
            return Moment(
                id: photo.id,
                dateTaken: photo.dateTaken,
                assetIdentifier: photo.assetIdentifier,
                thumbnail: photo.thumbnail,
                placeName: placeName,
                caption: caption,
                promptText: promptText,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                isLocked: locked,
                unlockTime: photo.unlockTime,
                latitude: photo.latitude ?? latitude,
                longitude: photo.longitude ?? longitude,
                isPlaceNameUserSet: isPlaceNameUserSet,
                dateAddedToApp: Date()
            )
        }
        return DaySection(date: date, placeName: placeName, moments: moments)
    }
}
