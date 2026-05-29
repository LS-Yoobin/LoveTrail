import SwiftUI

enum BabyTownTheme {

    // MARK: - Backgrounds

    static let background = Color.white
    static let blush = Color.pink.opacity(0.15)
    static let backgroundGradient = LinearGradient(
        colors: [background, background],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Accents

    static let accent = Color.pink
    static let accentDeep = Color(red: 0.88, green: 0.22, blue: 0.38)
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let accentSoft = Color.pink.opacity(0.08)

    // MARK: - Text

    static let textPrimary = Color(.darkGray)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    // MARK: - Cards

    static let cardBackground = Color(red: 0.96, green: 0.82, blue: 0.86)
    static let cardShadow = Color.black.opacity(0.05)
    static let cardRadius: CGFloat = 18

    // MARK: - Buttons

    static let buttonGradient = LinearGradient(
        colors: [accent, accent.opacity(0.82)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let buttonShadow = Color.pink.opacity(0.3)
}

enum PlaceNameFormatting {
    static func displayName(raw: String?, isUserSet: Bool) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.hasPrefix("Near ") ? String(trimmed.dropFirst(5)) : trimmed
        if isUserSet { return stripped }
        return "Near \(stripped)"
    }

    static func storedName(fromUserInput input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("Near ") { return String(trimmed.dropFirst(5)) }
        return trimmed
    }
}
