import Foundation
import SwiftUI

/// Who authored a scrapbook note on a memory page canvas.
enum MemoryNoteAuthor: String, Codable, CaseIterable, Identifiable {
    case localUser
    case partner

    var id: String { rawValue }
}

/// One scrapbook note on a full moment page (at most one per author).
struct MemoryPageNote: Codable, Equatable, Identifiable {
    var author: MemoryNoteAuthor
    var text: String
    var position: NormalizedPoint?

    var id: MemoryNoteAuthor { author }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasContent: Bool {
        !trimmedText.isEmpty
    }
}

/// Scrapbook decorations for one memory cluster (timeline card or founding slot).
struct MemoryCanvas: Codable, Equatable {
    /// Stable key — first moment id in the cluster (`memory_<uuid>`).
    let memoryKey: String
    var stickers: [ProfileSticker]
    var notes: [MemoryPageNote]

    init(
        memoryKey: String,
        stickers: [ProfileSticker] = [],
        notes: [MemoryPageNote] = []
    ) {
        self.memoryKey = memoryKey
        self.stickers = stickers
        self.notes = Self.normalizedNotes(notes)
    }

    static func memoryKey(anchorMomentId: UUID) -> String {
        "memory_\(anchorMomentId.uuidString)"
    }

    func note(for author: MemoryNoteAuthor) -> MemoryPageNote? {
        notes.first { $0.author == author && $0.hasContent }
    }

    var localUserNote: MemoryPageNote? {
        note(for: .localUser)
    }

    var partnerNote: MemoryPageNote? {
        note(for: .partner)
    }

    var displayedNotes: [MemoryPageNote] {
        notes.filter(\.hasContent)
    }

    mutating func upsertNote(
        author: MemoryNoteAuthor,
        text: String?,
        position: NormalizedPoint?
    ) {
        notes.removeAll { $0.author == author }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        notes.append(MemoryPageNote(author: author, text: trimmed, position: position))
        notes = Self.normalizedNotes(notes)
    }

    mutating func setNotePosition(_ position: NormalizedPoint, for author: MemoryNoteAuthor) {
        guard let index = notes.firstIndex(where: { $0.author == author }) else { return }
        notes[index].position = position
    }

    private static func normalizedNotes(_ notes: [MemoryPageNote]) -> [MemoryPageNote] {
        var seen = Set<MemoryNoteAuthor>()
        return notes.filter { note in
            guard note.hasContent else { return false }
            return seen.insert(note.author).inserted
        }
    }

    enum CodingKeys: String, CodingKey {
        case memoryKey, stickers, notes
        case memoryNote, memoryNotePosition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memoryKey = try container.decode(String.self, forKey: .memoryKey)
        stickers = try container.decodeIfPresent([ProfileSticker].self, forKey: .stickers) ?? []
        notes = try container.decodeIfPresent([MemoryPageNote].self, forKey: .notes) ?? []

        if notes.isEmpty,
           let legacyNote = try container.decodeIfPresent(String.self, forKey: .memoryNote)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !legacyNote.isEmpty {
            let legacyPosition = try container.decodeIfPresent(
                NormalizedPoint.self,
                forKey: .memoryNotePosition
            )
            notes = [MemoryPageNote(author: .localUser, text: legacyNote, position: legacyPosition)]
        }

        notes = Self.normalizedNotes(notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memoryKey, forKey: .memoryKey)
        try container.encode(stickers, forKey: .stickers)
        try container.encode(notes, forKey: .notes)
    }
}

enum MemoryCanvasLayout {
    static let canvasMinHeight: CGFloat = 220
    static let defaultNotePosition = NormalizedPoint(x: 0.5, y: 0.78)
    static let fullPageDragBounds = (
        minX: CGFloat(0.04),
        maxX: CGFloat(0.96),
        minY: CGFloat(0.04),
        maxY: CGFloat(0.96)
    )

    static func defaultNotePosition(canvasSize: CGSize) -> NormalizedPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return defaultNotePosition
        }
        let noteW = ProfileGardenNoteLayout.noteWidth(for: canvasSize.width)
        let noteH = ProfileGardenNoteLayout.noteHeight(for: noteW)
        let minY = (noteH / 2 + 12) / canvasSize.height
        return NormalizedPoint(x: 0.5, y: max(defaultNotePosition.y, minY))
    }
}

/// Scroll layout for the full moment scrapbook page.
enum MemoryPageLayout {
    /// Open canvas below metadata (love note, date, etc.) for photo stickers.
    static let stickerSandboxHeight: CGFloat = 960
    static let noteBelowMetadataPadding: CGFloat = 20
    /// `scrollTo` anchor Y: keeps the note band above the footer with room for the keyboard.
    static let noteComposeScrollAnchorUnitY: CGFloat = 0.44

    static func noteHeight(canvasWidth: CGFloat) -> CGFloat {
        let noteW = ProfileGardenNoteLayout.noteWidth(for: canvasWidth)
        return ProfileGardenNoteLayout.noteHeight(for: noteW)
    }

