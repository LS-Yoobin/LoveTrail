import Foundation
import UIKit

struct ProcessingMemory: Identifiable, Codable {
    let id: UUID
    let date: Date
    let unlockTime: Date
    let imageFileName: String
    
    enum CodingKeys: String, CodingKey {
        case id, date, unlockTime, imageFileName
    }
    
    func timeUntilUnlock() -> String {
        let now = Date()
        let timeInterval = unlockTime.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "Available now"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 0 {
            return "Available in \(hours)h \(minutes)m"
        } else {
            return "Available in \(minutes)m"
        }
    }
}
