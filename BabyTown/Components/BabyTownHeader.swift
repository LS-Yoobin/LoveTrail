import SwiftUI
import Combine
import UIKit

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
                    HamburgerNavigationMenuButton(items: navigationMenuButtonItems)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Home navigation menu")
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 56)
        .onAppear {
            // #region agent log
            HamburgerDebugLog.write(
                hypothesisId: "H3",
                location: "BabyTownHeader.swift:onAppear",
                message: "BabyTownHeader appeared",
                data: [
                    "isNightMode": isNightMode,
                    "showsNavigationMenu": showsNavigationMenu,
                    "menuItemCount": navigationMenuButtonItems.count
                ]
            )
            // #endregion
        }
    }

    private var navigationMenuButtonItems: [HamburgerNavigationMenuButton.Item] {
        var items: [HamburgerNavigationMenuButton.Item] = []

        if let onLettersTap {
            items.append(
                .init(title: lettersMenuTitle, systemImage: "envelope.fill", action: onLettersTap)
            )
        }
        if let onGardenTap {
            items.append(
                .init(title: "Our Garden", systemImage: "leaf.circle.fill", action: onGardenTap)
            )
        }
        if let onVisitPetTap {
            items.append(
                .init(title: "Visit Pet", systemImage: "pawprint.fill", action: onVisitPetTap)
            )
        }
        if let onMapTap {
            items.append(
                .init(title: "Our Map", systemImage: "map.fill", action: onMapTap)
            )
        }
        if let onTableOfContentsTap {
            items.append(
                .init(title: "Table of Contents", systemImage: "book.fill", action: onTableOfContentsTap)
            )
        }

        return items
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

// UIKit menu keeps the trigger icon black while menu row icons stay white.
// SwiftUI Menu applies `.tint()` from menu content onto the hamburger label too.
private struct HamburgerNavigationMenuButton: UIViewRepresentable {

    struct Item {
        let title: String
        let systemImage: String
        let action: () -> Void
    }

    let items: [Item]

    func makeUIView(context: Context) -> UIButton {
        let button = DebugHamburgerButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Home navigation menu"
        // #region agent log
        HamburgerDebugLog.write(
            hypothesisId: "H1",
            location: "BabyTownHeader.swift:makeUIView",
            message: "Hamburger UIButton created",
            data: ["buttonType": "system", "showsMenuAsPrimaryAction": true]
        )
        // #endregion
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "line.3", withConfiguration: symbolConfig)
        button.setImage(image, for: .normal)
        button.tintColor = .black

        let traitStyle = button.traitCollection.userInterfaceStyle.rawValue
        let imageRenderingMode = image?.renderingMode.rawValue ?? -1
        // #region agent log
        HamburgerDebugLog.write(
            hypothesisId: "H2",
            location: "BabyTownHeader.swift:updateUIView",
            message: "Applied hamburger styling",
            data: [
                "setTintColor": HamburgerDebugLog.colorDescription(.black),
                "actualTintColor": HamburgerDebugLog.colorDescription(button.tintColor),
                "traitUserInterfaceStyle": traitStyle,
                "imageRenderingMode": imageRenderingMode,
                "menuItemCount": items.count
            ]
        )
        // #endregion

        button.menu = UIMenu(
            children: items.map { item in
                UIAction(
                    title: item.title,
                    image: menuItemIcon(named: item.systemImage),
                    handler: { _ in item.action() }
                )
            }
        )

        DispatchQueue.main.async {
            // #region agent log
            HamburgerDebugLog.write(
                hypothesisId: "H1",
                location: "BabyTownHeader.swift:updateUIView:async",
                message: "Post-layout hamburger state",
                data: [
                    "actualTintColor": HamburgerDebugLog.colorDescription(button.tintColor),
                    "traitUserInterfaceStyle": button.traitCollection.userInterfaceStyle.rawValue,
                    "superviewTintColor": HamburgerDebugLog.colorDescription(button.superview?.tintColor),
                    "windowTintColor": HamburgerDebugLog.colorDescription(button.window?.tintColor),
                    "isHidden": button.isHidden,
                    "alpha": button.alpha
                ]
            )
            // #endregion
        }
    }

    private func menuItemIcon(named systemName: String) -> UIImage? {
        UIImage(systemName: systemName)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
    }
}

// #region agent log
private enum HamburgerDebugLog {
    private static let logPath = "/Users/ybstudio/Desktop/Projects/Covela/.cursor/debug-dcf6e9.log"
    private static let ingestURL = URL(string: "http://127.0.0.1:7746/ingest/7d886d98-0f6f-4ddf-9280-f6baa1620581")

    static func write(hypothesisId: String, location: String, message: String, data: [String: Any]) {
        let payload: [String: Any] = [
            "sessionId": "dcf6e9",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "runId": "pre-fix"
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: jsonData, encoding: .utf8) else { return }

        if let ingestURL {
            var request = URLRequest(url: ingestURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("dcf6e9", forHTTPHeaderField: "X-Debug-Session-Id")
            request.httpBody = jsonData
            URLSession.shared.dataTask(with: request).resume()
        }

        let url = URL(fileURLWithPath: logPath)
        if FileManager.default.fileExists(atPath: logPath),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data((line + "\n").utf8))
            try? handle.close()
        } else {
            try? Data((line + "\n").utf8).write(to: url, options: .atomic)
        }

        NSLog("[hamburger-debug] \(line)")
    }

    static func colorDescription(_ color: UIColor?) -> String {
        guard let color else { return "nil" }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "rgba(%.2f,%.2f,%.2f,%.2f)", red, green, blue, alpha)
    }
}

private final class DebugHamburgerButton: UIButton {
    override var tintColor: UIColor! {
        get { super.tintColor }
        set {
            let stack = Thread.callStackSymbols.prefix(4).joined(separator: " | ")
            HamburgerDebugLog.write(
                hypothesisId: "H4",
                location: "BabyTownHeader.swift:DebugHamburgerButton.tintColor",
                message: "tintColor mutation",
                data: [
                    "newTintColor": HamburgerDebugLog.colorDescription(newValue),
                    "stack": stack
                ]
            )
            super.tintColor = newValue
        }
    }
}
// #endregion
