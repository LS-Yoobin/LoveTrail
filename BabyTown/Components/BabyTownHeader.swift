import SwiftUI
import Combine

struct BabyTownHeader: View {

    var onSettingsTap: (() -> Void)? = nil
    var unreadLetterCount: Int = 0
    var onLettersTap: (() -> Void)? = nil
    var onGardenTap: (() -> Void)? = nil
    var onVisitPetTap: (() -> Void)? = nil
    var onMapTap: (() -> Void)? = nil
    var onTableOfContentsTap: (() -> Void)? = nil
    var isNightMode: Bool = false

    private var showsNavigationMenu: Bool {
        onLettersTap != nil
            || onGardenTap != nil
            || onVisitPetTap != nil
            || onMapTap != nil
            || onTableOfContentsTap != nil
    }

    private var iconForeground: Color {
        isNightMode ? .white.opacity(0.9) : BabyTownTheme.textPrimary.opacity(0.6)
    }

    var body: some View {
        ZStack {
            // Logo hidden for now — restore to bring back the BabyTown wordmark.
            // Image("BabyTownLogo")
            //     .resizable()
            //     .scaledToFit()
            //     .frame(height: 120)

            HStack {
                if let onSettingsTap = onSettingsTap {
                    Button {
                        onSettingsTap()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(iconForeground)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }

                Spacer()

                if showsNavigationMenu {
                    Menu {
                        if let onLettersTap {
                            Button(action: onLettersTap) {
                                Label(lettersMenuTitle, systemImage: "envelope.fill")
                            }
                        }
                        if let onGardenTap {
                            Button(action: onGardenTap) {
                                Label("Our Garden", systemImage: "leaf.circle.fill")
                            }
                        }
                        if let onVisitPetTap {
                            Button(action: onVisitPetTap) {
                                Label("Visit Pet", systemImage: "pawprint.fill")
                            }
                        }
                        if let onMapTap {
                            Button(action: onMapTap) {
                                Label("Our Map", systemImage: "map.fill")
                            }
                        }
                        if let onTableOfContentsTap {
                            Button(action: onTableOfContentsTap) {
                                Label("Table of Contents", systemImage: "book.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(iconForeground)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Home navigation menu")
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 56)
    }

    private var lettersMenuTitle: String {
        switch unreadLetterCount {
        case 0:
            return "Letters"
        case 1:
            return "Letters · 1 new"
        default:
            return "Letters · \(unreadLetterCount) new"
        }
    }
}

#Preview {
    ZStack {
        HomeBackgroundView(isNightMode: false)
        BabyTownHeader()
    }
}
