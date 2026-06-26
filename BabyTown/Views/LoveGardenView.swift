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
                case .flower(let element, let elements, let context):
                    FlowerAchievementSheet(
                        tappedElement: element,
                        gardenElements: elements,
                        sourceContext: context
                    )
                    .presentationDetents([.large])
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
        guard let element = gardenElements.first(where: { $0.sourceID == id }) else { return }
        var sourceContext: FlowerSourceContext?
        if let moment = moments.first(where: { $0.id == id }) {
            sourceContext = FlowerSourceContext(placeName: moment.placeName, date: moment.dateTaken)
        }
        tapPresentation = .flower(element, gardenElements, sourceContext)
    }
}

private enum GardenTapPresentation: Identifiable {
    case flower(GardenElement, [GardenElement], FlowerSourceContext?)

    var id: String {
        switch self {
        case .flower(let element, _, _): return "flower-\(element.sourceID.uuidString)"
        }
    }
}

