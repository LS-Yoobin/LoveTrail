import SwiftUI
import SpriteKit
import GardenCore

/// Live garden backdrop for the Home "Our Garden" card — blooms stay still while
/// clouds drift inside the clipped card bounds.
struct CoupleSpaceGardenBackground: View {
    let elements: [GardenElement]
    let season: GardenSeason

    @State private var scene: LoveGardenScene?
    @State private var builtToken: String?

    private var rebuildToken: String {
        let ids = elements.map(\.sourceID.uuidString).sorted().joined(separator: ",")
        return "\(ids)-\(season)"
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if let scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .allowsHitTesting(false)
                } else {
                    fallbackGradient
                }
            }
            .onAppear { updateScene(size: geo.size) }
            .onChange(of: geo.size) { _, newSize in updateScene(size: newSize) }
            .onChange(of: rebuildToken) { _, _ in
                builtToken = nil
                updateScene(size: geo.size)
            }
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.78, green: 0.90, blue: 0.98),
                Color(red: 0.66, green: 0.80, blue: 0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func updateScene(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let token = rebuildToken
        guard builtToken != token || scene == nil else {
            if let scene, scene.size != size {
                scene.size = size
            }
            return
        }

        let newScene = LoveGardenScene(
            size: size,
            elements: elements,
            season: season,
            isStaticSnapshot: true,
            animateClouds: true
        )
        scene = newScene
        builtToken = token
    }
}
