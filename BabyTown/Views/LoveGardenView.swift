import SwiftUI
import SpriteKit
import GardenCore

/// SwiftUI host for the Love Garden scene. Loads the couple's moments + letters,
/// grows the garden, shows the warm "welcome back" line when a resting garden is
/// revived, and surfaces a memory card when a bloom is tapped.
struct LoveGardenView: View {
    @State private var scene: LoveGardenScene?
    @State private var moments: [Moment] = []
    @State private var tappedMoment: Moment?
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
            .sheet(item: $tappedMoment) { moment in
                GardenMemoryCard(moment: moment)
                    .presentationDetents([.medium])
            }
        }
    }

    private func buildGarden(size: CGSize) {
        guard scene == nil else { return }
        let dpm = DataPersistenceManager.shared
        let loadedMoments = dpm.loadMoments()
        let letters = dpm.loadUserLetters()
        moments = loadedMoments

        let acts = GardenActMapper.acts(moments: loadedMoments, letters: letters)
        let elements = GardenComposer().compose(acts: acts)

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
        newScene.onTapElement = { id in
            tappedMoment = moments.first { $0.id == id }
        }
        scene = newScene
    }
}

/// Minimal memory card shown when a bloom is tapped (Slice 1).
private struct GardenMemoryCard: View {
    let moment: Moment

    var body: some View {
        VStack(spacing: 14) {
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
