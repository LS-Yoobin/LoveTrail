import SwiftUI

/// Popover shown when the user taps a need meter in the pet-room HUD.
struct PetStatDetailCard: View {
    let stat: PetNeedStat
    let value: Int
    var onClose: () -> Void

    private struct Config {
        let title: String
        let emoji: String
        let detail: String
        let tint: Color
    }

    private var config: Config {
        switch stat {
        case .hunger:
            return Config(title: "Hunger", emoji: "🍗", detail: "Food bowl fullness", tint: .orange)
        case .thirst:
            return Config(title: "Thirst", emoji: "💧", detail: "Water bowl level", tint: .blue)
        case .litter:
            return Config(title: "Litter Box", emoji: "🧹", detail: "Cleanliness", tint: .brown)
        case .happiness:
            return Config(title: "Happiness", emoji: "😻", detail: "How your kitty is feeling", tint: BabyTownTheme.accent)
        }
    }

    var body: some View {
        let c = config
        VStack(spacing: 16) {
            HStack {
                Text("\(c.emoji) \(c.title)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(c.detail)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.10)).frame(height: 18)
                    GeometryReader { geo in
                        Capsule()
                            .fill(c.tint)
                            .frame(width: geo.size.width * CGFloat(value) / 100, height: 18)
                    }
                    .frame(height: 18)
                }
                .frame(height: 18)

                Text("\(value)%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }
        }
        .padding(20)
        .background(BabyTownTheme.background, in: RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        .padding(.horizontal, 32)
    }
}