    /// Distance from metadata bottom to the default note center (padding + half note height).
    static func noteScrollContentOffset(canvasWidth: CGFloat) -> CGFloat {
        noteBelowMetadataPadding + noteHeight(canvasWidth: canvasWidth) / 2
    }

    /// Sticker canvas below the default note placement.
    static func sandboxBelowNoteHeight(canvasWidth: CGFloat) -> CGFloat {
        max(
            160,
            stickerSandboxHeight - noteBelowMetadataPadding - noteHeight(canvasWidth: canvasWidth)
        )
    }

    static func defaultNotePosition(
        metadataBottomY: CGFloat,
        contentHeight: CGFloat,
        canvasWidth: CGFloat
    ) -> NormalizedPoint {
        defaultNotePosition(
            for: .localUser,
            existingNotes: [],
            metadataBottomY: metadataBottomY,
            contentHeight: contentHeight,
            canvasWidth: canvasWidth
        )
    }

    /// Default center for a note author; offsets horizontally when both partners have notes.
    static func defaultNotePosition(
        for author: MemoryNoteAuthor,
        existingNotes: [MemoryPageNote],
        metadataBottomY: CGFloat,
        contentHeight: CGFloat,
        canvasWidth: CGFloat
    ) -> NormalizedPoint {
        guard contentHeight > 0, canvasWidth > 0 else {
            let x: CGFloat = author == .localUser ? 0.32 : 0.68
            return NormalizedPoint(x: x, y: MemoryCanvasLayout.defaultNotePosition.y)
        }
        let noteW = ProfileGardenNoteLayout.noteWidth(for: canvasWidth)
        let noteH = ProfileGardenNoteLayout.noteHeight(for: noteW)
        let anchorY = metadataBottomY > 0
            ? metadataBottomY + noteBelowMetadataPadding + noteH / 2
            : contentHeight * MemoryCanvasLayout.defaultNotePosition.y
        let normalizedY = min(max(anchorY / contentHeight, 0.08), 0.92)

        let otherAuthors = Set(existingNotes.filter(\.hasContent).map(\.author))
        let hasPair = otherAuthors.contains(author == .localUser ? .partner : .localUser)
        let normalizedX: CGFloat
        if hasPair {
            normalizedX = author == .localUser ? 0.32 : 0.68
        } else {
            normalizedX = 0.5
        }
        return NormalizedPoint(x: normalizedX, y: normalizedY)
    }

    /// Keeps the note center below metadata text (prompt, place, date, love note).
    static func noteDragBounds(
        metadataBottomY: CGFloat,
        contentHeight: CGFloat,
        canvasWidth: CGFloat
    ) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let maxY: CGFloat = 0.96
        let minX: CGFloat = 0.04
        let maxX: CGFloat = 0.96
        guard contentHeight > 0, canvasWidth > 0 else {
            return (minX, maxX, 0.42, maxY)
        }
        let noteH = noteHeight(canvasWidth: canvasWidth)
        let minCenterY = metadataBottomY > 0
            ? metadataBottomY + noteBelowMetadataPadding + noteH / 2
            : contentHeight * 0.42
        let minY = min(max(minCenterY / contentHeight, 0.08), maxY - 0.02)
        return (minX, maxX, minY, maxY)
    }

    static func clampNotePosition(
        _ position: NormalizedPoint,
        metadataBottomY: CGFloat,
        contentHeight: CGFloat,
        canvasWidth: CGFloat
    ) -> NormalizedPoint {
        let limits = noteDragBounds(
            metadataBottomY: metadataBottomY,
            contentHeight: contentHeight,
            canvasWidth: canvasWidth
        )
        return NormalizedPoint(
            x: min(max(position.x, limits.minX), limits.maxX),
            y: min(max(position.y, limits.minY), limits.maxY)
        )
    }

    static func stickerDragBounds(
        metadataBottomY: CGFloat,
        contentHeight: CGFloat
    ) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let sandboxMinY: CGFloat
        if metadataBottomY > 0, contentHeight > 0 {
            sandboxMinY = min(max((metadataBottomY + 8) / contentHeight, 0.08), 0.90)
        } else {
            sandboxMinY = 0.42
        }
        return (minX: 0.04, maxX: 0.96, minY: sandboxMinY, maxY: 0.96)
    }

    static func defaultStickerPosition(
        metadataBottomY: CGFloat,
        contentHeight: CGFloat,
        index: Int = 0
    ) -> NormalizedPoint {
        let bounds = stickerDragBounds(metadataBottomY: metadataBottomY, contentHeight: contentHeight)
        let midY = (bounds.minY + bounds.maxY) / 2
        let xs: [CGFloat] = [0.28, 0.62, 0.45, 0.72]
        let ys: [CGFloat] = [midY - 0.06, midY, midY + 0.06, midY + 0.10]
        let i = index % xs.count
        return NormalizedPoint(x: xs[i], y: min(ys[i], bounds.maxY - 0.04))
    }
}

struct MemoryPageMetadataBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MemoryPageContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
