import Foundation
import UIKit

struct MemorySharePhotoSource: Identifiable {
    let id: UUID
    let thumbnail: UIImage
    let assetIdentifier: String?
    let isLocked: Bool
}

struct MemorySharePayload: Identifiable {
    let id: UUID
    let date: Date
    let dateDisplay: String
    let placeName: String?
    let isPlaceNameUserSet: Bool
    let promptText: String?
    let loveNote: String?
    let photoSources: [MemorySharePhotoSource]

    var unlockedPhotoSources: [MemorySharePhotoSource] {
        photoSources.filter { !$0.isLocked }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        placeName: String?,
        isPlaceNameUserSet: Bool,
        promptText: String?,
        loveNote: String?,
        photoSources: [MemorySharePhotoSource]
    ) {
        self.id = id
        self.date = date
        self.dateDisplay = Self.formatShareDate(date)
        self.placeName = placeName
        self.isPlaceNameUserSet = isPlaceNameUserSet
        self.promptText = promptText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.loveNote = loveNote?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.photoSources = photoSources
    }

    init(section: DaySection) {
        let primary = section.moments.first
        let sources = section.moments.map { moment in
            MemorySharePhotoSource(
                id: moment.id,
                thumbnail: moment.thumbnail,
                assetIdentifier: moment.assetIdentifier,
                isLocked: moment.isLocked
            )
        }
        self.init(
            id: primary?.id ?? UUID(),
            date: section.date,
            placeName: primary?.placeName,
            isPlaceNameUserSet: section.isPlaceNameUserSet,
            promptText: primary?.promptText,
            loveNote: primary?.caption,
            photoSources: sources
        )
    }

    init(memory: PromptMemory) {
        let sources = memory.photos.map { photo in
            MemorySharePhotoSource(
                id: photo.id,
                thumbnail: photo.thumbnail,
                assetIdentifier: photo.assetIdentifier,
                isLocked: Self.isPromptPhotoLocked(photo)
            )
        }
        self.init(
            id: memory.id,
            date: memory.date,
            placeName: memory.placeName,
            isPlaceNameUserSet: false,
            promptText: memory.promptText,
            loveNote: memory.loveNote,
            photoSources: sources
        )
    }

    init(pinned: PinnedItem) {
        switch pinned {
        case .moment(let primary, let all):
            let sources = all.map { moment in
                MemorySharePhotoSource(
                    id: moment.id,
                    thumbnail: moment.thumbnail,
                    assetIdentifier: moment.assetIdentifier,
                    isLocked: moment.isLocked
                )
            }
            self.init(
                id: pinned.id,
                date: pinned.date,
                placeName: primary.placeName,
                isPlaceNameUserSet: primary.isPlaceNameUserSet,
                promptText: primary.promptText,
                loveNote: primary.caption,
                photoSources: sources
            )
        case .prompt(let memory):
            self.init(memory: memory)
        }
    }

    private static func formatShareDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date)
    }

    private static func isPromptPhotoLocked(_ photo: PromptPhoto) -> Bool {
        guard photo.isFromCamera, let unlockTime = photo.unlockTime else { return false }
        return Date() < unlockTime
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
