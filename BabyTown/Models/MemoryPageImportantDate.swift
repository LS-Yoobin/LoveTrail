import Foundation
import GardenCore
import UIKit

/// Important-date label shown on the scrapbook moment page.
struct MemoryPageImportantDateInfo: Equatable {
    let title: String
    let date: Date

    init(title: String, date: Date) {
        self.title = title
        self.date = date
    }

    init(item: ImportantDateItem) {
        self.init(title: item.title, date: item.date)
    }
}

enum MemoryPageMomentFactory {

    static func moments(from memory: PromptMemory) -> [Moment] {
        memory.asEditingDaySection().moments.sorted { $0.dateTaken < $1.dateTaken }
    }

    static func moment(image: UIImage, importantDate: MemoryPageImportantDateInfo, itemId: String) -> Moment {
        Moment(
            id: stableMomentId(for: itemId),
            dateTaken: importantDate.date,
            thumbnail: image,
            dateAddedToApp: Date()
        )
    }

    static func stableMomentId(for itemId: String) -> UUID {
        if let uuid = UUID(uuidString: itemId) { return uuid }
        switch itemId {
        case "firstMet":
            return UUID(uuidString: "E1000001-0000-4000-8000-000000000001")!
        case "official":
            return UUID(uuidString: "E1000001-0000-4000-8000-000000000002")!
        default:
            return UUID()
        }
    }
}

extension PromptMemory {
    var sortedViewerMoments: [Moment] {
        MemoryPageMomentFactory.moments(from: self)
    }
}
