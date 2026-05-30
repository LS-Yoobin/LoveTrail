import SwiftUI
import SpriteKit

/// Hosts the SpriteKit living-room scene plus the care HUD: coins + need meters,
/// tap-a-bowl inspect cards, the laser-pointer play toggle, and reward feedback.
struct PetRoomView: View {
    let skin: CatSkin
    @ObservedObject var viewModel: PetViewModel
    var onChangePet: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scene: PetRoomScene?
    @State private var inspect: PetRoomScene.RoomProp?
    @State private var selectedStat: PetNeedStat?
    @State private var isPlaying = false
    @State private var playProgress: TimeInterval = 0
    @State private var playRewardClaimed = false

    @State private var toast: String?
    @State private var coinBurst: (amount: Int, id: UUID)?
    @State private var showMarket = false
    @State private var isCustomizing = false
    @State private var showMomentPicker = false
    @State private var customizeSnapshot: [String: NormalizedPoint] = [:]
    @State private var showCustomizeExitPrompt = false

    var body: some View {
        GeometryReader { geo in
            // SpriteView (Metal) can obscure sibling ZStack content, so modals
            // and bottom controls use `.overlay`, which draws above the scene.
            sceneView(geo: geo)
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    if isCustomizing {
                        saveRoomButton
                            .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                    } else {
                        VStack(spacing: 10) {
                            if isPlaying {
                                laserPlayProgressBar
                                Text("Drag the laser to fill the bar")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            playButton
                        }
                        .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                    }
                }
                .overlay(alignment: .center) {
                    if let burst = coinBurst {
                        Text("+\(burst.amount) 🪙")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(BabyTownTheme.accentDeep)
                            .shadow(color: .white, radius: 2)
                            .id(burst.id)
                            .offset(y: -130)
                    }
                    if let toast {
                        Text(toast)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color.black.opacity(0.78), in: Capsule())
                            .offset(y: 40)
                    }
                }
                .overlay {
                    if let prop = inspect {
                        ZStack {
                            Color.black.opacity(0.25).ignoresSafeArea()
                                .onTapGesture { inspect = nil }
                            BowlInspectCard(prop: prop,
                                            hunger: viewModel.hunger,
                                            thirst: viewModel.thirst,
                                            litter: viewModel.litter,
                                            foodServings: viewModel.foodServings,
                                            onAction: { performInspectAction(prop) },
                                            onClose: { inspect = nil })
                                .transition(.scale.combined(with: .opacity))
                        }
                    } else if let stat = selectedStat {
                        ZStack {
                            Color.black.opacity(0.25).ignoresSafeArea()
                                .onTapGesture { selectedStat = nil }
                            PetStatDetailCard(stat: stat,
                                              value: statValue(stat),
                                              onClose: { selectedStat = nil })
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
        }
        .navigationTitle(skin.petName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isCustomizing {
                    Button("Cancel") {
                        requestExitCustomize()
                    }
                    .font(.system(size: 17))
                } else {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                    }
                }
            }
            if !isCustomizing {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showMarket = true
                        } label: {
                            Image(systemName: "storefront.fill")
                                .font(.system(size: 18))
                        }
                        .accessibilityLabel("Market")

                        Menu {
                            Button {
                                beginCustomizeRoom()
                            } label: {
                                Label("Customize Room", systemImage: "square.dashed")
                            }
                            Button("Choose a different pet", systemImage: "arrow.triangle.2.circlepath", action: onChangePet)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Do you want to save before you leave?",
            isPresented: $showCustomizeExitPrompt,
            titleVisibility: .visible
        ) {
            Button("Yes") {
                saveCustomizeRoom()
            }
            Button("No", role: .destructive) {
                discardCustomizeChanges()
            }
        }
        .safeAreaInset(edge: .top, spacing: 8) {
            if isCustomizing {
                customizeBanner
            } else {
                TimelineView(.periodic(from: .now, by: 5)) { _ in
                    PetHUDView(coins: viewModel.coins,
                               hunger: viewModel.hunger,
                               thirst: viewModel.thirst,
                               litter: viewModel.litter,
                               happiness: viewModel.happiness) { stat in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedStat = stat
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showMarket) {
            PetMarketSheet(viewModel: viewModel) {
                showMomentPicker = true
            }
        }
        .sheet(isPresented: $showMomentPicker) {
            PetMomentGalleryPickerSheet { momentID in
                viewModel.setPictureFrameMoment(momentID)
                refreshRoomLayout()
            }
        }
        .onChange(of: viewModel.lastAward?.id) { _, _ in
            if let award = viewModel.lastAward { triggerCoinBurst(award.amount) }
        }
        .onChange(of: viewModel.roomLayout) { _, _ in
            refreshRoomLayout()
        }
    }

    private var customizeBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Customize Room")
                    .font(.system(size: 14, weight: .bold))
                Text("Drag bowls, furniture & the cat tree")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var customizeHasChanges: Bool {
        viewModel.roomLayout.propPositions != customizeSnapshot
    }

    // MARK: Scene

    private func sceneView(geo: GeometryProxy) -> some View {
        Group {
            if let scene {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
            } else {
                Color.clear
            }
        }
        .onAppear {
            if scene == nil {
                let s = PetRoomScene(skin: skin, size: geo.size)
                s.onTapProp = { prop in handleProp(prop) }
                s.onLayoutPositionsChanged = { positions in
                    viewModel.updatePropPositions(positions)
                }
                s.onPlayProgress = { progress in
                    DispatchQueue.main.async {
                        playProgress = progress
                    }
                }
                s.onPlayDurationMet = {
                    DispatchQueue.main.async {
                        guard !playRewardClaimed else { return }
                        playRewardClaimed = true
                        present(viewModel.completePlay())
                    }
                }
                scene = s
                refreshRoomLayout()
                if viewModel.ownsShopItem(PetShopCatalog.pictureFrameID),
                   viewModel.roomLayout.pictureFrameMomentID == nil {
                    showMomentPicker = true
                }
            }
        }
    }

    private func refreshRoomLayout() {
        scene?.applyRoomLayout(
            viewModel.roomLayout,
            frameImage: viewModel.pictureFrameImage()
        )
    }

    private func beginCustomizeRoom() {
        customizeSnapshot = viewModel.roomLayout.propPositions
        isCustomizing = true
        inspect = nil
        selectedStat = nil
        scene?.setCustomizeMode(true)
    }

    private func saveCustomizeRoom() {
        isCustomizing = false
        scene?.setCustomizeMode(false)
        customizeSnapshot = viewModel.roomLayout.propPositions
        showToast("Room layout saved")
    }

    private func exitCustomizeMode() {
        isCustomizing = false
        scene?.setCustomizeMode(false)
    }

    private func requestExitCustomize() {
        if customizeHasChanges {
            showCustomizeExitPrompt = true
        } else {
            exitCustomizeMode()
        }
    }

    private func discardCustomizeChanges() {
        viewModel.updatePropPositions(customizeSnapshot)
        refreshRoomLayout()
        exitCustomizeMode()
    }

    private var saveRoomButton: some View {
        Button(action: saveCustomizeRoom) {
            Label("Save Room", systemImage: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(BabyTownTheme.buttonGradient)
                .clipShape(Capsule())
                .shadow(color: BabyTownTheme.buttonShadow, radius: 10, y: 4)
        }
    }

    private var laserPlayProgressBar: some View {
        let fraction = min(1, playProgress / PetEconomy.playDurationRequired)
        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.12))
                    Capsule()
                        .fill(BabyTownTheme.buttonGradient)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 12)
            .padding(.horizontal, 32)

            Text(playProgressLabel(fraction: fraction))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(fraction >= 1 ? BabyTownTheme.accentDeep : .secondary)
        }
    }

    private func playProgressLabel(fraction: Double) -> String {
        if fraction >= 1 {
            return viewModel.canEarnPlayCoins()
                ? "Play complete! +\(PetEconomy.playCoinReward) 🪙"
                : "Play complete!"
        }
        return "Play time \(Int(ceil(playProgress))) / \(Int(PetEconomy.playDurationRequired))s"
    }

    private var playButton: some View {
        Button {
            if isPlaying {
                scene?.endLaserPlay()
                isPlaying = false
                playProgress = 0
                playRewardClaimed = false
            } else {
                playProgress = 0
                playRewardClaimed = false
                viewModel.beginPlaySession()
                scene?.startLaserPlay()
                isPlaying = true
            }
        } label: {
            Label(isPlaying ? "Done Playing" : "Play (Laser)",
                  systemImage: isPlaying ? "stop.fill" : "wand.and.rays")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(isPlaying ? AnyShapeStyle(Color.gray) : AnyShapeStyle(BabyTownTheme.buttonGradient))
                .clipShape(Capsule())
                .shadow(color: BabyTownTheme.buttonShadow, radius: 10, y: 4)
        }
    }

    // MARK: Interaction handling

    private func statValue(_ stat: PetNeedStat) -> Int {
        switch stat {
        case .hunger: return viewModel.hunger
        case .thirst: return viewModel.thirst
        case .litter: return viewModel.litter
        case .happiness: return viewModel.happiness
        }
    }

    private func handleProp(_ prop: PetRoomScene.RoomProp) {
        switch prop {
        case .cat:
            present(viewModel.pet())
            scene?.playReaction(.happy)
        case .foodBowl, .waterBowl, .litterBox:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { inspect = prop }
        }
    }

    private func performInspectAction(_ prop: PetRoomScene.RoomProp) {
        let result: CareResult
        switch prop {
        case .foodBowl:
            result = viewModel.refillAndBuyFood()
            if result.coinsAwarded > 0 { scene?.playReaction(.eat) }
        case .waterBowl:
            result = viewModel.fillWater()
        case .litterBox:
            result = viewModel.cleanLitter()
        case .cat:
            result = .none
        }
        present(result)
        withAnimation { inspect = nil }
    }

    // MARK: Feedback

    private func present(_ result: CareResult) {
        if let reason = result.blockedReason {
            showToast(reason)
        }
        // Coin awards animate via the lastAward onChange handler.
    }

    private func triggerCoinBurst(_ amount: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            coinBurst = (amount, UUID())
        }
        let id = coinBurst?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if coinBurst?.id == id { withAnimation { coinBurst = nil } }
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toast == message { withAnimation { toast = nil } }
        }
    }
}
