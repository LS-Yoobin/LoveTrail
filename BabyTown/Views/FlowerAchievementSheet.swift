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

    private enum BloomImageRole {
        case hero
        case grid
    }

    private func bloomImageSize(for entry: BloomCatalogEntry, role: BloomImageRole) -> CGSize {
        if entry.isTree {
            switch role {
            case .hero: return CGSize(width: 140, height: 195)
            case .grid: return CGSize(width: 70, height: 98)
            }
        }
        switch role {
        case .hero: return CGSize(width: 140, height: 160)
        case .grid: return CGSize(width: 70, height: 80)
        }
    }

    private var subpageBackground: some View {
        CoupleProfileSubpageBackground()
    }

    var body: some View {
        ZStack {
            subpageBackground

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Capsule()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 36, height: 4)
                        Text("Garden Blooms")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 12)

                    if let entry = tappedEntry {
                        heroCard(entry: entry)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Collection")
                            .font(.headline)
                            .foregroundStyle(.white)
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
        }
        .presentationBackground { subpageBackground }
        .task { await loadImages() }
    }

    @ViewBuilder
    private func heroCard(entry: BloomCatalogEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    bloomImageView(for: entry)
                        .frame(
                            width: bloomImageSize(for: entry, role: .hero).width,
                            height: bloomImageSize(for: entry, role: .hero).height
                        )
                    if entry.isLegend {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundStyle(.yellow)
                            .padding(6)
                    }
                }

                Text(entry.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(entry.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                if let ctx = sourceContext {
                    earnedCaption(ctx)
                }
            }
            .padding(20)

            if entry.ownedCount > 0 {
                bloomCountBadge(entry.ownedCount)
                    .padding(14)
            }
        }
        .background(CoupleProfileScrollCardBackground(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow, lineWidth: 2))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func earnedCaption(_ ctx: FlowerSourceContext) -> some View {
        if let place = ctx.placeName {
            (Text("Earned · \(place) · ") + Text(ctx.date, style: .date))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        } else {
            (Text("Earned · ") + Text(ctx.date, style: .date))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private func gridCell(entry: BloomCatalogEntry, isActive: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    bloomImageView(for: entry)
                        .frame(
                            width: bloomImageSize(for: entry, role: .grid).width,
                            height: bloomImageSize(for: entry, role: .grid).height
                        )
                        .saturation(entry.isEarned ? 1.0 : 0.0)

                    if entry.isEarned {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, .green)
                            .offset(x: 4, y: 4)
                    } else {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, Color.white.opacity(0.45))
                            .offset(x: 4, y: 4)
                    }
                }

                Text(entry.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if !entry.isEarned {
                    Text(entry.unlockCondition)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)

            if entry.ownedCount > 0 {
                bloomCountBadge(entry.ownedCount)
                    .padding(8)
            }
        }
        .background(CoupleProfileScrollCardBackground(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.yellow : Color.white.opacity(0.35), lineWidth: isActive ? 2 : 1)
        )
    }

    private func bloomCountBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.55), in: Capsule())
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
