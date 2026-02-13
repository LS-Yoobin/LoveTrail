import Foundation
import UIKit

struct PolaroidEntry: Identifiable, Codable {
    let id: UUID
    let capturedAt: Date
    let imageFileName: String
    var released: Bool
    var manuallyReleasedAt: Date?
    var isFifthPhoto: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, capturedAt, imageFileName, released, manuallyReleasedAt, isFifthPhoto
    }
}
