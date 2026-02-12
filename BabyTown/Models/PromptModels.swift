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
    
    enum CodingKeys: String, CodingKey {
        case id, dateTaken, thumbnailData, assetIdentifier
    }
    
    init(id: UUID = UUID(), dateTaken: Date, thumbnail: UIImage, assetIdentifier: String? = nil) {
        self.id = id
        self.dateTaken = dateTaken
        self.thumbnail = thumbnail
        self.assetIdentifier = assetIdentifier
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dateTaken = try container.decode(Date.self, forKey: .dateTaken)
        assetIdentifier = try container.decodeIfPresent(String.self, forKey: .assetIdentifier)
        
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
