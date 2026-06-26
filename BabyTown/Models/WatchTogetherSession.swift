import Foundation

enum WatchTogetherSessionStatus: String, Codable {
    case waiting
    case active
    case ended
}

struct WatchTogetherSession: Identifiable, Codable, Equatable {
    let id: UUID
    let coupleID: String
    let hostUserID: String
    let videoURL: String
    var status: WatchTogetherSessionStatus
    let createdAt: Date
    let expiresAt: Date
}

enum WatchTogetherSignalType: String, Codable {
    case offer
    case answer
    case iceCandidate
}

struct WatchTogetherSignalMessage: Codable, Equatable {
    let type: WatchTogetherSignalType
    let fromUserID: String
    let payload: String
}

struct WatchTogetherInvite: Equatable {
    let sessionID: UUID
    let videoURL: String
    let hostName: String
}
