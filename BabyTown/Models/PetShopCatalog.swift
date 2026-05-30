import SwiftUI
import UIKit

enum PetShopCategory: String, CaseIterable, Identifiable {
    case furniture
    case catToys
    case wallColors
    case pictureFrames

    var id: String { rawValue }

    var title: String {
        switch self {
        case .furniture: return "Furniture"
        case .catToys: return "Cat Toys"
        case .wallColors: return "Wall Color"
        case .pictureFrames: return "Picture Frames"
        }
    }

    var systemImage: String {
        switch self {
        case .furniture: return "sofa.fill"
        case .catToys: return "balloon.fill"
        case .wallColors: return "paintpalette.fill"
        case .pictureFrames: return "photo.artframe"
        }
    }
}

struct PetShopItem: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let category: PetShopCategory
    let cost: Int
    /// Asset catalog image for furniture / toys; nil for swatch-only items.
    let imageName: String?
    let systemImage: String
    let placeholderCaption: String
    let defaultSize: CGSize
    let isFloorItem: Bool
    let isWallColor: Bool
    let isPictureFrame: Bool
}

enum PetShopCatalog {

    static let pictureFrameID = "decor_memory_frame"

    static let all: [PetShopItem] = [
        PetShopItem(
            id: "furniture_couch",
            name: "Cozy Couch",
            detail: "A soft spot for lounging on the floor.",
            category: .furniture,
            cost: 45,
            imageName: "prop_couch",
            systemImage: "sofa.fill",
            placeholderCaption: "Couch",
            defaultSize: CGSize(width: 140, height: 80),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "furniture_cat_bed",
            name: "Cat Bed",
            detail: "Plush bed for afternoon naps.",
            category: .furniture,
            cost: 35,
            imageName: "prop_cat_bed",
            systemImage: "bed.double.fill",
            placeholderCaption: "Cat Bed",
            defaultSize: CGSize(width: 90, height: 56),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "toy_yarn_ball",
            name: "Yarn Ball",
            detail: "Rolls around when the cat pounces.",
            category: .catToys,
            cost: 22,
            imageName: nil,
            systemImage: "circle.fill",
            placeholderCaption: "Yarn",
            defaultSize: CGSize(width: 36, height: 36),
            isFloorItem: true,
            isWallColor: false,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "wall_blush",
            name: "Blush Pink",
            detail: "Warm rose-tinted walls.",
            category: .wallColors,
            cost: 18,
            imageName: nil,
            systemImage: "paintpalette.fill",
            placeholderCaption: "",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: true,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "wall_sage",
            name: "Soft Sage",
            detail: "Calm green wall wash.",
            category: .wallColors,
            cost: 18,
            imageName: nil,
            systemImage: "paintpalette.fill",
            placeholderCaption: "",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: true,
            isPictureFrame: false
        ),
        PetShopItem(
            id: "wall_lavender",
            name: "Lavender Mist",
            detail: "Gentle purple evening tone.",
            category: .wallColors,
            cost: 18,
            imageName: nil,
            systemImage: "paintpalette.fill",
            placeholderCaption: "",
            defaultSize: .zero,
            isFloorItem: false,
            isWallColor: true,
            isPictureFrame: false
        ),
        PetShopItem(
            id: pictureFrameID,
            name: "Memory Frame",
            detail: "Hang a Baby Town moment on your wall.",
            category: .pictureFrames,
            cost: 32,
            imageName: nil,
            systemImage: "photo.artframe",
            placeholderCaption: "Frame",
            defaultSize: CGSize(width: 88, height: 100),
            isFloorItem: false,
            isWallColor: false,
            isPictureFrame: true
        ),
    ]

    static func item(id: String) -> PetShopItem? {
        all.first { $0.id == id }
    }

    static func items(in category: PetShopCategory) -> [PetShopItem] {
        all.filter { $0.category == category }
    }

    static func wallColor(for id: String?) -> Color {
        Color(uiColor: wallUIColor(for: id))
    }

    static func wallUIColor(for id: String?) -> UIColor {
        switch id {
        case "wall_sage":
            return UIColor(red: 0.82, green: 0.90, blue: 0.84, alpha: 1)
        case "wall_lavender":
            return UIColor(red: 0.88, green: 0.84, blue: 0.94, alpha: 1)
        case "wall_blush", nil:
            return UIColor(red: 1.0, green: 0.93, blue: 0.95, alpha: 1)
        default:
            return UIColor(red: 1.0, green: 0.93, blue: 0.95, alpha: 1)
        }
    }
}
