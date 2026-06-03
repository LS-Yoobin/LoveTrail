import SwiftUI
import GardenCore

/// Dark glass card showing travel stats: countries, cities, and places visited.
struct OurHistoryCard: View {
    let stats: TravelHistoryStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Our History")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                statColumn(value: stats.countries, label: "Countries")
                Spacer()
                statColumn(value: stats.cities, label: "Cities")
                Spacer()
                statColumn(value: stats.places, label: "Places")
            }
        }
        .padding(18)
        .background { CoupleProfileScrollCardBackground() }
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }
}
