import SwiftUI

struct StoryOnboardingTheme {
    static var backgroundBlush: Color {
        BabyTownTheme.theme == .blue ? Color(red: 0.95, green: 0.97, blue: 1.0) : Color(red: 1.0, green: 0.95, blue: 0.95)
    }
    static var primaryRed: Color { BabyTownTheme.accentDeep }
    static var accentPink: Color {
        BabyTownTheme.theme == .blue ? Color(red: 0.62, green: 0.78, blue: 1.0) : Color(red: 1.0, green: 0.7, blue: 0.75)
    }
    static let textDark = Color(red: 0.2, green: 0.15, blue: 0.15)
    
    static let cornerRadius: CGFloat = 20
    static let shadowRadius: CGFloat = 8
    static let spacing: CGFloat = 24
}
