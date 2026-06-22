import Foundation

struct PreludeChapter: Codable, Equatable {
    let startDate: Date
    let officialDate: Date
    let creatorUserId: String
    let partnerUserId: String
    var giftCaptureIds: [UUID]
}
