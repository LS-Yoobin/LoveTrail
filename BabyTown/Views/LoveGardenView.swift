import SwiftUI
import SpriteKit
import GardenCore

/// SwiftUI host for the Love Garden scene. Loads the couple's moments + letters,
/// grows the garden, shows the warm "welcome back" line when a resting garden is
/// revived, and surfaces a memory card when a bloom is tapped.
struct LoveGardenView: View {
    @State private var scene: LoveGardenScene?
    @State private var moments: [Moment] = []
    @State private var gardenElements: [GardenElement] = []
    @State private var tapPresentation: GardenTapPresentation?
    @State private var revivalMessage: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    Color(red: 0.78, green: 0.90, blue: 0.98).ignoresSafeArea()
                }

                if let revivalMessage {
                    VStack {
                        Text(revivalMessage)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 12)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear { buildGarden(size: geo.size) }
            .sheet(item: $tapPresentation) { presentation in
                switch presentation {
                case .moment(let moment, let lore):
                    GardenMemoryCard(moment: moment, lore: lore)
                        .presentationDetents([.medium])
                case .legend(let lore):
                    LegendBloomCard(lore: lore)
                        .presentationDetents([.height(220)])
                }
            }
        }
    }

    private func buildGarden(size: CGSize) {
        guard scene == nil else { return }
        let dpm = DataPersistenceManager.shared
        let loadedMoments = dpm.loadMoments()
        moments = loadedMoments

        let context = GardenActMapper.persistedContext(moments: loadedMoments, dpm: dpm)
        let elements = GardenActMapper.composeElements(context: context)
        gardenElements = elements

        // Register today's visit; reflect & persist any warm revival.
        let now = Date()
        let stored = dpm.loadGardenState()
        let storedSeason = stored.season(now: now)
        let result = stored.registering(actAt: now)
        dpm.saveGardenState(result.state)
        if result.didRevive {
            withAnimation { revivalMessage = "Welcome back — your garden missed you 🌱" }
        }

        let newScene = LoveGardenScene(size: size, elements: elements, season: storedSeason)
        newScene.onTapElement = { id in handleBloomTap(id: id) }
        scene = newScene
    }

    private func handleBloomTap(id: UUID) {
        guard let element = gardenElements.first(where: { $0.sourceID == id }),
              let lore = BloomChapterResolver.lore(for: element) else { return }
        if element.isLegend || element.kind != .flower {
            tapPresentation = .legend(lore)
        } else if let moment = moments.first(where: { $0.id == id }) {
            tapPresentation = .moment(moment, lore)
        } else {
            tapPresentation = .legend(lore)
        }
    }
}

private enum GardenTapPresentation: Identifiable {
    case moment(Moment, BloomLore)
    case legend(BloomLore)

    var id: String {
        switch self {
        case .moment(let moment, _): return "moment-\(moment.id.uuidString)"
        case .legend(let lore): return "legend-\(lore.displayName)"
        }
    }
}

/// Minimal memory card shown when a bloom is tapped (Slice 1).
struct GardenMemoryCard: View {
    let moment: Moment
    var lore: BloomLore?

    var body: some View {
        VStack(spacing: 14) {
            if let lore {
                VStack(spacing: 4) {
                    Text(lore.displayName)
                        .font(.headline)
                    Text(lore.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Image(uiImage: moment.thumbnail)
                .resizable().scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if let place = moment.placeName, !place.isEmpty {
                Label(place, systemImage: "mappin.and.ellipse").font(.subheadline)
            }
            if let caption = moment.caption, !caption.isEmpty {
                Text(caption).font(.body).multilineTextAlignment(.center)
            }
            Text(moment.dateTaken, style: .date).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

/// Celebration card for milestone shrine blooms (no photo).
struct LegendBloomCard: View {
    let lore: BloomLore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.yellow, .purple)
            Text(lore.displayName)
                .font(.title2.weight(.semibold))
            Text(lore.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}
