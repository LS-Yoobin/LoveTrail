import SwiftUI

struct ItineraryStopCard: View {
    let stop: ItineraryStop
    let itineraryStops: [ItineraryStop]
    var showsReorderHandle: Bool = false
    var dayLabel: String? = nil
    var onDelete: (() -> Void)? = nil

    private var badgeStyle: PlannerStopBadgeStyle {
        PlannerStopBadgeStyle.forStop(stop, in: itineraryStops)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Order badge
            ZStack {
                Circle()
                    .fill(badgeStyle.fill)
                    .frame(width: 28, height: 28)
                Text("\(stop.order)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Photo or pin icon
            Group {
                if let data = stop.photoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                } else {
                    BabyTownTheme.accentSoft
                        .overlay {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 18))
                                .foregroundStyle(BabyTownTheme.accent)
                        }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Text
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stop.placeName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let dayLabel {
                        Text(dayLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BabyTownTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BabyTownTheme.accentSoft, in: Capsule())
                    }
                }

                if let note = stop.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .padding(.trailing, showsReorderHandle ? 28 : 0)
        .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .trailing) {
            if showsReorderHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(.trailing, 8)
            }
        }
    }
}

#Preview {
    let previewStops = [
        ItineraryStop(id: UUID(), order: 1, placeName: "Blue Bottle Coffee", note: "Get the New Orleans iced latte"),
        ItineraryStop(id: UUID(), order: 2, placeName: "Dolores Park"),
    ]
    VStack(spacing: 12) {
        ItineraryStopCard(
            stop: previewStops[0],
            itineraryStops: previewStops,
            showsReorderHandle: false
        )
        ItineraryStopCard(
            stop: previewStops[1],
            itineraryStops: previewStops,
            showsReorderHandle: true
        )
    }
    .padding()
    .background(BabyTownTheme.backgroundGradient)
}
