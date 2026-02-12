import UIKit

struct Moment: Identifiable, Codable {
    let id: UUID
    let dateTaken: Date
    var assetIdentifier: String?
    let thumbnail: UIImage
    var placeName: String?
    var caption: String?
    var voiceNotePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, dateTaken, assetIdentifier, thumbnailData, placeName, caption, voiceNotePath
    }
    
    init(id: UUID, dateTaken: Date, assetIdentifier: String? = nil, thumbnail: UIImage, placeName: String? = nil, caption: String? = nil, voiceNotePath: String? = nil) {
        self.id = id
        self.dateTaken = dateTaken
        self.assetIdentifier = assetIdentifier
        self.thumbnail = thumbnail
        self.placeName = placeName
        self.caption = caption
        self.voiceNotePath = voiceNotePath
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dateTaken = try container.decode(Date.self, forKey: .dateTaken)
        assetIdentifier = try container.decodeIfPresent(String.self, forKey: .assetIdentifier)
        placeName = try container.decodeIfPresent(String.self, forKey: .placeName)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        voiceNotePath = try container.decodeIfPresent(String.self, forKey: .voiceNotePath)
        
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
        try container.encodeIfPresent(placeName, forKey: .placeName)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encodeIfPresent(voiceNotePath, forKey: .voiceNotePath)
        
        if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
            try container.encode(thumbnailData, forKey: .thumbnailData)
        }
    }
}

// MARK: - Sample Data

extension Moment {

    static func placeholder(_ color: UIColor) -> UIImage {
        let size = CGSize(width: 300, height: 300)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    static var sampleMoments: [Moment] {
        let cal = Calendar.current

        let day1 = cal.date(from: DateComponents(year: 2025, month: 6, day: 10, hour: 14))!
        let day2 = cal.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 10))!
        let day3 = cal.date(from: DateComponents(year: 2025, month: 7, day: 4, hour: 18))!

        return [
            Moment(id: UUID(), dateTaken: day1,
                   thumbnail: placeholder(.systemPink), placeName: "San Jose"),
            Moment(id: UUID(), dateTaken: day1.addingTimeInterval(3600),
                   thumbnail: placeholder(.systemRed), placeName: "San Jose"),
            Moment(id: UUID(), dateTaken: day1.addingTimeInterval(7200),
                   thumbnail: placeholder(.systemOrange), placeName: "San Jose"),

            Moment(id: UUID(), dateTaken: day2,
                   thumbnail: placeholder(.systemTeal), placeName: "Santa Cruz"),
            Moment(id: UUID(), dateTaken: day2.addingTimeInterval(1800),
                   thumbnail: placeholder(.systemCyan), placeName: "Santa Cruz"),
            Moment(id: UUID(), dateTaken: day2.addingTimeInterval(5400),
                   thumbnail: placeholder(.systemMint), placeName: "Santa Cruz"),

            Moment(id: UUID(), dateTaken: day3,
                   thumbnail: placeholder(.systemPurple)),
            Moment(id: UUID(), dateTaken: day3.addingTimeInterval(2700),
                   thumbnail: placeholder(.systemIndigo)),
        ]
    }

    static var samplePinnedOfficial: UIImage {
        placeholder(.init(red: 0.92, green: 0.35, blue: 0.45, alpha: 1))
    }

    static var samplePinnedFirstMet: UIImage {
        placeholder(.init(red: 0.95, green: 0.6, blue: 0.65, alpha: 1))
    }
}
