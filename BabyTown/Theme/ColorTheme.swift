import Foundation

/// The two selectable app color themes. Default is `.pink` (the original look).
/// `Codable` is retained for future embedding in persisted model structs.
enum ColorTheme: String, CaseIterable, Codable {
    case pink
    case blue
}
