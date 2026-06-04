import SwiftUI
import SpriteKit
import GardenCore

/// The living garden rendered purely as an ambient backdrop (no banners, no
/// memory cards). When the user owns pets, each cat wanders the grass in a
/// transparent SpriteKit layer on top. Rebuilds when saved moments change so
/// new blooms appear after each save. Used behind the Couples Profile Page.
struct GardenBackgroundView: View {
    /// Timeline moments (one flower per calendar day) and love letters (trees).
    var moments: [Moment] = []
    var letters: [UserLetter] = []
    /// Hide the live cats while arranging stickers so static pet cutouts can be moved.
    var showsLivePet: Bool = true
    /// Skins for every owned pet; one roaming cat is shown per skin.
    var petSkins: [CatSkin] = []
    /// Matches home night mode (9 PM–6 AM LA); sky is transparent so `HomeBackgroundView` shows through.
    var isNightMode: Bool = false

    @State private var gardenScene: LoveGardenScene?
    @State private var petScenes: [CatSkin: PetRoomScene] = [:]
    @State private var builtPetSkins: [CatSkin] = []
    @State private var builtGardenToken: GardenRebuildToken?
    @State private var builtIsNightMode = false

    private var gardenRebuildToken: GardenRebuildToken {
        GardenRebuildToken(
            momentCount: moments.count,
            actIDs: GardenActMapper.bloomActIDs(moments: moments, letters: letters)
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
            .onAppear { updateScenes(size: geo.size) }
            .onChange(of: geo.size) { _, newSize in updateScenes(size: newSize) }
            .onChange(of: petSkins) { _, _ in updateScenes(size: geo.size) }
            .onChange(of: letters) { _, _ in updateScenes(size: geo.size) }
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
            let elements = GardenActMapper.composeElements(moments: moments, letters: letters)
            let season = DataPersistenceManager.shared.loadGardenState().season(now: Date())
            gardenScene = LoveGardenScene(
                size: size,
                elements: elements,
                season: season,
                isNightMode: isNightMode
            )
            builtGardenToken = token
            builtIsNightMode = isNightMode
        } else if let gardenScene, gardenScene.size != size {
            gardenScene.size = size
        }

        updatePetScenes(size: size)
    }

    private func updatePetScenes(size: CGSize) {
        guard showsLivePet, !petSkins.isEmpty else {
            petScenes = [:]
            builtPetSkins = []
            return
        }

        let spawnCount = petSkins.count
        if builtPetSkins != petSkins {
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

/// Rebuild when act IDs or total moment count changes (legend shrines use count).
private struct GardenRebuildToken: Equatable {
    let momentCount: Int
    let actIDs: [UUID]
}
