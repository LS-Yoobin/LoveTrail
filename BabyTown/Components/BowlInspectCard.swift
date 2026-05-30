import SwiftUI

/// Popover card shown when the user taps the food bowl, water bowl, or litter
/// box — bowl art at the top, a fullness bar, and the matching care action.
struct BowlInspectCard: View {
    let prop: PetRoomScene.RoomProp
    let hunger: Int
    let thirst: Int
    let litter: Int
    let foodServings: Int
    var onAction: () -> Void
    var onClose: () -> Void

    private struct Config {
        let title: String
        let imageName: String
        let value: Int
        let fullnessLabel: String
        let button: String
        let tint: Color
    }

    private var config: Config {
        switch prop {
        case .foodBowl:
            return Config(title: "Food Bowl", imageName: "prop_food_bowl", value: hunger,
                          fullnessLabel: "Fullness · \(foodServings) serving\(foodServings == 1 ? "" : "s") left",
                          button: "Refill and Buy Food", tint: .orange)
        case .waterBowl:
            return Config(title: "Water Bowl", imageName: "prop_water_bowl", value: thirst,
                          fullnessLabel: "Fullness", button: "Refill", tint: .blue)
        case .litterBox:
            return Config(title: "Litter Box", imageName: "prop_litter_box", value: litter,
                          fullnessLabel: "Cleanliness", button: "Clean", tint: .brown)
        case .cat:
            return Config(title: "", imageName: "", value: 0, fullnessLabel: "", button: "", tint: .pink)
        }
    }

    var body: some View {
        let c = config
        VStack(spacing: 18) {
            HStack {
                Text(c.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            }

            Image(c.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 96)

            VStack(alignment: .leading, spacing: 8) {
                Text(c.fullnessLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.10)).frame(height: 12)
                    GeometryReader { geo in
                        Capsule()
                            .fill(c.tint)
                            .frame(width: geo.size.width * CGFloat(c.value) / 100)
                    }
                    .frame(height: 12)
                }
                .frame(height: 12)
                Text("\(c.value)%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onAction) {
                Text(c.button)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(BabyTownTheme.buttonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .background(BabyTownTheme.background, in: RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        .padding(.horizontal, 32)
    }
}
