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
    let thumbnail: UIImage
    var assetIdentifier: String?
    var isFromCamera: Bool
    var unlockTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, dateTaken, thumbnailData, assetIdentifier, isFromCamera, unlockTime
    }
    
    init(id: UUID = UUID(), dateTaken: Date, thumbnail: UIImage, assetIdentifier: String? = nil, isFromCamera: Bool = false, unlockTime: Date? = nil) {
        self.id = id
        self.dateTaken = dateTaken
        self.thumbnail = thumbnail
        self.assetIdentifier = assetIdentifier
        self.isFromCamera = isFromCamera
        self.unlockTime = unlockTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dateTaken = try container.decode(Date.self, forKey: .dateTaken)
        assetIdentifier = try container.decodeIfPresent(String.self, forKey: .assetIdentifier)
        isFromCamera = try container.decodeIfPresent(Bool.self, forKey: .isFromCamera) ?? false
        unlockTime = try container.decodeIfPresent(Date.self, forKey: .unlockTime)
        
        if let thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData),
           let image = UIImage(data: thumbnailData) {
            thumbnail = image
        } else {
            thumbnail = UIImage(systemName: "photo")!
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dateTaken, forKey: .dateTaken)
        try container.encodeIfPresent(assetIdentifier, forKey: .assetIdentifier)
        try container.encode(isFromCamera, forKey: .isFromCamera)
        try container.encodeIfPresent(unlockTime, forKey: .unlockTime)
        
        if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
            try container.encode(thumbnailData, forKey: .thumbnailData)
        }
    }
}

struct PromptMemory: Identifiable, Codable {
    let id: UUID
    let promptText: String
    let date: Date
    var placeName: String?
    var loveNote: String
    var photos: [PromptPhoto]
    
    init(
        id: UUID = UUID(),
        promptText: String,
        date: Date,
        placeName: String? = nil,
        loveNote: String,
        photos: [PromptPhoto]
    ) {
        self.id = id
        self.promptText = promptText
        self.date = date
        self.placeName = placeName
        self.loveNote = loveNote
        self.photos = photos
    }
}
