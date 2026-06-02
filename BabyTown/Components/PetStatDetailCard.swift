import SwiftUI

/// Popover shown when the user taps the need meters in the pet-room HUD.
struct PetStatDetailCard: View {
    let hunger: Int
    let thirst: Int
    let litter: Int
    let happiness: Int
    var onClose: () -> Void

    private struct StatRow: Identifiable {
        let stat: PetNeedStat
        let value: Int

        var id: PetNeedStat { stat }
    }

    private var rows: [StatRow] {
        PetNeedStat.allCases.map { stat in
            StatRow(
                stat: stat,
                value: value(for: stat)
            )
        }
    }

    private func value(for stat: PetNeedStat) -> Int {
        switch stat {
        case .hunger: return hunger
        case .thirst: return thirst
        case .litter: return litter
        case .happiness: return happiness
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Kitty Needs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 18) {
                ForEach(rows) { row in
                    statSection(row)
                }
            }
        }
        .padding(20)
        .background(BabyTownTheme.background, in: RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        .padding(.horizontal, 32)
    }

    private func statSection(_ row: StatRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                PetNeedEmoji(stat: row.stat, size: 15)
                Text(row.stat.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                Spacer()
                Text("\(row.value)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }

            Text(row.stat.detail)
                .font(.system(size: 14))
                .foregroundStyle(.black)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.10)).frame(height: 14)
                GeometryReader { geo in
                    Capsule()
                        .fill(row.stat.tint)
                        .frame(width: geo.size.width * CGFloat(row.value) / 100, height: 14)
                }
                .frame(height: 14)
            }
            .frame(height: 14)
        }
    }
}
