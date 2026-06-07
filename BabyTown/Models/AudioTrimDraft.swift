import Foundation

/// Temporary extracted audio awaiting trim confirmation during import.
struct AudioTrimDraft: Identifiable, Equatable {
    let id: UUID
    let sourceURL: URL
    let duration: TimeInterval
    let proposedName: String
}
