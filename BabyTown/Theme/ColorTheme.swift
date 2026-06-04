import Foundation
import SwiftUI

/// The two selectable app color themes. Default is `.pink` (the original look).
/// `Codable` is retained for future embedding in persisted model structs.
enum ColorTheme: String, CaseIterable, Codable {
    case pink
    case blue

    var displayName: String {
        switch self {
        case .pink: "Pink"
        case .blue: "Blue"
        }
    }

    var tagline: String {
        switch self {
        case .pink: "Warm blush & soft evenings"
        case .blue: "Calm sky & quiet mornings"
        }
    }

    var accent: Color {
        switch self {
        case .pink: .pink
        case .blue: Color(red: 0.22, green: 0.48, blue: 0.96)
        }
    }

    var accentDeep: Color {
        switch self {
        case .pink: Color(red: 0.88, green: 0.22, blue: 0.38)
        case .blue: Color(red: 0.14, green: 0.34, blue: 0.78)
        }
    }

    var cardLight: Color {
        switch self {
        case .pink: Color(red: 1.0, green: 0.97, blue: 0.94)
        case .blue: Color(red: 0.96, green: 0.98, blue: 1.0)
        }
    }

    var cardDeep: Color {
        switch self {
        case .pink: Color(red: 0.99, green: 0.90, blue: 0.93)
        case .blue: Color(red: 0.86, green: 0.92, blue: 0.99)
        }
    }

    var blushSoft: Color {
        switch self {
        case .pink: Color(red: 1.0, green: 0.92, blue: 0.94)
        case .blue: Color(red: 0.92, green: 0.95, blue: 1.0)
        }
    }

    var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.82)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Pet-room wall swatch shown when no custom wall color is saved.
    var defaultWallColorID: String {
        switch self {
        case .pink: "wall_blush"
        case .blue: "wall_sky"
        }
    }

    /// Loads the persisted theme (same key as `DataPersistenceManager`).
    static var persisted: ColorTheme {
        guard let raw = UserDefaults.standard.string(forKey: "colorTheme"),
              let theme = ColorTheme(rawValue: raw) else {
            return .pink
        }
        return theme
    }
}
