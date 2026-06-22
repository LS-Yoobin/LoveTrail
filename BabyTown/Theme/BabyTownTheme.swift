import SwiftUI
import SpriteKit

enum BabyTownTheme {

    // MARK: - Theme

    static var theme: ColorTheme { ThemeManager.shared.theme }
    private static var isBlue: Bool { theme == .blue }

    // MARK: - Backgrounds

    static let background = Color.white
    static var blush: Color { isBlue ? Color.blue.opacity(0.15) : Color.pink.opacity(0.15) }
    static var backgroundGradient: LinearGradient {
        isBlue
            ? LinearGradient(colors: [background, Color(red: 0.88, green: 0.94, blue: 0.99)],
                             startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [background, background], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Accents

    static var accent: Color { isBlue ? Color(red: 0.22, green: 0.48, blue: 0.96) : Color.pink }
    static var accentDeep: Color {
        isBlue ? Color(red: 0.14, green: 0.34, blue: 0.78) : Color(red: 0.88, green: 0.22, blue: 0.38)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .leading, endPoint: .trailing)
    }
    static var accentSoft: Color { accent.opacity(0.08) }

    // MARK: - Text

    static let textPrimary = Color(.darkGray)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    /// Home memory search bar in day mode — fixed light gray (avoids semantic `systemGray` flipping dark).
    static let daySearchBarFill = Color(red: 0.66, green: 0.66, blue: 0.68)
    static let daySearchBarText = Color.white
    static let daySearchBarPlaceholder = Color.white.opacity(0.72)
    static let daySearchBarIcon = Color.white.opacity(0.85)

    // MARK: - Cards

    static var cardBackground: Color {
        isBlue ? Color(red: 0.80, green: 0.88, blue: 0.96) : Color(red: 0.96, green: 0.82, blue: 0.86)
    }
    static let cardShadow = Color.black.opacity(0.05)
    static let cardRadius: CGFloat = 18

    /// Muted accent fill (e.g. sticker-edit "Add More" button). Pink: soft salmon. Blue: muted blue.
    static var accentMuted: Color {
        isBlue ? Color(red: 0.52, green: 0.68, blue: 0.90) : Color(red: 0.93, green: 0.55, blue: 0.52)
    }
    /// Very light blush background tint. Pink: warm blush. Blue: cool light blue.
    static var blushSoft: Color {
        isBlue ? Color(red: 0.92, green: 0.95, blue: 1.0) : Color(red: 1.0, green: 0.92, blue: 0.94)
    }

    /// Light card gradient endpoints used by pet cards/sheets. Pink: warm rose. Blue: cool blue.
    static var cardTintLight: Color {
        isBlue ? Color(red: 0.96, green: 0.98, blue: 1.0) : Color(red: 1.0, green: 0.97, blue: 0.94)
    }
    static var cardTintDeep: Color {
        isBlue ? Color(red: 0.86, green: 0.92, blue: 0.99) : Color(red: 0.99, green: 0.90, blue: 0.93)
    }

    /// Rose tint for locked pet-trick icons. Pink: medium rose (original). Blue: medium blue.
    static var lockedIconTint: Color {
        isBlue ? Color(red: 0.30, green: 0.50, blue: 0.80) : Color(red: 0.84, green: 0.41, blue: 0.45)
    }

    // MARK: - Invite Banner

    static var inviteBannerFill: Color {
        isBlue ? Color(red: 1.000, green: 0.953, blue: 0.839) : Color(red: 0.910, green: 0.871, blue: 1.000)
    }
    static var inviteBannerBorder: Color {
        isBlue ? Color(red: 0.878, green: 0.690, blue: 0.376) : Color(red: 0.659, green: 0.533, blue: 0.816)
    }
    static var inviteBannerText: Color {
        isBlue ? Color(red: 0.353, green: 0.220, blue: 0.000) : Color(red: 0.227, green: 0.157, blue: 0.376)
    }
    static var inviteBannerSubtext: Color {
        isBlue ? Color(red: 0.478, green: 0.314, blue: 0.000) : Color(red: 0.353, green: 0.251, blue: 0.502)
    }

    // MARK: - Buttons

    static var buttonGradient: LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.82)], startPoint: .leading, endPoint: .trailing)
    }
    static var buttonShadow: Color { accent.opacity(0.3) }

    /// Solid blue for Save confirmation pills (edit garden, editors, etc.).
    static let savePillFill = Color(red: 0.22, green: 0.48, blue: 0.96)
    static let savePillShadow = savePillFill.opacity(0.35)

    /// Pink → red (or blue → deep blue) icon tint used on onboarding access cards and the home camera control.
    static var accentIconGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentIconBackdropGradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(0.15), accentDeep.opacity(0.08)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Bridged colors (SpriteKit / UIKit)

    static var accentUIColor: UIColor { UIColor(accent) }
    static var accentDeepUIColor: UIColor { UIColor(accentDeep) }

    /// Pet-room ambient surfaces. Pink: warm peach. Blue: cool light blue.
    static var roomWallTop: Color {
        isBlue ? Color(red: 0.93, green: 0.96, blue: 1.0) : Color(red: 1.0, green: 0.93, blue: 0.95)
    }
    static var roomWallBottom: Color {
        isBlue ? Color(red: 0.83, green: 0.90, blue: 0.98) : Color(red: 0.99, green: 0.86, blue: 0.83)
    }
    static var roomFloor: Color {
        isBlue ? Color(red: 0.74, green: 0.84, blue: 0.95) : Color(red: 0.97, green: 0.80, blue: 0.74)
    }
    static var roomWallTopSK: SKColor { SKColor(roomWallTop) }
    static var roomWallBottomSK: SKColor { SKColor(roomWallBottom) }
    static var roomFloorSK: SKColor { SKColor(roomFloor) }
    static var accentSK: SKColor { SKColor(accent) }
    static var accentDeepSK: SKColor { SKColor(accentDeep) }
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
