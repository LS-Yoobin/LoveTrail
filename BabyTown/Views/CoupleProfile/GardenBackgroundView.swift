import SwiftUI
import SpriteKit
import GardenCore

/// The living garden rendered purely as an ambient backdrop (no banners, no
/// memory cards). When the user owns pets, each cat wanders the grass in a
/// transparent SpriteKit layer on top. Rebuilds when saved moments change so
/// new blooms appear after each save. Used behind the Couples Profile Page.
struct GardenBackgroundView: View {
    /// Timeline moments, special dates, and love letters that grow the garden.
    var moments: [Moment] = []
    var promptMemories: [PromptMemory] = []
    var letters: [UserLetter] = []
    var specialDates: [SpecialDate] = []
    var officialDate: Date?
    var firstMetDate: Date?
    /// Hide the live cats while arranging stickers so static pet cutouts can be moved.
    var showsLivePet: Bool = true
    /// Skins for every owned pet; one roaming cat is shown per skin.
    var petSkins: [CatSkin] = []
    /// Matches home night mode (9 PM–6 AM LA); sky is transparent so `HomeBackgroundView` shows through.
    var isNightMode: Bool = false

    @State private var gardenScene: LoveGardenScene?
    @State private var gardenElements: [GardenElement] = []
    @State private var tapPresentation: GardenTapPresentation?
    @State private var petScenes: [CatSkin: PetRoomScene] = [:]
    @State private var builtPetSkins: [CatSkin] = []
    @State private var builtGardenToken: GardenRebuildToken?
    @State private var builtIsNightMode = false

    private var gardenContext: GardenActMapper.Context {
        GardenActMapper.Context(
            moments: moments,
            promptMemories: promptMemories,
            letters: letters,
            specialDates: specialDates,
            officialDate: officialDate,
            firstMetDate: firstMetDate
        )
    }

    private var gardenRebuildToken: GardenRebuildToken {
        GardenRebuildToken(
            memoryClusterCount: GardenActMapper.gardenMilestoneCount(from: gardenContext),
            actIDs: GardenActMapper.bloomActIDs(context: gardenContext)
                .sorted { $0.uuidString < $1.uuidString }
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Opaque sky fill — the SpriteKit scene clears to transparent.
                (isNightMode ? Color.clear : Color(red: 0.78, green: 0.90, blue: 0.98))
                    .ignoresSafeArea()

                if let gardenScene {
                    SpriteView(scene: gardenScene)
                        .ignoresSafeArea()
                }

                if showsLivePet {
                    ForEach(petSkins, id: \.self) { skin in
                        if let scene = petScenes[skin] {
                            SpriteView(scene: scene, options: [.allowsTransparency])
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
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
            .onAppear { updateScenes(size: geo.size) }
            .onChange(of: geo.size) { _, newSize in updateScenes(size: newSize) }
            .onChange(of: petSkins) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: letters) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: promptMemories.count) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: specialDates) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: officialDate) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: firstMetDate) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: showsLivePet) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: isNightMode) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: gardenRebuildToken) { _, _ in updateScenes(size: geo.size) }
        }
    }

    private func updateScenes(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }

        let token = gardenRebuildToken
        let gardenNeedsBuild = gardenScene == nil
            || builtGardenToken != token
            || builtIsNightMode != isNightMode
        if gardenNeedsBuild {
            detachPetsFromGarden()
            let elements = GardenActMapper.composeElements(context: gardenContext)
            gardenElements = elements
            let season = DataPersistenceManager.shared.loadGardenState().season(now: Date())
            let newScene = LoveGardenScene(
                size: size,
                elements: elements,
                season: season,
                isNightMode: isNightMode
            )
            newScene.onTapElement = { id in handleBloomTap(id: id) }
            gardenScene = newScene
            builtGardenToken = token
            builtIsNightMode = isNightMode
        } else if let gardenScene, gardenScene.size != size {
            gardenScene.size = size
        }

        updatePetScenes(size: size)
        linkPetsToGarden()
    }

    private func handleBloomTap(id: UUID) {
        guard let element = gardenElements.first(where: { $0.sourceID == id }) else { return }
        let sourceContext = moments.first(where: { $0.id == id }).map {
            FlowerSourceContext(placeName: $0.placeName, date: $0.dateTaken)
        }
        tapPresentation = .flower(element, gardenElements, sourceContext)
    }

    private func detachPetsFromGarden() {
        for scene in petScenes.values {
            scene.detachCatFromGardenHost()
        }
    }

    private func linkPetsToGarden() {
        guard let gardenScene else { return }
        for scene in petScenes.values {
            scene.gardenHost = gardenScene
            scene.attachCatToGardenHostIfNeeded()
        }
    }

    private func updatePetScenes(size: CGSize) {
        guard showsLivePet, !petSkins.isEmpty else {
            detachPetsFromGarden()
            petScenes = [:]
            builtPetSkins = []
            return
        }

        let spawnCount = petSkins.count
        if builtPetSkins != petSkins {
            detachPetsFromGarden()
            var scenes: [CatSkin: PetRoomScene] = [:]
            for (index, skin) in petSkins.enumerated() {
                let pet = PetRoomScene(skin: skin, size: size)
                pet.isGardenBackdrop = true
                pet.gardenSpawnIndex = index
                pet.gardenSpawnCount = spawnCount
                scenes[skin] = pet
            }
            petScenes = scenes
            builtPetSkins = petSkins
        } else {
            for (index, skin) in petSkins.enumerated() {
                guard let scene = petScenes[skin] else { continue }
                scene.gardenSpawnIndex = index
                scene.gardenSpawnCount = spawnCount
                if scene.size != size {
                    scene.size = size
                }
            }
        }
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

/// Rebuild when act IDs or memory-cluster count changes (milestone shrines use clusters).
private struct GardenRebuildToken: Equatable {
    let memoryClusterCount: Int
    let actIDs: [UUID]
}
