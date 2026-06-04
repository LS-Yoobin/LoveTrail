import Foundation

struct CouplePlaylistTrack: Codable, Equatable, Identifiable {
    let id: UUID
    var displayName: String
    let fileName: String
    let addedAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        displayName: String,
        fileName: String,
        addedAt: Date = Date(),
        sortOrder: Int
    ) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
        self.addedAt = addedAt
        self.sortOrder = sortOrder
    }
}
