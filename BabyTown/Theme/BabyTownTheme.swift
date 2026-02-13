import SwiftUI

enum BabyTownTheme {

    // MARK: - Backgrounds

    static let background = Color.white
    static let blush = Color.pink.opacity(0.15)
    static let backgroundGradient = LinearGradient(
        colors: [background, blush],
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

    static let cardBackground = Color.white
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
