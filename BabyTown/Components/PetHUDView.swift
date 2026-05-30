import SwiftUI

enum PetNeedStat: Identifiable {
    case hunger, thirst, litter, happiness

    var id: Self { self }
}

/// The top overlay strip in the pet room: a coins pill + four compact need
/// meters (incl. happiness, so the user can check how the cat's feeling).
struct PetHUDView: View {
    let coins: Int
    let hunger: Int
    let thirst: Int
    let litter: Int
    let happiness: Int
    var onStatTap: (PetNeedStat) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 5) {
                Text("🪙")
                Text("\(coins)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            HStack(spacing: 14) {
                PetMeter(icon: "🍗", label: "Hunger", value: hunger, tint: .orange) {
                    onStatTap(.hunger)
                }
                PetMeter(icon: "💧", label: "Thirst", value: thirst, tint: .blue) {
                    onStatTap(.thirst)
                }
                PetMeter(icon: "🧹", label: "Litter", value: litter, tint: .brown) {
                    onStatTap(.litter)
                }
                PetMeter(icon: "😻", label: "Happiness", value: happiness, tint: BabyTownTheme.accent) {
                    onStatTap(.happiness)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
    }
}

/// A single compact need meter: emoji + a thin progress bar.
private struct PetMeter: View {
    let icon: String
    let label: String
    let value: Int
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon).font(.system(size: 15))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.10)).frame(width: 40, height: 6)
                    Capsule().fill(tint).frame(width: 40 * CGFloat(value) / 100, height: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(value) percent")
        .accessibilityHint("Shows details")
    }
}

#Preview {
    ZStack {
        Color.pink.opacity(0.2)
        VStack {
            PetHUDView(coins: 128, hunger: 70, thirst: 35, litter: 90, happiness: 55)
            Spacer()
        }
    }
}
