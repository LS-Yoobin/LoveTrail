import SwiftUI

enum PetNeedStat: String, Identifiable, CaseIterable {
    case hunger, thirst, litter, happiness

    var id: Self { self }

    var emoji: String {
        switch self {
        case .hunger: return "🍗"
        case .thirst: return "💧"
        case .litter: return "🧹"
        case .happiness: return "😻"
        }
    }

    var label: String {
        switch self {
        case .hunger: return "Hunger"
        case .thirst: return "Thirst"
        case .litter: return "Litter Box"
        case .happiness: return "Happiness"
        }
    }

    var detail: String {
        switch self {
        case .hunger: return "Food bowl fullness"
        case .thirst: return "Water bowl level"
        case .litter: return "Cleanliness"
        case .happiness: return "How your kitty is feeling"
        }
    }

    var tint: Color {
        switch self {
        case .hunger: return .orange
        case .thirst: return .blue
        case .litter: return .brown
        case .happiness: return BabyTownTheme.accent
        }
    }
}

/// Renders a need emoji at a consistent size/color in the pet-room HUD and stat sheet.
struct PetNeedEmoji: View {
    let stat: PetNeedStat
    var size: CGFloat = 15

    var body: some View {
        Text(verbatim: stat.emoji)
            .font(.system(size: size))
            .frame(height: size + 2)
    }
}

/// Coin balance pill for shop sheet hero modules (top-trailing placement).
struct PetCoinBalancePill: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 6) {
            PetCoinIcon(size: 22)
            Text("\(coins)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(BabyTownTheme.accentDeep)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.92))
                .overlay(
                    Capsule()
                        .strokeBorder(BabyTownTheme.accent.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: BabyTownTheme.accent.opacity(0.12), radius: 8, y: 3)
        )
        .accessibilityLabel("Coin balance")
        .accessibilityValue("\(coins) coins")
    }
}

/// Yellow in-game coin with a “C” mark — used in the pet-room HUD and shop UI.
struct PetCoinIcon: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.93, blue: 0.42),
                            Color(red: 0.96, green: 0.78, blue: 0.14),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color(red: 0.84, green: 0.64, blue: 0.08), lineWidth: 1.5)
                )
            Text("C")
                .font(.system(size: size * 0.52, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.70, green: 0.46, blue: 0.04))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The top overlay strip in the pet room: a coins pill + four compact need
/// meters (incl. happiness, so the user can check how the cat's feeling).
struct PetHUDView: View {
    let coins: Int
    let level: Int
    let hunger: Int
    let thirst: Int
    let litter: Int
    let happiness: Int
    var onInventoryTap: () -> Void = {}
    var onStatsTap: () -> Void = {}
    var onLevelLongPress: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Button(action: onInventoryTap) {
                    HStack(spacing: 6) {
                        PetCoinIcon(size: 22)
                        Text("\(coins)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("My items")
                .accessibilityValue("\(coins) coins")
                .accessibilityHint("Opens décor you own for this room")

                levelPill
            }

            Spacer()

            Button(action: onStatsTap) {
                HStack(spacing: 14) {
                    PetMeter(stat: .hunger, value: hunger)
                    PetMeter(stat: .thirst, value: thirst)
                    PetMeter(stat: .litter, value: litter)
                    PetMeter(stat: .happiness, value: happiness)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Kitty needs")
            .accessibilityHint("Shows hunger, thirst, litter, and happiness")
        }
        .padding(.horizontal, 16)
    }

    private var levelPill: some View {
        Text("Lvl \(level)")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(BabyTownTheme.accentDeep)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(BabyTownTheme.accent.opacity(0.16), in: Capsule())
            .onLongPressGesture(minimumDuration: 1.2) {
                onLevelLongPress?()
            }
            .accessibilityLabel("Pet level")
            .accessibilityValue("Level \(level)")
    }
}

/// A single compact need meter: emoji + a thin progress bar.
private struct PetMeter: View {
    let stat: PetNeedStat
    let value: Int

    var body: some View {
        VStack(spacing: 4) {
            PetNeedEmoji(stat: stat)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.10)).frame(width: 40, height: 6)
                Capsule().fill(stat.tint).frame(width: 40 * CGFloat(value) / 100, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.pink.opacity(0.2)
        VStack {
            PetHUDView(coins: 128, level: 7, hunger: 70, thirst: 35, litter: 90, happiness: 55)
            Spacer()
        }
    }
}
