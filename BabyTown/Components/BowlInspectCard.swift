import SwiftUI

/// Popover card shown when the user taps the food bowl, water bowl, or litter
/// box — bowl art at the top, a fullness bar, and the matching care action.
struct BowlInspectCard: View {
    let prop: PetRoomScene.RoomProp
    let hunger: Int
    let thirst: Int
    let litter: Int
    let foodServings: Int
    /// Clean-frame art of the equipped litter box, shown for the litter inspect card.
    var litterImage: UIImage? = nil
    /// Status line shown for plants in place of a fullness bar (cooldown-aware).
    var plantStatusText: String? = nil
    var onAction: () -> Void
    var onSecondaryAction: (() -> Void)?
    var onClose: () -> Void

    private struct Config {
        let title: String
        let imageName: String
        let value: Int
        let fullnessLabel: String
        let primaryButton: String
        let secondaryButton: String?
        let tint: Color
        /// Plants show a status line instead of a fullness bar.
        var showsFullnessBar: Bool = true
        var statusText: String? = nil
    }

    private var config: Config {
        switch prop {
        case .foodBowl:
            return Config(
                title: "Food Bowl",
                imageName: "prop_food_bowl",
                value: hunger,
                fullnessLabel: "Fullness",
                primaryButton: "Refill",
                secondaryButton: "Buy Food",
                tint: .orange
            )
        case .waterBowl:
            return Config(
                title: "Water Bowl",
                imageName: "prop_water_bowl",
                value: thirst,
                fullnessLabel: "Fullness",
                primaryButton: "Refill",
                secondaryButton: nil,
                tint: .blue
            )
        case .litterBox:
            return Config(
                title: "Litter Box",
                imageName: "prop_litter_box",
                value: litter,
                fullnessLabel: "Cleanliness",
                primaryButton: "Clean",
                secondaryButton: nil,
                tint: .brown
            )
        case .smallPlant, .bigPlant:
            return Config(
                title: prop == .smallPlant ? "Tulip Pot Plant" : "Monstera Pot Plant",
                imageName: prop == .smallPlant ? "prop_small_plant" : "prop_big_plant",
                value: 0,
                fullnessLabel: "",
                primaryButton: "Water",
                secondaryButton: nil,
                tint: Color(red: 0.30, green: 0.70, blue: 0.45),
                showsFullnessBar: false,
                statusText: plantStatusText ?? "Give your plant a drink 💧"
            )
        case .cat:
            return Config(
                title: "",
                imageName: "",
                value: 0,
                fullnessLabel: "",
                primaryButton: "",
                secondaryButton: nil,
                tint: BabyTownTheme.accent
            )
        case .toiletPaperMess:
            return Config(
                title: "",
                imageName: "",
                value: 0,
                fullnessLabel: "",
                primaryButton: "",
                secondaryButton: nil,
                tint: BabyTownTheme.accent
            )
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

            Group {
                if prop == .litterBox, let litterImage {
                    Image(uiImage: litterImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(c.imageName)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(height: 96)

            if c.showsFullnessBar {
                VStack(alignment: .leading, spacing: 8) {
                    Text(c.fullnessLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BabyTownTheme.textPrimary)
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
                        .foregroundStyle(BabyTownTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let statusText = c.statusText {
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 10) {
                Button(action: onAction) {
                    Text(c.primaryButton)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(BabyTownTheme.buttonGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let secondary = c.secondaryButton, let onSecondaryAction {
                    Button(action: onSecondaryAction) {
                        Text(secondary)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.accentDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(BabyTownTheme.accent.opacity(0.45), lineWidth: 1.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.92))
                                    )
                            )
                    }
                }
            }
        }
        .padding(18)
        .background(BabyTownTheme.background, in: RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        .padding(.horizontal, 32)
    }
}
