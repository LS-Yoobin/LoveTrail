import Foundation
import UIKit
import CoreLocation

struct PolaroidEntry: Identifiable, Codable {
    let id: UUID
    let capturedAt: Date
    let imageFileName: String
    var released: Bool
    var manuallyReleasedAt: Date?
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    var vibeFileName: String?
    var videoFileName: String?

    enum CodingKeys: String, CodingKey {
        case id, capturedAt, imageFileName, released, manuallyReleasedAt, placeName, latitude, longitude, vibeFileName, videoFileName
    }

    init(
        id: UUID,
        capturedAt: Date,
        imageFileName: String,
        released: Bool,
        manuallyReleasedAt: Date? = nil,
        placeName: String? = nil,
        location: CLLocation? = nil,
        vibeFileName: String? = nil,
        videoFileName: String? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.imageFileName = imageFileName
        self.released = released
        self.manuallyReleasedAt = manuallyReleasedAt
        self.placeName = placeName
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.vibeFileName = vibeFileName
        self.videoFileName = videoFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        imageFileName = try container.decode(String.self, forKey: .imageFileName)
        released = try container.decode(Bool.self, forKey: .released)
        manuallyReleasedAt = try container.decodeIfPresent(Date.self, forKey: .manuallyReleasedAt)
        placeName = try container.decodeIfPresent(String.self, forKey: .placeName)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        vibeFileName = try container.decodeIfPresent(String.self, forKey: .vibeFileName)
        videoFileName = try container.decodeIfPresent(String.self, forKey: .videoFileName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(capturedAt, forKey: .capturedAt)
        try container.encode(imageFileName, forKey: .imageFileName)
        try container.encode(released, forKey: .released)
        try container.encodeIfPresent(manuallyReleasedAt, forKey: .manuallyReleasedAt)
        try container.encodeIfPresent(placeName, forKey: .placeName)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(vibeFileName, forKey: .vibeFileName)
        try container.encodeIfPresent(videoFileName, forKey: .videoFileName)
    }
    
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
}
