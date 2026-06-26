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

    @State private var isNavigationMenuPresented = false

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

    private var hamburgerIconColor: Color {
        isNightMode ? .white.opacity(0.9) : .black
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
                    navigationMenuButton
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 44)
    }

    private var navigationMenuButton: some View {
        hamburgerIcon
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                isNavigationMenuPresented.toggle()
            }
            .accessibilityLabel("Home navigation menu")
            .popover(isPresented: $isNavigationMenuPresented, arrowEdge: .top) {
                navigationMenuPopover
                    .presentationCompactAdaptation(.popover)
            }
    }

    private var hamburgerIcon: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(hamburgerIconColor)
                    .frame(width: 20, height: 2)
            }
        }
    }

    private var navigationMenuPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onLettersTap {
                lettersMenuRow(action: onLettersTap)
            }
            if let onGardenTap {
                navigationMenuRow(title: "Our Garden", systemImage: "leaf.circle.fill", action: onGardenTap)
            }
            if let onVisitPetTap {
                navigationMenuRow(title: "Visit Pet", systemImage: "pawprint.fill", action: onVisitPetTap)
            }
            if let onMapTap {
                navigationMenuRow(title: "Our Map", systemImage: "map.fill", action: onMapTap)
            }
            if let onTableOfContentsTap {
                navigationMenuRow(title: "Table of Contents", systemImage: "book.fill", action: onTableOfContentsTap)
            }
        }
        .padding(.vertical, 8)
        .frame(minWidth: 240)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.12))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        }
    }

    private func navigationMenuRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            isNavigationMenuPresented = false
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func lettersMenuRow(action: @escaping () -> Void) -> some View {
        Button {
            isNavigationMenuPresented = false
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22)

                lettersMenuLabel
                    .font(.system(size: 16, weight: .medium))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var lettersMenuLabel: some View {
        if unreadLetterCount > 0 {
            let suffix = unreadLetterCount == 1 ? " · 1 new" : " · \(unreadLetterCount) new"
            Text("Letters")
                .foregroundStyle(.white)
            + Text(suffix)
                .foregroundStyle(.white.opacity(0.75))
        } else {
            (Text("Letters") + Text(" · Empty"))
                .foregroundStyle(.white)
        }
    }
}

#Preview("Day") {
    ZStack {
        HomeBackgroundView(isNightMode: false)
        BabyTownHeader(
            onSettingsTap: {},
            onLettersTap: {},
            onGardenTap: {},
            onVisitPetTap: {},
            onMapTap: {},
            onTableOfContentsTap: {}
        )
    }
}

#Preview("Night") {
    ZStack {
        HomeBackgroundView(isNightMode: true)
        BabyTownHeader(
            onSettingsTap: {},
            onLettersTap: {},
            onGardenTap: {},
            onVisitPetTap: {},
            onMapTap: {},
            onTableOfContentsTap: {},
            isNightMode: true
        )
    }
}
