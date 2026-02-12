import Foundation
import UIKit

struct PolaroidEntry: Identifiable, Codable {
    let id: UUID
    let capturedAt: Date
    let imageFileName: String
    var released: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, capturedAt, imageFileName, released
    }
}
