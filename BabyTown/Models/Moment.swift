import UIKit
import CoreLocation

struct Moment: Identifiable, Codable {
    let id: UUID
    let dateTaken: Date
    var assetIdentifier: String?
    let thumbnail: UIImage
    var placeName: String?
    var caption: String?
    var voiceNotePath: String?
    var promptText: String?
    var isPinned: Bool
    var pinnedAt: Date?
    var isLocked: Bool
    var unlockTime: Date?
    var latitude: Double?
    var longitude: Double?
    var isAddedFromOnThisDay: Bool
    var isPlaceNameUserSet: Bool
    var country: String?

    enum CodingKeys: String, CodingKey {
        case id, dateTaken, assetIdentifier, thumbnailData, placeName, caption, voiceNotePath, promptText, isPinned, pinnedAt, isLocked, unlockTime, latitude, longitude, isAddedFromOnThisDay, isPlaceNameUserSet, country
    }
    
    init(id: UUID, dateTaken: Date, assetIdentifier: String? = nil, thumbnail: UIImage, placeName: String? = nil, caption: String? = nil, voiceNotePath: String? = nil, promptText: String? = nil, isPinned: Bool = false, pinnedAt: Date? = nil, isLocked: Bool = false, unlockTime: Date? = nil, latitude: Double? = nil, longitude: Double? = nil, isAddedFromOnThisDay: Bool = false, isPlaceNameUserSet: Bool = false, country: String? = nil) {
        self.id = id
        self.dateTaken = dateTaken
        self.assetIdentifier = assetIdentifier
        self.thumbnail = thumbnail
        self.placeName = placeName
        self.caption = caption
        self.voiceNotePath = voiceNotePath
        self.promptText = promptText
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.isLocked = isLocked
        self.unlockTime = unlockTime
        self.latitude = latitude
        self.longitude = longitude
        self.isAddedFromOnThisDay = isAddedFromOnThisDay
        self.isPlaceNameUserSet = isPlaceNameUserSet
        self.country = country
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dateTaken = try container.decode(Date.self, forKey: .dateTaken)
        assetIdentifier = try container.decodeIfPresent(String.self, forKey: .assetIdentifier)
        placeName = try container.decodeIfPresent(String.self, forKey: .placeName)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        voiceNotePath = try container.decodeIfPresent(String.self, forKey: .voiceNotePath)
        promptText = try container.decodeIfPresent(String.self, forKey: .promptText)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedAt = try container.decodeIfPresent(Date.self, forKey: .pinnedAt)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        unlockTime = try container.decodeIfPresent(Date.self, forKey: .unlockTime)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        isAddedFromOnThisDay = try container.decodeIfPresent(Bool.self, forKey: .isAddedFromOnThisDay) ?? false
        isPlaceNameUserSet = try container.decodeIfPresent(Bool.self, forKey: .isPlaceNameUserSet) ?? false
        country = try container.decodeIfPresent(String.self, forKey: .country)

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
        try container.encodeIfPresent(promptText, forKey: .promptText)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encodeIfPresent(pinnedAt, forKey: .pinnedAt)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encodeIfPresent(unlockTime, forKey: .unlockTime)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(isAddedFromOnThisDay, forKey: .isAddedFromOnThisDay)
        try container.encode(isPlaceNameUserSet, forKey: .isPlaceNameUserSet)
        try container.encodeIfPresent(country, forKey: .country)

        if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
            try container.encode(thumbnailData, forKey: .thumbnailData)
        }
    }
    
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    var year: Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: dateTaken)
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
    
    static var sampleMoment: Moment {
        Moment(
            id: UUID(),
            dateTaken: Date(),
            thumbnail: placeholder(.systemPink),
            placeName: "Somewhere Special"
        )
    }
}
