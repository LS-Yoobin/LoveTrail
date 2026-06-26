import SwiftUI
import GardenCore

struct FlowerSourceContext {
    let placeName: String?
    let date: Date
}

struct FlowerAchievementSheet: View {
    let tappedElement: GardenElement
    let gardenElements: [GardenElement]
    let sourceContext: FlowerSourceContext?

    @State private var images: [String: UIImage] = [:]

    private var catalog: [BloomCatalogEntry] {
        BloomCatalogBuilder.build(from: gardenElements)
    }

    private var tappedEntry: BloomCatalogEntry? {
        catalog.first { $0.cacheKey == elementCacheKey(tappedElement) }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 4)
                    Text("Garden Blooms")
                        .font(.title2.weight(.semibold))
                }
                .padding(.top, 12)

                if let entry = tappedEntry {
                    heroCard(entry: entry)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Collection")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(catalog) { entry in
                            gridCell(entry: entry, isActive: entry.id == tappedEntry?.id)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
        }
        .task { await loadImages() }
    }

    @ViewBuilder
    private func heroCard(entry: BloomCatalogEntry) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                bloomImageView(for: entry)
                    .frame(width: 140, height: 160)
                if entry.isLegend {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(.yellow)
                        .padding(6)
                }
            }

            Text(entry.displayName)
                .font(.title3.weight(.semibold))

            Text(entry.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let ctx = sourceContext {
                earnedCaption(ctx)
            }
        }
        .padding(20)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow, lineWidth: 2))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func earnedCaption(_ ctx: FlowerSourceContext) -> some View {
        if let place = ctx.placeName {
            (Text("Earned · \(place) · ") + Text(ctx.date, style: .date))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            (Text("Earned · ") + Text(ctx.date, style: .date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func gridCell(entry: BloomCatalogEntry, isActive: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                bloomImageView(for: entry)
                    .frame(width: 70, height: 80)
                    .saturation(entry.isEarned ? 1.0 : 0.0)

                if entry.isEarned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .green)
                        .offset(x: 4, y: 4)
                } else {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color(.systemGray3))
                        .offset(x: 4, y: 4)
                }
            }

            Text(entry.displayName)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)

            if !entry.isEarned {
                Text(entry.unlockCondition)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.yellow : Color(.systemGray5), lineWidth: isActive ? 2 : 1)
        )
    }

    @ViewBuilder
    private func bloomImageView(for entry: BloomCatalogEntry) -> some View {
        if let image = images[entry.cacheKey] {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .transition(.opacity)
        } else {
            ProgressView()
        }
    }

    private func loadImages() async {
        let renderer = BloomImageRenderer.shared
        for entry in catalog {
            guard images[entry.cacheKey] == nil else { continue }
            if let image = await renderer.render(entry: entry) {
                withAnimation(.easeIn(duration: 0.2)) {
                    images[entry.cacheKey] = image
                }
            }
        }
    }

    private func elementCacheKey(_ element: GardenElement) -> String {
        guard element.kind != .tree else { return "tree" }
        return "\(element.chapter.rawValue)-\(element.shape.rawValue)-\(element.isLegend)"
    }
}
