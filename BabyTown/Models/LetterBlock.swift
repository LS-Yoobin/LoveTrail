import Foundation
import CoreGraphics

enum LetterPhotoLayout {
    static let baseWidth: CGFloat = 240
    static let chinHeight: CGFloat = 24
    /// Default inline photo scale when composing a letter (15% larger than the original 1.0).
    static let defaultScale: CGFloat = 1.15
    static let minScale: CGFloat = 0.45
    static let maxScale: CGFloat = 1.35
    static let defaultRotation: Double = 0
    /// Default sticker scale when composing a letter (matches garden photo stickers).
    static let defaultStickerScale: CGFloat = ProfileSticker.newStickerScale
}

enum LetterBlockType: String, Codable, CaseIterable {
    case voiceMemo
    case photo
    case sticker

    var captureType: PreludeCapture.CaptureType? {
        switch self {
        case .voiceMemo: return .voiceMemo
        case .photo, .sticker: return nil
        }
    }

    var icon: String {
        switch self {
        case .voiceMemo: return "mic.fill"
        case .photo: return "photo.on.rectangle.angled"
        case .sticker: return "square.on.square.dashed"
        }
    }

    var label: String {
        switch self {
        case .voiceMemo: return "Voice"
        case .photo: return "Photo"
        case .sticker: return "Sticker"
        }
    }
}

struct LetterBlock: Identifiable, Codable, Equatable {
    let id: UUID
    let type: LetterBlockType
    var voiceMemoFileId: String?
    var photoImageId: UUID?
    var photoRotation: Double?
    var photoScale: CGFloat?
    var stickerImageId: UUID?
    var stickerPosition: NormalizedPoint?
    var stickerRotation: Double?
    var stickerScale: CGFloat?
    var usedSubjectLift: Bool?

    init(
        id: UUID = UUID(),
        type: LetterBlockType,
        voiceMemoFileId: String? = nil,
        photoImageId: UUID? = nil,
        photoRotation: Double? = nil,
        photoScale: CGFloat? = nil,
        stickerImageId: UUID? = nil,
        stickerPosition: NormalizedPoint? = nil,
        stickerRotation: Double? = nil,
        stickerScale: CGFloat? = nil,
        usedSubjectLift: Bool? = nil
    ) {
        self.id = id
        self.type = type
        self.voiceMemoFileId = voiceMemoFileId
        self.photoImageId = photoImageId
        self.photoRotation = photoRotation
        self.photoScale = photoScale
        self.stickerImageId = stickerImageId
        self.stickerPosition = stickerPosition
        self.stickerRotation = stickerRotation
        self.stickerScale = stickerScale
        self.usedSubjectLift = usedSubjectLift
    }

    var displayTitle: String {
        switch type {
        case .voiceMemo:
            return "Voice message"
        case .photo:
            return "Photo"
        case .sticker:
            return "Sticker"
        }
    }

    var previewText: String {
        switch type {
        case .voiceMemo:
            return "Voice message"
        case .photo:
            return "Photo"
        case .sticker:
            return "Sticker"
        }
    }

    var typeIcon: String { type.icon }

    var typeLabel: String { type.label }

    func profileSticker(fallbackPosition: NormalizedPoint = NormalizedPoint(x: 0.5, y: 0.6)) -> ProfileSticker {
        ProfileSticker(
            id: id,
            kind: .moment,
            sourceKey: stickerImageId?.uuidString ?? id.uuidString,
            position: stickerPosition ?? fallbackPosition,
            rotation: stickerRotation ?? 0,
            scale: stickerScale ?? LetterPhotoLayout.defaultStickerScale,
            usedSubjectLift: usedSubjectLift ?? false
        )
    }
}
