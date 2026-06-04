import SwiftUI
import Combine

/// Holds the app's current color theme. Loaded from persistence at launch and
/// updated during onboarding. `BabyTownTheme` tokens read `ThemeManager.shared.theme`.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var theme: ColorTheme

    private init() {
        self.theme = DataPersistenceManager.shared.loadColorTheme()
    }

    /// Sets and persists the theme. Call from the onboarding picker.
    func setTheme(_ theme: ColorTheme) {
        self.theme = theme
        DataPersistenceManager.shared.saveColorTheme(theme)
    }
}
