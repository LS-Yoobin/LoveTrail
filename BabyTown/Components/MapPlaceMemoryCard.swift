import SwiftUI

/// Grid card for a located memory, styled after Bloggo's `PlaceVisitedCard`.
struct MapPlaceMemoryCard: View {

    let section: DaySection
    var onTap: () -> Void

    private var heroThumbnail: UIImage? {
        section.moments.first?.thumbnail
    }

    private var photoCount: Int {
        section.moments.count
    }

    private var placeTitle: String {
        section.formattedPlaceName ?? section.placeDisplay
    }

    private var timestampText: String {
        section.timeDisplay
    }

    private var loveNote: String? {
        let raw = section.moments.first?.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    private var visitDateBadge: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: section.date)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let heroThumbnail {
                            Image(uiImage: heroThumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(BabyTownTheme.accentSoft)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(BabyTownTheme.accent.opacity(0.5))
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.35)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)

                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(photoCount)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text(visitDateBadge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(10)
                        .allowsHitTesting(false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(placeTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(timestampText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.7))
                        .lineLimit(1)

                    if let loveNote {
                        Text(loveNote)
                            .font(.system(size: 13))
                            .foregroundStyle(.black.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: BabyTownTheme.cardShadow, radius: 8, y: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(BabyTownTheme.accent.opacity(0.12), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
