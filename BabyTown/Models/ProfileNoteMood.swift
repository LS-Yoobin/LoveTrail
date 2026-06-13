import SwiftUI
import UIKit

/// Mood stamp for the profile garden scrapbook note.
enum ProfileNoteMood: String, CaseIterable, Codable, Equatable {
    case butterflies, giddy, smitten, playful
    case tender, dreamy, cozy, longing
    case sad, angry, confused, jealous

    var displayName: String {
        switch self {
        case .butterflies: "Butterflies"
        case .giddy: "Giddy"
        case .smitten: "Smitten"
        case .playful: "Playful"
        case .tender: "Tender"
        case .dreamy: "Dreamy"
        case .cozy: "Cozy"
        case .longing: "Longing"
        case .sad: "Sad"
        case .angry: "Angry"
        case .confused: "Confused"
        case .jealous: "Jealous"
        }
    }

    var iconName: String {
        switch self {
        case .butterflies: "sparkle"
        case .giddy: "face.smiling"
        case .smitten: "heart.fill"
        case .playful: "bolt.heart.fill"
        case .tender: "heart.circle.fill"
        case .dreamy: "moon.stars.fill"
        case .cozy: "flame.fill"
        case .longing: "moon.fill"
        case .sad: "cloud.rain.fill"
        case .angry: "bolt.fill"
        case .confused: "questionmark.circle.fill"
        case .jealous: "eye.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .butterflies: Color(red: 232 / 255, green: 213 / 255, blue: 242 / 255)
        case .giddy: Color(red: 255 / 255, green: 229 / 255, blue: 102 / 255)
        case .smitten: Color(red: 244 / 255, green: 165 / 255, blue: 184 / 255)
        case .playful: Color(red: 255 / 255, green: 123 / 255, blue: 138 / 255)
        case .tender: Color(red: 255 / 255, green: 212 / 255, blue: 196 / 255)
        case .dreamy: Color(red: 197 / 255, green: 202 / 255, blue: 245 / 255)
        case .cozy: Color(red: 245 / 255, green: 214 / 255, blue: 168 / 255)
        case .longing: Color(red: 155 / 255, green: 181 / 255, blue: 232 / 255)
        case .sad: Color(red: 184 / 255, green: 197 / 255, blue: 217 / 255)
        case .angry: Color(red: 224 / 255, green: 122 / 255, blue: 106 / 255)
        case .confused: Color(red: 212 / 255, green: 206 / 255, blue: 216 / 255)
        case .jealous: Color(red: 196 / 255, green: 155 / 255, blue: 181 / 255)
        }
    }

    /// Soft fill for the writable text area — a lighter wash adjacent to the mood tint.
    var fieldBackgroundColor: Color {
        tintColor.opacity(0.48)
    }

    var fieldBackgroundUIColor: UIColor {
        UIColor(fieldBackgroundColor)
    }
}
