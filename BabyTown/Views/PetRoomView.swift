import SwiftUI
import SpriteKit
import Combine

/// Hosts the SpriteKit living-room scene plus the care HUD: coins + need meters,
/// tap-a-bowl inspect cards, the laser-pointer play toggle, and reward feedback.
struct PetRoomView: View {
    let skin: CatSkin
    @ObservedObject var viewModel: PetViewModel
    var onChangePet: () -> Void
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var environmentDismiss

    @State private var scene: PetRoomScene?
    /// Tracks which pet the SpriteKit scene was built for (guards layout refresh).
    @State private var sceneSkin: CatSkin?
    @State private var inspect: PetRoomScene.RoomProp?
    @State private var showStatsDetail = false
    @State private var showPetProfile = false
    @State private var isPlaying = false
    @State private var playProgress: TimeInterval = 0
    @State private var playRewardClaimed = false

    @State private var toast: String?
    @State private var coinBurst: (amount: Int, id: UUID)?
    @State private var showMarket = false
    @State private var marketInitialCategory: PetShopCategory = .catTrees
    @State private var showOwnedItems = false
    @State private var ownedItemsInitialCategory: PetShopCategory = .catTrees
    @State private var isCustomizing = false
    @State private var isInspectingPictureFrame = false
    @State private var isPictureFrameInspectAnimating = false
    @State private var showMomentPicker = false
    @State private var momentPickerFrameID: String?
    @State private var showingPictureFrameMomentViewer = false
    @State private var pictureFrameViewerMoments: [Moment] = []
    @State private var pictureFrameViewerInitialIndex = 0
    @State private var customizeSnapshot: [String: NormalizedPoint] = [:]
    @State private var showCustomizeExitPrompt = false
    @State private var showRenameSheet = false
    @State private var selectedCustomizePropKey: String?
    @State private var selectedPropActionAnchor: CGPoint?
    @State private var toiletPaperMessage: String?
    @State private var showWelcomeTutorial = false

    @State private var isTrickMode = false
    @State private var showTrickBook = false
    @State private var isDraggingSnack = false
    @StateObject private var speechRecognizer = PetSpeechCommandRecognizer()
    @State private var trickProgressAlert: (trick: PetTrick, kind: PetTrickProgressAlertView.Kind, id: UUID)?
    @State private var voiceTrickCompletion: (trick: PetTrick, id: UUID)?
    @State private var voiceTrickCompletionHapticTick = 0
    @State private var isCleaningLitterBox = false
    @State private var showLitterScooper = false
    @State private var litterScooperCenter = CGPoint.zero
    @State private var litterScooperOpacity = 0.0
    @State private var litterCleanProgress: TimeInterval = 0
    @State private var litterDragLastTimestamp: Date?
    @State private var litterDragLastScrubPoint: CGPoint?
    @State private var litterScooperDragGrabOffset: CGSize?
    @State private var lastKnownLitterDirty = false
    @State private var isRefillingFood = false
    @State private var showFoodRefillOverlay = false
    @State private var selectedRefillFoodID = "food_dry_kibble"
    @State private var refillFoodCenter = CGPoint.zero
    @State private var refillFoodOpacity = 0.0
    @State private var refillProgress: TimeInterval = 0
    @State private var refillHoldTimer: Timer?
    private let litterScheduleTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let litterCleanDurationRequired: TimeInterval = PetEconomy.careTaskDurationRequired
    private let refillDurationRequired: TimeInterval = PetEconomy.careTaskDurationRequired
    private let litterScooperAssetName = "litter_scooper"
    private let litterScooperSize = CGSize(width: 110, height: 82.5)
    /// Scoop/scrub hotspot to the right of the finger (overlay coordinates).
    private let litterScooperScrubOffsetFromTouch = CGSize(width: 56, height: -6)
    /// Let the scooper travel partially offscreen so the scoop can still reach
    /// the litter box edges without feeling "stuck" at screen bounds.
    private let litterScooperHorizontalOverflow: CGFloat = 44
    private let litterScooperVerticalOverflow: CGFloat = 24

    // MARK: Plant watering mini-game
    @State private var isWateringPlant = false
    @State private var wateringPlantProp: PetRoomScene.RoomProp?
    @State private var showWateringCan = false
    @State private var wateringCanCenter = CGPoint.zero
    @State private var wateringCanOpacity = 0.0
    @State private var wateringCanFacesLeft = true
    @State private var wateringProgress: TimeInterval = 0
    @State private var wateringDragLastTimestamp: Date?
    private let wateringDurationRequired: TimeInterval = PetEconomy.plantWaterDurationRequired
    private let wateringCanSize = CGSize(width: 124, height: 112)
    /// Base offsets for the default (spout-left) can orientation.
    private let wateringCanSpoutOffsetLeft = CGSize(width: -46, height: 22)
    /// Touch anchor near the top opening of the can body (not the spout).
    private let wateringCanTopAnchorOffsetLeft = CGSize(width: 18, height: -16)
    private let wateringOverflow: CGFloat = 40

    /// Active room pet; follows `viewModel.adoptedSkin` when the HUD switcher changes pets.
    private var activeSkin: CatSkin {
        viewModel.adoptedSkin ?? skin
    }

    private var petDisplayName: String {
        viewModel.displayName(for: activeSkin)
    }

    private var showingToiletPaperModal: Bool {
        toiletPaperMessage != nil
    }

    private var availableRefillFoodItems: [PetShopItem] {
        PetShopCatalog.items(in: .catFood)
    }
    private static let transparentAssetCache = NSCache<NSString, UIImage>()

    var body: some View {
        GeometryReader { geo in
            // SpriteView (Metal) can obscure sibling ZStack content, so modals
            // and bottom controls use `.overlay`, which draws above the scene.
            sceneView(geo: geo)
                .ignoresSafeArea()
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
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.78), in: Capsule())
                    }
                    if let alert = trickProgressAlert {
                        PetTrickProgressAlertView(trick: alert.trick, kind: alert.kind)
                            .id(alert.id)
                            .offset(y: -100)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                    if let completed = voiceTrickCompletion {
                        voiceTrickCompletionPill(trick: completed.trick)
                            .id(completed.id)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .overlay {
                    if showLitterScooper {
                        litterScooperOverlay
                    } else if showFoodRefillOverlay {
                        foodRefillOverlay
                    } else if showWateringCan {
                        wateringCanOverlay
                    }
                }
                .overlay(alignment: .bottom) {
                    Group {
                        if isInspectingPictureFrame {
                            if !showMomentPicker, !showingPictureFrameMomentViewer {
                                pictureFrameInspectBottomBar
                            }
                        } else if isCustomizing {
                            customizeBottomBar
                        } else if isTrickMode {
                            trickModeBottomBar
                        } else {
                            playModeBottomBar
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, bottomBarPadding(safeArea: geo.safeAreaInsets.bottom))
                }
                .overlay {
                    if showingPictureFrameMomentViewer {
                        pictureFrameMomentViewerOverlay
                    }
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.82), value: voiceTrickCompletion?.id)
                .animation(.spring(response: 0.34, dampingFraction: 0.82), value: trickProgressAlert?.id)
                .successHapticIfAvailable(trigger: voiceTrickCompletionHapticTick)
                .overlay {
                    if let message = toiletPaperMessage {
                        ZStack {
                            Color.black.opacity(0.25).ignoresSafeArea()
                                .onTapGesture {
                                    toiletPaperMessage = nil
                                }
                            VStack(spacing: 16) {
                                VStack(spacing: 10) {
                                    Image("prop_toilet_paper")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 74, height: 74)
                                        .frame(maxWidth: .infinity)

                                    Text(message)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }

                                Button {
                                    toiletPaperMessage = nil
                                    viewModel.throwAwayActiveToiletPaperMess()
                                    scene?.setToiletPaperMessVisible(viewModel.hasActiveToiletPaperMess())
                                } label: {
                                    Text("Throw Away")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(BabyTownTheme.accentDeep, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 22)
                            .frame(maxWidth: 320)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(.white.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 14, y: 7)
                            .transition(.scale.combined(with: .opacity))
                        }
                    } else if let prop = inspect {
                        ZStack {
                            Color.black.opacity(0.25).ignoresSafeArea()
                                .onTapGesture { inspect = nil }
                            BowlInspectCard(
                                prop: prop,
                                hunger: viewModel.hunger,
                                thirst: viewModel.thirst,
                                litter: viewModel.litter,
                                foodServings: viewModel.foodServings,
                                litterImage: PetShopCatalog.equippedLitterCleanCrop(
                                    equippedItemID: viewModel.equippedLitterItemID
                                ),
                                plantStatusText: plantStatusText(for: prop),
                                onAction: { performInspectAction(prop) },
                                onSecondaryAction: prop == .foodBowl ? { openMarket(category: .catFood) } : nil,
                                onClose: { inspect = nil }
                            )
                                .transition(.scale.combined(with: .opacity))
                        }
                    } else if showStatsDetail {
                        ZStack {
                            Color.black.opacity(0.25).ignoresSafeArea()
                                .onTapGesture { showStatsDetail = false }
                            PetStatDetailCard(
                                hunger: viewModel.hunger,
                                thirst: viewModel.thirst,
                                litter: viewModel.litter,
                                happiness: viewModel.happiness,
                                onClose: { showStatsDetail = false }
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    } else if showPetProfile {
                        ZStack {
                            Color.black.opacity(0.25).ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showPetProfile = false
                                    }
                                }
                            PetProfileCard(
                                skin: activeSkin,
                                displayName: petDisplayName,
                                birthDate: DataPersistenceManager.shared.loadOrCreateAppJoinedDate(),
                                smartnessLevel: viewModel.smartMeterLevel,
                                knownTricks: knownUnlockedTricks,
                                onClose: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showPetProfile = false
                                    }
                                },
                                onRenameName: openRenameSheet
                            )
                            .offset(y: -petRoomModalCenterOffset(bottomSafeArea: geo.safeAreaInsets.bottom))
                            .transition(.scale.combined(with: .opacity))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isCustomizing {
                    Button("Cancel") {
                        requestExitCustomize()
                    }
                    .font(.system(size: 17))
                } else if !isInspectingPictureFrame, !showingPictureFrameMomentViewer {
                    Button(action: close) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                    }
                }
            }
            if isCustomizing {
                ToolbarItem(placement: .topBarTrailing) {
                    marketToolbarButton
                }
            } else if !isInspectingPictureFrame {
                ToolbarItem(placement: .principal) {
                    Button {
                        inspect = nil
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showPetProfile = true
                        }
                    } label: {
                        PetNameTagLabel(name: petDisplayName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(petDisplayName), pet profile")
                    .accessibilityHint("Opens profile with name, birth date, breed, and origin story")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        marketToolbarButton
                        Button(action: beginCustomizeRoom) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 18))
                        }
                        .accessibilityLabel("Customize Room")
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
            } else if isTrickMode {
                trickModeBanner
            } else if isPlaying {
                VStack(spacing: 8) {
                    laserPlayBanner
                    playToyHotbar
                        .padding(.horizontal, 16)
                }
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if isRefillingFood {
                VStack(spacing: 8) {
                    refillModeBanner
                    refillFoodHotbar
                        .padding(.horizontal, 16)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if isCleaningLitterBox {
                litterModeBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if isWateringPlant {
                wateringModeBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if !isInspectingPictureFrame && !isRefillingFood {
                TimelineView(.periodic(from: .now, by: 5)) { _ in
                    PetHUDView(
                        coins: viewModel.coins,
                        hunger: viewModel.hunger,
                        thirst: viewModel.thirst,
                        litter: viewModel.litter,
                        happiness: viewModel.happiness,
                        currentSkin: activeSkin,
                        ownedSkins: viewModel.ownedSkins,
                        onInventoryTap: { openOwnedItems() },
                        onStatsTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showStatsDetail = true
                            }
                        },
                        onSelectPet: { newSkin in
                            guard newSkin != viewModel.adoptedSkin else { return }
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.visit(newSkin)
                            }
                        },
                        onAdoptMore: onChangePet,
                        checkInStreak: viewModel.checkInStreak,
                        checkedInToday: viewModel.checkedInToday
                    )
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isPlaying)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isRefillingFood)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isInspectingPictureFrame)
        .animation(.easeInOut(duration: 0.25), value: showingPictureFrameMomentViewer)
        .sheet(isPresented: $showMarket) {
            PetMarketSheet(viewModel: viewModel, category: $marketInitialCategory) {
                openPictureFramePicker(for: viewModel.activePictureFrameID())
            }
        }
        .sheet(isPresented: $showOwnedItems) {
            PetOwnedItemsSheet(viewModel: viewModel, category: $ownedItemsInitialCategory) {
                openPictureFramePicker(for: viewModel.activePictureFrameID())
            }
        }
        .sheet(isPresented: $showMomentPicker) {
            pictureFramePickerSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showMomentPicker) { _, isPresented in
            if !isPresented {
                momentPickerFrameID = nil
            }
        }
        .sheet(isPresented: $showTrickBook) {
            PetTrickBookSheet(viewModel: viewModel) {
                showTrickBook = false
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSheetContent
        }
        .onChange(of: showTrickBook) { _, isOpen in
            guard isTrickMode else { return }
            if isOpen {
                speechRecognizer.stop()
            } else {
                speechRecognizer.start()
            }
        }
        .onChange(of: viewModel.lastAward?.id) { _, _ in
            if let award = viewModel.lastAward { triggerCoinBurst(award.amount) }
        }
        .onChange(of: viewModel.roomLayout) { _, _ in
            guard viewModel.adoptedSkin == sceneSkin else { return }
            refreshRoomLayout()
        }
        .onChange(of: showMarket) { _, _ in
            syncSceneSheetPause()
        }
        .onChange(of: showOwnedItems) { _, _ in
            syncSceneSheetPause()
        }
        .onChange(of: showWelcomeTutorial) { _, _ in
            syncSceneSheetPause()
        }
        .onChange(of: viewModel.selectedPlayToyID) { _, selectedToyID in
            guard isPlaying else { return }
            scene?.setPlayToySelection(selectedToyID)
        }
        .onDisappear {
            if isTrickMode { exitTrickMode() }
            stopRefillHoldTimer(resetProgress: false)
        }
        .onReceive(litterScheduleTicker) { _ in
            syncLitterBoxState()
            syncNeedThoughtBubble()
        }
        .overlay {
            if showWelcomeTutorial {
                PetRoomWelcomeTutorialView(
                    petName: petDisplayName,
                    petPortraitAsset: activeSkin.profileSitAsset,
                    onFinish: dismissWelcomeTutorial
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showWelcomeTutorial)
        .toolbar(showWelcomeTutorial ? .hidden : .visible, for: .navigationBar)
    }

    private var marketToolbarButton: some View {
        Button {
            openMarket()
        } label: {
            Image(systemName: "storefront.fill")
                .font(.system(size: 18))
        }
        .accessibilityLabel("Market")
    }

    private var inventoryCoinPillButton: some View {
        Button(action: { openOwnedItems() }) {
            HStack(spacing: 6) {
                PetCoinIcon(size: 22)
                Text("\(viewModel.coins)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("My items")
        .accessibilityValue("\(viewModel.coins) coins")
        .accessibilityHint("Opens décor you own for this room")
    }

    /// Level badge tracks the cat in scene space (same anchor logic as need-thought bubbles).
    private var catLevelPillOverlay: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            GeometryReader { overlayGeo in
                if let anchor = scene?.catHeadAnchorPoint() {
                    PetLevelPill(
                        level: viewModel.smartMeterLevel,
                        onLongPress: toggleSecondPetAdoptionBypassIfNeeded
                    )
                    .position(
                        viewPoint(
                            fromScene: anchor,
                            geo: overlayGeo,
                            sceneSize: scene?.size ?? overlayGeo.size
                        )
                    )
                }
            }
        }
        .allowsHitTesting(true)
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

    private var laserPlayBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.rays")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Text("Laser Play")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Spacer()
            }
            laserPlayProgressBar
            Text("Drag the laser to fill the bar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var refillModeBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Refill the food bowl")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            refillModeProgressBar
            Text("Select food below, then drag/tap to place it in the bowl")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var refillModeProgressBar: some View {
        let fraction = min(1, refillProgress / refillDurationRequired)
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule()
                        .fill(BabyTownTheme.buttonGradient)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 9)
            Text("\(Int(refillProgress.rounded(.down))) / \(Int(refillDurationRequired))s")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var litterModeBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Text("Clean Litter Box")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Spacer()
            }
            litterCleaningProgressBar
            Text("Drag the scooper over the litter box to clean it")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var trickModeBanner: some View {
        let listening = speechRecognizer.status == .listening
        return VStack(spacing: 10) {
            PetSmartMeterBar(
                level: viewModel.smartMeterLevel,
                progressFraction: viewModel.smartMeterProgressFraction(),
                compact: true
            )

            HStack(spacing: 12) {
            // Glowing mic that swells with the live input level, ringed by a pulse,
            // so it visibly reacts to the user's voice.
            ZStack {
                Circle()
                    .fill(listening
                          ? AnyShapeStyle(BabyTownTheme.accentGradient)
                          : AnyShapeStyle(Color.orange.opacity(0.85)))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(BabyTownTheme.accent.opacity(listening ? 0.5 : 0), lineWidth: 3)
                            .scaleEffect(1 + speechRecognizer.audioLevel * 0.7)
                            .opacity(listening ? Double(1 - speechRecognizer.audioLevel) : 0)
                    )
                    .scaleEffect(1 + (listening ? speechRecognizer.audioLevel * 0.22 : 0))
                Image(systemName: listening ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .animation(.easeOut(duration: 0.12), value: speechRecognizer.audioLevel)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Trick Training")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BabyTownTheme.accentDeep)
                    if listening {
                        MicLevelBars(level: speechRecognizer.audioLevel)
                    }
                }
                Group {
                    switch speechRecognizer.status {
                    case .listening:
                        if let transcript = speechRecognizer.liveTranscript, !transcript.isEmpty {
                            Text("\"\(transcript)\"")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BabyTownTheme.accentDeep)
                        } else {
                            Text("Listening…")
                        }
                    case .requestingPermission:
                        Text("Setting up microphone…")
                    case .unavailable(let message):
                        Text(message)
                    case .idle:
                        if showTrickBook {
                            Text("Mic paused while viewing Tricks")
                        } else {
                            Text("Tap Exit to leave training")
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    listening && (speechRecognizer.liveTranscript ?? "").isEmpty
                        ? .white
                        : Color(red: 0.22, green: 0.2, blue: 0.22)
                )
                .lineLimit(2)
            }
            Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func voiceTrickCompletionPill(trick: PetTrick) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
            Text("\(trick.displayName) completed!")
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(
            Capsule()
                .fill(Color(red: 0.12, green: 0.52, blue: 0.28))
                .shadow(color: Color(red: 0.12, green: 0.52, blue: 0.28).opacity(0.35), radius: 12, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
    }

    private var customizeHasChanges: Bool {
        viewModel.roomLayout.propPositions != customizeSnapshot
    }

    // MARK: Trick mode

    private var customizeBottomBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            saveRoomButton
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func customizePropActionsBar(for key: String) -> some View {
        HStack(spacing: 10) {
            customizePropActionButton(title: "Flip", icon: "arrow.left.and.right") {
                scene?.flipCustomizeProp(key)
            }
            if scene?.isStashableProp(key) == true {
                customizePropActionButton(title: "Stash", icon: "archivebox.fill") {
                    scene?.stashCustomizeProp(key)
                    selectedCustomizePropKey = nil
                    selectedPropActionAnchor = nil
                }
            }
        }
    }

    private func customizePropActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.18, green: 0.18, blue: 0.21).opacity(0.94), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var pictureFrameMomentViewerOverlay: some View {
        MomentPhotoViewer(
            moments: pictureFrameViewerMoments,
            initialIndex: pictureFrameViewerInitialIndex,
            onDismiss: {
                withAnimation(.easeOut(duration: 0.25)) {
                    showingPictureFrameMomentViewer = false
                }
            },
            onUpdateMoments: { updatedMoments in
                var allMoments = DataPersistenceManager.shared.loadMoments()
                for moment in updatedMoments {
                    if let index = allMoments.firstIndex(where: { $0.id == moment.id }) {
                        allMoments[index] = moment
                    }
                }
                DataPersistenceManager.shared.saveMoments(allMoments)
                refreshRoomLayout()
            },
            onDeleteMoment: { moment in
                var allMoments = DataPersistenceManager.shared.loadMoments()
                allMoments.removeAll { $0.id == moment.id }
                DataPersistenceManager.shared.saveMoments(allMoments)
                refreshRoomLayout()
            }
        )
        .transition(.opacity)
        .zIndex(2)
    }

    private var pictureFrameInspectBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                scene?.exitPictureFrameInspect()
            } label: {
                Text("Exit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.18, green: 0.18, blue: 0.21).opacity(0.94), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                openPictureFramePicker(for: viewModel.activePictureFrameID())
            } label: {
                Text("Replace")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BabyTownTheme.buttonGradient)
                    .clipShape(Capsule())
                    .shadow(color: BabyTownTheme.buttonShadow, radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private var playModeBottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if isRefillingFood {
                    Spacer(minLength: 0)
                    doneRefillButton
                    Spacer(minLength: 0)
                } else if isCleaningLitterBox {
                    Spacer(minLength: 0)
                    cancelLitterCleaningButton
                    Spacer(minLength: 0)
                } else if isWateringPlant {
                    Spacer(minLength: 0)
                    cancelWateringButton
                    Spacer(minLength: 0)
                } else if isPlaying {
                    Spacer(minLength: 0)
                    playButton
                    Spacer(minLength: 0)
                } else {
                    trickTrainingEntryButton
                    playButton
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isPlaying)
    }

    private var refillFoodHotbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableRefillFoodItems) { item in
                    refillFoodChip(item: item, selected: selectedRefillFoodID == item.id) {
                        selectedRefillFoodID = item.id
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refillFoodChip(
        item: PetShopItem,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Group {
                    if let imageName = item.imageName, UIImage(named: imageName) != nil {
                        assetImage(name: imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? .white : Color.black.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(selected ? AnyShapeStyle(BabyTownTheme.buttonGradient)
                                   : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(
                Capsule()
                    .stroke(selected ? .clear : Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: selected ? BabyTownTheme.buttonShadow : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var doneRefillButton: some View {
        Button(action: cancelFoodRefillMiniGame) {
            Label("Cancel", systemImage: "xmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Color.gray, in: Capsule())
                .shadow(color: Color.black.opacity(0.16), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var cancelLitterCleaningButton: some View {
        Button(action: cancelLitterCleaningMiniGame) {
            Label("Cancel", systemImage: "xmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.gray, in: Capsule())
                .shadow(color: Color.black.opacity(0.16), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var playToyHotbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                playToyChip(
                    title: "Laser",
                    iconSystemName: "wand.and.rays",
                    imageName: nil,
                    selected: viewModel.selectedPlayToyID == nil
                ) {
                    viewModel.selectPlayToy(nil)
                }

                ForEach(viewModel.ownedPlayToysNewestFirst) { toy in
                    playToyChip(
                        title: toy.name,
                        iconSystemName: toy.systemImage,
                        imageName: toy.imageName,
                        selected: viewModel.selectedPlayToyID == toy.id
                    ) {
                        viewModel.selectPlayToy(toy.id)
                    }
                }

                playToyChip(
                    title: "Buy",
                    iconSystemName: "plus.circle.fill",
                    imageName: nil,
                    selected: false
                ) {
                    openMarket(category: .catToys)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playToyChip(
        title: String,
        iconSystemName: String,
        imageName: String?,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Group {
                    if let imageName, UIImage(named: imageName) != nil {
                        assetImage(name: imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: iconSystemName)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? .white : Color.black.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(selected ? AnyShapeStyle(BabyTownTheme.buttonGradient)
                                   : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(
                Capsule()
                    .stroke(selected ? .clear : Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: selected ? BabyTownTheme.buttonShadow : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var trickModeBottomBar: some View {
        ZStack {
            HStack {
                Button(action: exitTrickMode) {
                    Label("Exit", systemImage: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.85), in: Capsule())
                }

                Spacer()

                Button { showTrickBook = true } label: {
                    Label("Tricks", systemImage: "book.closed.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(BabyTownTheme.buttonGradient, in: Capsule())
                        .shadow(color: BabyTownTheme.buttonShadow, radius: 8, y: 3)
                }
            }

            snackDragControl
        }
    }

    /// A grabbable snack: drag it out and drop it on the floor. The treat follows
    /// the finger inside the scene, then the cat trots over and eats it.
    private var snackDragControl: some View {
        VStack(spacing: 2) {
            Text("🐟")
                .font(.system(size: 26))
            Text("Drag")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 64, height: 64)
        .background(
            Circle().fill(LinearGradient(
                colors: [Color(red: 1.0, green: 0.74, blue: 0.36),
                         Color(red: 0.97, green: 0.54, blue: 0.27)],
                startPoint: .top, endPoint: .bottom))
        )
        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        .scaleEffect(isDraggingSnack ? 0.86 : 1)
        .opacity(isDraggingSnack ? 0.5 : 1)
        .animation(.easeOut(duration: 0.15), value: isDraggingSnack)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    guard let loc = sceneLocation(fromGlobal: value.location) else { return }
                    isDraggingSnack = true
                    scene?.moveSnack(toSceneX: loc.x, sceneY: loc.y)
                }
                .onEnded { value in
                    isDraggingSnack = false
                    let moved = hypot(value.translation.width, value.translation.height)
                    guard moved >= 24, let loc = sceneLocation(fromGlobal: value.location) else {
                        scene?.cancelSnack()
                        return
                    }
                    scene?.dropSnack(atSceneX: loc.x, sceneY: loc.y)
                }
        )
        .accessibilityLabel("Snack")
        .accessibilityHint("Drag onto the floor to feed your cat a treat")
    }

    /// Converts a SpriteKit scene point (origin bottom-left) into SwiftUI coordinates.
    private func viewPoint(fromScene point: CGPoint, geo: GeometryProxy, sceneSize: CGSize) -> CGPoint {
        let width = max(sceneSize.width, 1)
        let height = max(sceneSize.height, 1)
        return CGPoint(
            x: point.x / width * geo.size.width,
            y: geo.size.height - (point.y / height * geo.size.height)
        )
    }

    /// Converts a global (screen) point into the SpriteKit scene's coordinate
    /// space. The scene fills the screen (`.resizeFill` + `ignoresSafeArea`), so
    /// x maps directly and y is flipped against the scene height.
    private func sceneLocation(fromGlobal point: CGPoint) -> (x: CGFloat, y: CGFloat)? {
        guard let scene else { return nil }
        return (point.x, scene.size.height - point.y)
    }

    private var renameSheetContent: some View {
        PetRenameSheet(
            defaultName: activeSkin.petName,
            currentName: petDisplayName,
            cost: PetEconomy.renameCost,
            coinBalance: viewModel.coins,
            onCancel: { showRenameSheet = false },
            onConfirm: { newName in
                let result = viewModel.renamePet(for: activeSkin, to: newName)
                if let reason = result.blockedReason {
                    return reason
                }
                showRenameSheet = false
                showToast("Say hello to \(petDisplayName)!")
                return nil
            }
        )
    }

    private func close() {
        if let onDismiss {
            onDismiss()
        } else {
            environmentDismiss()
        }
    }

    private func openRenameSheet() {
        inspect = nil
        showRenameSheet = true
    }

    private func bottomBarPadding(safeArea: CGFloat) -> CGFloat {
        (safeArea + 4) * 0.8
    }

    /// Bottom play controls overlay the scene without shrinking layout, so a
    /// naive vertical center reads slightly low relative to the visible gap.
    private func petRoomModalCenterOffset(bottomSafeArea: CGFloat) -> CGFloat {
        let bottomChrome = bottomBarPadding(safeArea: bottomSafeArea) + 50
        return bottomChrome / 2
    }

    private func enterTrickMode() {
        if isPlaying {
            scene?.endLaserPlay()
            isPlaying = false
            playProgress = 0
            playRewardClaimed = false
        }
        if isRefillingFood {
            cancelFoodRefillMiniGame()
        }
        inspect = nil
        showStatsDetail = false
        showPetProfile = false
        showRenameSheet = false

        speechRecognizer.onCommand = { trick in
            handleTrickCommand(trick)
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isTrickMode = true
        }
        scene?.setTrickMode(true)
        speechRecognizer.start()
    }

    private func exitTrickMode() {
        viewModel.clearPendingSnackReinforcement()
        speechRecognizer.stop()
        speechRecognizer.onCommand = nil
        voiceTrickCompletion = nil
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isTrickMode = false
            showTrickBook = false
        }
        scene?.setTrickMode(false)
    }

    private func showVoiceTrickCompleted(_ trick: PetTrick) {
        let flashID = UUID()
        withAnimation(.easeOut(duration: 0.2)) {
            voiceTrickCompletion = (trick, flashID)
        }
        voiceTrickCompletionHapticTick += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            guard voiceTrickCompletion?.id == flashID else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                voiceTrickCompletion = nil
            }
        }
    }

    private func handleSnackEatenAfterTrick() {
        switch viewModel.rewardSnackAfterTrick() {
        case .reinforced(let trick, let leveledUp, let rewards):
            let rate = Int(viewModel.trickProgress(for: trick).obedienceRate * 100)
            showToast("Reinforced \(trick.displayName)! +\(rewards.smartMeterXP) Smart XP · \(rate)% obey")
            if leveledUp {
                let xp = PetTrickTrainingRules.snackReinforcementSmartXP
                presentTrickProgressAlerts([(trick, .levelUp(level: viewModel.trickProgress(for: trick).level, smartMeterXP: xp))])
            }
        case .treatOnly:
            break
        }
    }

    private func handleTrickCommand(_ trick: PetTrick) {
        let outcome = viewModel.attemptTrick(trick)
        switch outcome {
        case .locked:
            showToast("\(trick.displayName) isn't unlocked yet — check Tricks")
            scene?.playTrick(trick, succeeded: false)
        case .ignored(let level):
            let rate = Int(viewModel.trickProgress(for: trick).obedienceRate * 100)
            showToast("\(petDisplayName) didn't obey (\(rate)% chance · Lv \(level))")
            scene?.playTrick(trick, succeeded: false)
        case .performed(let level, let leveledUp, let newlyUnlocked, let rewards):
            showVoiceTrickCompleted(trick)
            scene?.playTrick(trick, succeeded: true)
            var alerts: [(PetTrick, PetTrickProgressAlertView.Kind)] = []
            if leveledUp {
                let levelXP = PetSmartMeterRules.successXP(for: trick) + PetSmartMeterRules.levelUpXP
                alerts.append((trick, .levelUp(level: level, smartMeterXP: levelXP)))
            }
            for unlocked in newlyUnlocked {
                let unlockXP = PetSmartMeterRules.unlockXP
                let coins = PetSmartMeterRules.unlockBonusCoins(for: unlocked)
                alerts.append((unlocked, .unlocked(bonusCoins: coins, smartMeterXP: unlockXP)))
            }
            presentTrickProgressAlerts(alerts)
        }
    }

    private func presentTrickProgressAlerts(_ alerts: [(PetTrick, PetTrickProgressAlertView.Kind)]) {
        guard !alerts.isEmpty else { return }

        func show(at index: Int) {
            guard index < alerts.count else { return }
            let (trick, kind) = alerts[index]
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                trickProgressAlert = (trick, kind, UUID())
            }
            let alertID = trickProgressAlert?.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                guard trickProgressAlert?.id == alertID else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    trickProgressAlert = nil
                }
                if index + 1 < alerts.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        show(at: index + 1)
                    }
                }
            }
        }

        show(at: 0)
    }

    // MARK: Scene

    private func sceneView(geo: GeometryProxy) -> some View {
        Group {
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            } else {
                Color.clear
            }
        }
        .onAppear {
            viewModel.registerPetInteraction()
            let awarded = viewModel.checkInForPetRoom()
            if awarded > 0 {
                coinBurst = (amount: awarded, id: UUID())
            }
            if scene == nil {
                installScene(
                    makeConfiguredScene(skin: activeSkin, size: geo.size),
                    for: activeSkin,
                    geo: geo
                )
            }
            presentWelcomeTutorialIfNeeded()
        }
        .overlay {
            if isCustomizing,
               let key = selectedCustomizePropKey,
               let anchor = selectedPropActionAnchor {
                GeometryReader { overlayGeo in
                    customizePropActionsBar(for: key)
                        .position(
                            viewPoint(
                                fromScene: anchor,
                                geo: overlayGeo,
                                sceneSize: scene?.size ?? overlayGeo.size
                            )
                        )
                }
                .allowsHitTesting(true)
            }
        }
        .overlay {
            if !isTrickMode, !isInspectingPictureFrame, !isPictureFrameInspectAnimating {
                catLevelPillOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: isPictureFrameInspectAnimating)
        .onChange(of: viewModel.adoptedSkin) { _, newSkin in
            guard let newSkin, newSkin != sceneSkin else { return }
            installScene(
                makeConfiguredScene(skin: newSkin, size: geo.size),
                for: newSkin,
                geo: geo
            )
        }
    }

    private func installScene(_ newScene: PetRoomScene, for skin: CatSkin, geo: GeometryProxy) {
        if isCustomizing { exitCustomizeMode() }
        if isTrickMode { exitTrickMode() }
        isInspectingPictureFrame = false
        isPictureFrameInspectAnimating = false
        showingPictureFrameMomentViewer = false
        scene = newScene
        sceneSkin = skin
        lastKnownLitterDirty = viewModel.isLitterBoxDirty
        refreshRoomLayout()
    }

    private func makeConfiguredScene(skin: CatSkin, size: CGSize) -> PetRoomScene {
        let s = PetRoomScene(skin: skin, size: size)
        s.onTapProp = { prop in handleProp(prop) }
        s.onTapPictureFrame = {
            openPictureFramePicker(for: viewModel.activePictureFrameID())
        }
        s.onTapPictureFrameWhileInspecting = {
            DispatchQueue.main.async {
                openPictureFrameMomentViewer()
            }
        }
        s.onPictureFrameInspectAnimatingChanged = { animating in
            DispatchQueue.main.async {
                isPictureFrameInspectAnimating = animating
            }
        }
        s.onPictureFrameInspectChanged = { active in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    isInspectingPictureFrame = active
                }
                if active {
                    inspect = nil
                    showStatsDetail = false
                    showPetProfile = false
                } else {
                    showingPictureFrameMomentViewer = false
                }
            }
        }
        s.onLayoutPositionsChanged = { positions in
            viewModel.updatePropPositions(positions)
        }
        s.onStashProp = { key in
            viewModel.stashItem(key)
            let name = PetShopCatalog.item(id: key)?.name ?? "Item"
            showToast("\(name) stashed — tap the coin pill above to bring it back")
        }
        s.onToggleFlip = { key in
            viewModel.toggleFlip(key)
        }
        s.onCustomizeSelectionChanged = { key in
            selectedCustomizePropKey = key
        }
        s.onCustomizeSelectionAnchorChanged = { anchor in
            selectedPropActionAnchor = anchor
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
        s.onSnackEaten = {
            DispatchQueue.main.async {
                handleSnackEatenAfterTrick()
            }
        }
        return s
    }

    private func refreshRoomLayout() {
        scene?.applyRoomLayout(
            viewModel.roomLayout,
            frameImage: viewModel.pictureFrameImage()
        )
        syncLitterBoxState()
        syncNeedThoughtBubble()
        scene?.setToiletPaperMessVisible(viewModel.hasActiveToiletPaperMess())
        scene?.recoverFromStalledBehavior()
    }

    /// Keeps SpriteKit paused while market / owned-items sheets cover the room,
    /// then heals walk-animation desync when they close.
    private func syncSceneSheetPause() {
        scene?.setSheetCoverActive(showMarket || showOwnedItems || showWelcomeTutorial)
    }

    private func presentWelcomeTutorialIfNeeded() {
        guard viewModel.shouldShowPetRoomTutorial, !showWelcomeTutorial else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard viewModel.shouldShowPetRoomTutorial else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                showWelcomeTutorial = true
            }
            syncSceneSheetPause()
        }
    }

    private func dismissWelcomeTutorial() {
        viewModel.markPetRoomTutorialSeen()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            showWelcomeTutorial = false
        }
        syncSceneSheetPause()
    }

    private var pictureFramePickerSheet: some View {
        let frameID = momentPickerFrameID ?? viewModel.activePictureFrameID()
        let item = frameID.flatMap { PetShopCatalog.item(id: $0) }

        return PetMomentGalleryPickerSheet(
            frameImageName: item?.imageName,
            currentMomentID: frameID.flatMap { viewModel.pictureFrameMoment(for: $0) }
        ) { momentID in
            guard let frameID else { return }
            viewModel.setPictureFrameMoment(momentID, for: frameID)
            refreshRoomLayout()
            if isInspectingPictureFrame {
                scene?.refreshPictureFrameInspect()
            }
        }
    }

    private func openPictureFramePicker(for frameID: String?) {
        guard let frameID else { return }
        momentPickerFrameID = frameID
        showMomentPicker = true
    }

    private func openPictureFrameMomentViewer() {
        guard let frameID = viewModel.activePictureFrameID(),
              let momentID = viewModel.pictureFrameMoment(for: frameID) else {
            openPictureFramePicker(for: viewModel.activePictureFrameID())
            return
        }

        let allMoments = DataPersistenceManager.shared.loadMoments()
        guard let target = allMoments.first(where: { $0.id == momentID }) else {
            openPictureFramePicker(for: frameID)
            return
        }

        let dayMoments: [Moment]
        if let section = DaySection.grouped(from: allMoments).first(where: { section in
            section.moments.contains { $0.id == momentID }
        }) {
            dayMoments = section.moments.sorted { $0.dateTaken < $1.dateTaken }
        } else {
            dayMoments = [target]
        }

        pictureFrameViewerMoments = dayMoments
        pictureFrameViewerInitialIndex = dayMoments.firstIndex(where: { $0.id == momentID }) ?? 0
        withAnimation(.easeInOut(duration: 0.25)) {
            showingPictureFrameMomentViewer = true
        }
    }

    private func syncNeedThoughtBubble() {
        let showFoodThought = Double(viewModel.hunger) < PetEconomy.feedThirstGate
        let showWaterThought = Double(viewModel.thirst) < PetEconomy.feedThirstGate
        scene?.setWaterBowlLevel(viewModel.thirst)
        scene?.setNeedThoughts(showFood: showFoodThought, showWater: showWaterThought)
    }

    private func syncLitterBoxState() {
        // Auto-Clean box: passively collect coins for any litter-use events that
        // happened since the last clean (including while the app was closed).
        let collected = viewModel.processAutoLitterCollection()
        if collected > 0 {
            showToast("Auto-Clean box tidied up! +\(collected) 🪙")
        }
        let isDirty = viewModel.isLitterBoxDirty
        if isDirty && !lastKnownLitterDirty {
            scene?.playLitterBoxUseAnimation(for: activeSkin)
        } else {
            scene?.setLitterBoxDirty(isDirty)
        }
        lastKnownLitterDirty = isDirty
    }

    private func beginCustomizeRoom() {
        customizeSnapshot = viewModel.roomLayout.propPositions
        isCustomizing = true
        inspect = nil
        showStatsDetail = false
        showPetProfile = false
        showRenameSheet = false
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
        selectedCustomizePropKey = nil
        selectedPropActionAnchor = nil
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
                .background(BabyTownTheme.savePillFill)
                .clipShape(Capsule())
                .shadow(color: BabyTownTheme.savePillShadow, radius: 10, y: 4)
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

    private var trickTrainingEntryButton: some View {
        Button(action: enterTrickMode) {
            Label("Train", systemImage: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accentDeep)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.white.opacity(0.95), in: Capsule())
                .overlay(Capsule().stroke(BabyTownTheme.accent.opacity(0.35), lineWidth: 1))
                .shadow(color: BabyTownTheme.cardShadow, radius: 8, y: 3)
        }
    }

    private var knownUnlockedTricks: [PetTrick] {
        PetTrick.unlockOrder.filter { viewModel.isTrickUnlocked($0) }
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
                scene?.startPlay(selectedToyID: viewModel.selectedPlayToyID)
                isPlaying = true
            }
        } label: {
            Label(isPlaying ? "Done Playing" : "Play",
                  systemImage: isPlaying ? "stop.fill" : "wand.and.rays")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(isPlaying ? AnyShapeStyle(Color.gray) : AnyShapeStyle(BabyTownTheme.buttonGradient))
                .clipShape(Capsule())
                .shadow(color: BabyTownTheme.buttonShadow, radius: 10, y: 4)
        }
    }

    // MARK: Interaction handling

    /// Opens the market. Passing a category jumps to it; otherwise the last-viewed
    /// category is preserved.
    private func openMarket(category: PetShopCategory? = nil) {
        if let category {
            marketInitialCategory = category
        }
        withAnimation { inspect = nil }
        showMarket = true
    }

    private func openOwnedItems(category: PetShopCategory? = nil) {
        if let category {
            ownedItemsInitialCategory = category
        } else if !viewModel.ownedItemCategories.contains(ownedItemsInitialCategory) {
            // Remembered category no longer has owned items — fall back.
            ownedItemsInitialCategory = viewModel.ownedItemCategories.first ?? .catTrees
        }
        withAnimation { inspect = nil }
        showOwnedItems = true
    }

    private func handleProp(_ prop: PetRoomScene.RoomProp) {
        if showingToiletPaperModal || isCleaningLitterBox || isRefillingFood || isWateringPlant { return }
        switch prop {
        case .cat:
            present(viewModel.pet())
            scene?.playReaction(.happy)
        case .foodBowl, .waterBowl, .litterBox, .smallPlant, .bigPlant:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { inspect = prop }
        case .toiletPaperMess:
            inspect = nil
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                toiletPaperMessage = viewModel.randomToiletPaperMessComment(for: petDisplayName)
            }
        }
    }

    private func performInspectAction(_ prop: PetRoomScene.RoomProp) {
        let result: CareResult
        switch prop {
        case .foodBowl:
            beginFoodRefillMiniGame()
            withAnimation { inspect = nil }
            return
        case .waterBowl:
            result = viewModel.fillWater()
            if result.coinsAwarded > 0 { scene?.playReaction(.drink) }
        case .litterBox:
            if viewModel.isLitterBoxDirty {
                beginLitterCleaningMiniGame()
                withAnimation { inspect = nil }
                return
            } else {
                result = viewModel.cleanLitter()
                syncLitterBoxState()
            }
        case .smallPlant, .bigPlant:
            beginWateringMiniGame(for: prop)
            withAnimation { inspect = nil }
            return
        case .toiletPaperMess:
            result = .none
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
        syncNeedThoughtBubble()
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

    private func toggleSecondPetAdoptionBypassIfNeeded() {
        guard viewModel.ownedSkins.count == 1 else { return }
        let enabled = viewModel.toggleSecondPetAdoptionBypass()
        if enabled {
            let lockedName = CatSkin.allCases.first { !viewModel.ownedSkins.contains($0) }?.petName ?? "second pet"
            showToast("Secret mode: \(lockedName) unlocked. Long-press the level pill again to undo.")
        } else {
            showToast("Secret mode undone. Level \(PetEconomy.secondPetUnlockLevel) required again.")
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toast == message { withAnimation { toast = nil } }
        }
    }

    private var foodRefillOverlay: some View {
        GeometryReader { overlayGeo in
            ZStack {
                Color.black.opacity(0.06)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(refillFoodDragGesture(in: overlayGeo))

                refillFoodSprite
                    .position(refillFoodCenter)
                    .opacity(refillFoodOpacity)
                    .allowsHitTesting(false)
            }
            .onAppear {
                if refillFoodCenter == .zero {
                    refillFoodCenter = CGPoint(x: overlayGeo.size.width / 2, y: overlayGeo.size.height / 2)
                }
            }
        }
        .transition(.opacity)
        .zIndex(100)
    }

    private var refillFoodSprite: some View {
        Group {
            if let item = availableRefillFoodItems.first(where: { $0.id == selectedRefillFoodID }),
               let imageName = item.imageName,
               UIImage(named: imageName) != nil {
                assetImage(name: imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            }
        }
        .frame(width: 140, height: 110)
        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
    }

    private func refillFoodDragGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard isRefillingFood else { return }
                refillFoodCenter = clampedRefillFoodCenter(value.location, in: geo.size)
                if isFoodOverBowl(refillFoodCenter, in: geo) {
                    startRefillHoldTimerIfNeeded(in: geo)
                } else {
                    stopRefillHoldTimer(resetProgress: true)
                }
            }
            .onEnded { _ in
                guard isRefillingFood else { return }
                if !isFoodOverBowl(refillFoodCenter, in: geo) {
                    stopRefillHoldTimer(resetProgress: true)
                }
            }
    }

    private func clampedRefillFoodCenter(_ center: CGPoint, in size: CGSize) -> CGPoint {
        let halfW: CGFloat = 70
        let halfH: CGFloat = 55
        return CGPoint(
            x: min(max(center.x, halfW), max(halfW, size.width - halfW)),
            y: min(max(center.y, halfH), max(halfH, size.height - halfH))
        )
    }

    private func beginFoodRefillMiniGame() {
        guard !isRefillingFood else { return }
        guard viewModel.foodServings > 0 else {
            showToast("Out of food — buy some in the Market")
            return
        }
        guard Double(viewModel.hunger) < PetEconomy.feedThirstGate else {
            showToast("There's still food in the bowl")
            return
        }
        isRefillingFood = true
        showFoodRefillOverlay = true
        refillProgress = 0
        stopRefillHoldTimer(resetProgress: false)
        withAnimation(.easeOut(duration: 0.2)) {
            refillFoodOpacity = 1
        }
    }

    private func cancelFoodRefillMiniGame() {
        guard isRefillingFood else { return }
        isRefillingFood = false
        stopRefillHoldTimer(resetProgress: true)
        withAnimation(.easeOut(duration: 0.2)) {
            refillFoodOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showFoodRefillOverlay = false
            refillProgress = 0
        }
    }

    private func finishFoodRefillMiniGame() {
        guard isRefillingFood else { return }
        let result = viewModel.refillFood()
        present(result)
        if result.coinsAwarded > 0 {
            scene?.playReaction(.eat)
            showToast("Food bowl has been refilled.")
        } else if let reason = result.blockedReason {
            showToast(reason)
        }
        cancelFoodRefillMiniGame()
    }

    private func startRefillHoldTimerIfNeeded(in geo: GeometryProxy) {
        guard refillHoldTimer == nil else { return }
        refillHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard isRefillingFood else {
                stopRefillHoldTimer(resetProgress: false)
                return
            }
            guard isFoodOverBowl(refillFoodCenter, in: geo) else {
                stopRefillHoldTimer(resetProgress: true)
                return
            }
            refillProgress = min(refillDurationRequired, refillProgress + 0.05)
            if refillProgress >= refillDurationRequired {
                stopRefillHoldTimer(resetProgress: false)
                finishFoodRefillMiniGame()
            }
        }
    }

    private func stopRefillHoldTimer(resetProgress: Bool) {
        refillHoldTimer?.invalidate()
        refillHoldTimer = nil
        if resetProgress {
            refillProgress = 0
        }
    }

    private func isFoodOverBowl(_ point: CGPoint, in geo: GeometryProxy) -> Bool {
        guard let scene,
              let bowlFrame = scene.foodBowlFrameInScene() else { return false }
        let scenePoint = CGPoint(
            x: point.x / max(geo.size.width, 1) * scene.size.width,
            y: scene.size.height - (point.y / max(geo.size.height, 1) * scene.size.height)
        )
        return bowlFrame.insetBy(dx: -14, dy: -14).contains(scenePoint)
    }

    private var litterScooperOverlay: some View {
        GeometryReader { overlayGeo in
            ZStack {
                Color.black.opacity(0.06)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                scooperImage
                    .contentShape(Rectangle())
                    .position(litterScooperCenter)
                    .opacity(litterScooperOpacity)
                    .gesture(litterScooperDragGesture(in: overlayGeo))
            }
            .coordinateSpace(name: "litterScooperOverlay")
            .onAppear {
                if litterScooperCenter == .zero {
                    litterScooperCenter = CGPoint(x: overlayGeo.size.width / 2, y: overlayGeo.size.height / 2)
                }
            }
        }
        .transition(.opacity)
        .zIndex(100)
    }

    private var scooperImage: some View {
        Group {
            if let uiImage = UIImage(named: litterScooperAssetName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: litterScooperSize.width, height: litterScooperSize.height)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 54))
                    .foregroundStyle(.white)
            }
        }
        // User requested a horizontal flip.
        .scaleEffect(x: -1, y: 1, anchor: .center)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    private var litterCleaningProgressBar: some View {
        let fraction = min(1, litterCleanProgress / litterCleanDurationRequired)
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule().fill(BabyTownTheme.buttonGradient)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 9)
            Text("\(Int(litterCleanProgress.rounded(.down))) / \(Int(litterCleanDurationRequired))s")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 220)
    }

    private func beginLitterCleaningMiniGame() {
        guard !isCleaningLitterBox else { return }
        isCleaningLitterBox = true
        showLitterScooper = true
        litterDragLastTimestamp = nil
        litterDragLastScrubPoint = nil
        litterScooperDragGrabOffset = nil
        withAnimation(.easeOut(duration: 0.2)) {
            litterScooperOpacity = 1
        }
    }

    private func cancelLitterCleaningMiniGame() {
        guard isCleaningLitterBox else { return }
        isCleaningLitterBox = false
        litterDragLastTimestamp = nil
        litterDragLastScrubPoint = nil
        litterScooperDragGrabOffset = nil
        withAnimation(.easeOut(duration: 0.22)) {
            litterScooperOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showLitterScooper = false
            // Intentionally keep `litterCleanProgress` so users can resume.
        }
    }

    private func finishLitterCleaningMiniGame() {
        guard isCleaningLitterBox else { return }
        isCleaningLitterBox = false
        litterDragLastTimestamp = nil
        litterDragLastScrubPoint = nil
        litterScooperDragGrabOffset = nil

        let result = viewModel.cleanLitter()
        syncLitterBoxState()
        present(result)
        if result.coinsAwarded > 0 {
            showToast("Litter box is now clean! +\(result.coinsAwarded) 🪙")
        }

        withAnimation(.easeOut(duration: 0.22)) {
            litterScooperOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showLitterScooper = false
            litterCleanProgress = 0
        }
    }

    private func litterScooperDragGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("litterScooperOverlay"))
            .onChanged { value in
                guard isCleaningLitterBox else { return }
                let touchPoint = value.location
                if litterScooperDragGrabOffset == nil {
                    litterScooperDragGrabOffset = CGSize(
                        width: value.startLocation.x - litterScooperCenter.x,
                        height: value.startLocation.y - litterScooperCenter.y
                    )
                }
                let grab = litterScooperDragGrabOffset ?? .zero
                let requestedCenter = CGPoint(
                    x: touchPoint.x - grab.width,
                    y: touchPoint.y - grab.height
                )
                litterScooperCenter = clampedScooperCenter(requestedCenter, in: geo.size)
                let scrubPoint = CGPoint(
                    x: touchPoint.x + litterScooperScrubOffsetFromTouch.width,
                    y: touchPoint.y + litterScooperScrubOffsetFromTouch.height
                )
                updateLitterCleaningProgress(withScrub: scrubPoint, in: geo)
            }
            .onEnded { _ in
                litterDragLastTimestamp = nil
                litterDragLastScrubPoint = nil
                litterScooperDragGrabOffset = nil
            }
    }

    private func clampedScooperCenter(_ center: CGPoint, in size: CGSize) -> CGPoint {
        let halfW = litterScooperSize.width / 2
        let halfH = litterScooperSize.height / 2
        return CGPoint(
            x: min(
                max(center.x, halfW - litterScooperHorizontalOverflow),
                max(halfW - litterScooperHorizontalOverflow, size.width - halfW + litterScooperHorizontalOverflow)
            ),
            y: min(
                max(center.y, halfH - litterScooperVerticalOverflow),
                max(halfH - litterScooperVerticalOverflow, size.height - halfH + litterScooperVerticalOverflow)
            )
        )
    }

    private func updateLitterCleaningProgress(withScrub scrubPoint: CGPoint, in geo: GeometryProxy) {
        let now = Date()
        defer {
            litterDragLastTimestamp = now
            litterDragLastScrubPoint = scrubPoint
        }

        guard let lastTime = litterDragLastTimestamp,
              let lastPoint = litterDragLastScrubPoint else { return }
        let dt = now.timeIntervalSince(lastTime)
        guard dt > 0 else { return }

        let moved = hypot(scrubPoint.x - lastPoint.x, scrubPoint.y - lastPoint.y)
        let isActivelyScrubbing = moved >= 6
        guard isActivelyScrubbing, isScrubPointOverLitterBox(scrubPoint, in: geo) else { return }

        litterCleanProgress = min(litterCleanDurationRequired, litterCleanProgress + dt)
        if litterCleanProgress >= litterCleanDurationRequired {
            finishLitterCleaningMiniGame()
        }
    }

    private func isScrubPointOverLitterBox(_ scrubPoint: CGPoint, in geo: GeometryProxy) -> Bool {
        guard let scene,
              let litterFrame = scene.litterBoxFrameInScene() else { return false }
        let scenePoint = CGPoint(
            x: scrubPoint.x / max(geo.size.width, 1) * scene.size.width,
            y: scene.size.height - (scrubPoint.y / max(geo.size.height, 1) * scene.size.height)
        )
        // Slightly larger scrubbing zone so the whole scooper feels effective over the litter.
        return litterFrame.insetBy(dx: -36, dy: -26).contains(scenePoint)
    }

    // MARK: Plant watering mini-game

    private func plantKey(for prop: PetRoomScene.RoomProp) -> String {
        prop == .smallPlant ? "furniture_small_plant" : "furniture_big_plant"
    }

    private func plantStatusText(for prop: PetRoomScene.RoomProp) -> String? {
        guard prop == .smallPlant || prop == .bigPlant else { return nil }
        if viewModel.canEarnWaterCoins(key: plantKey(for: prop)) {
            return "Give your plant a drink 💧"
        }
        return "Freshly watered — water again later for more coins"
    }

    private var wateringCanOverlay: some View {
        GeometryReader { overlayGeo in
            ZStack {
                Color.black.opacity(0.06)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                wateringCanView
                    .position(wateringCanCenter)
                    .opacity(wateringCanOpacity)
                    .gesture(wateringDragGesture(in: overlayGeo))
            }
            .onAppear {
                if wateringCanCenter == .zero {
                    wateringCanCenter = CGPoint(x: overlayGeo.size.width / 2, y: overlayGeo.size.height / 2)
                }
            }
        }
        .transition(.opacity)
        .zIndex(100)
    }

    private var wateringCanView: some View {
        let teal = Color(red: 0.38, green: 0.74, blue: 0.88)
        let tealDark = Color(red: 0.20, green: 0.52, blue: 0.68)
        return ZStack {
            // Handle arc over the top
            Capsule()
                .stroke(tealDark, lineWidth: 7)
                .frame(width: 40, height: 46)
                .position(x: 80, y: 30)
            // Spout
            Capsule()
                .fill(tealDark)
                .frame(width: 54, height: 15)
                .rotationEffect(.degrees(-26))
                .position(x: 36, y: 60)
            // Sprinkler head at the spout tip
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tealDark)
                .frame(width: 20, height: 16)
                .rotationEffect(.degrees(-26))
                .position(x: 17, y: 76)
            // Body
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(teal)
                .frame(width: 66, height: 58)
                .position(x: 80, y: 66)
            // Rim
            Ellipse()
                .fill(tealDark)
                .frame(width: 68, height: 16)
                .position(x: 80, y: 40)
            // Falling droplets under the spout
            wateringDroplets
                .position(x: 15, y: 96)
        }
        .frame(width: wateringCanSize.width, height: wateringCanSize.height)
        .scaleEffect(x: wateringCanFacesLeft ? 1 : -1, y: 1, anchor: .center)
        .shadow(color: .black.opacity(0.28), radius: 9, y: 4)
    }

    private var wateringDroplets: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, _ in
                for i in 0..<3 {
                    let phase = (t * 1.7 + Double(i) * 0.34).truncatingRemainder(dividingBy: 1)
                    let y = phase * 24
                    let alpha = 1 - phase
                    let rect = CGRect(x: Double(i) * 8, y: y, width: 5, height: 7)
                    ctx.fill(
                        Ellipse().path(in: rect),
                        with: .color(Color(red: 0.40, green: 0.72, blue: 0.95).opacity(alpha))
                    )
                }
            }
            .frame(width: 24, height: 32)
        }
    }

    private var wateringProgressBar: some View {
        let fraction = min(1, wateringProgress / wateringDurationRequired)
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule().fill(BabyTownTheme.buttonGradient)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 9)
            Text("\(Int(wateringProgress.rounded(.down))) / \(Int(wateringDurationRequired))s")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 220)
    }

    private var wateringModeBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Text("Water Plant")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Spacer()
            }
            wateringProgressBar
            Text("Drag the watering can over the plant")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var cancelWateringButton: some View {
        Button(action: cancelWateringMiniGame) {
            Label("Cancel", systemImage: "xmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.gray, in: Capsule())
                .shadow(color: Color.black.opacity(0.16), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func beginWateringMiniGame(for prop: PetRoomScene.RoomProp) {
        guard !isWateringPlant else { return }
        isWateringPlant = true
        wateringPlantProp = prop
        wateringCanFacesLeft = shouldWateringCanFaceLeft(for: prop)
        showWateringCan = true
        wateringProgress = 0
        wateringDragLastTimestamp = nil
        withAnimation(.easeOut(duration: 0.2)) {
            wateringCanOpacity = 1
        }
    }

    private func cancelWateringMiniGame() {
        guard isWateringPlant else { return }
        isWateringPlant = false
        wateringDragLastTimestamp = nil
        withAnimation(.easeOut(duration: 0.22)) {
            wateringCanOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showWateringCan = false
        }
    }

    private func finishWateringMiniGame() {
        guard isWateringPlant, let prop = wateringPlantProp else { return }
        isWateringPlant = false
        wateringDragLastTimestamp = nil

        let result = viewModel.waterPlant(plantKey(for: prop))
        scene?.playPlantWaterReaction(for: prop)
        present(result)
        if result.coinsAwarded > 0 {
            showToast("Plant watered! +\(result.coinsAwarded) 🪙")
        }

        withAnimation(.easeOut(duration: 0.22)) {
            wateringCanOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showWateringCan = false
            wateringProgress = 0
        }
    }

    private func wateringDragGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard isWateringPlant else { return }
                let topAnchorPoint = value.location
                let requestedCenter = CGPoint(
                    x: topAnchorPoint.x - wateringCanTopAnchorOffset.width,
                    y: topAnchorPoint.y - wateringCanTopAnchorOffset.height
                )
                wateringCanCenter = clampedWateringCanCenter(requestedCenter, in: geo.size)
                let spoutPoint = CGPoint(
                    x: wateringCanCenter.x + wateringCanSpoutOffset.width,
                    y: wateringCanCenter.y + wateringCanSpoutOffset.height
                )
                updateWateringProgress(withSpout: spoutPoint, in: geo)
            }
            .onEnded { _ in
                wateringDragLastTimestamp = nil
            }
    }

    private func clampedWateringCanCenter(_ center: CGPoint, in size: CGSize) -> CGPoint {
        let halfW = wateringCanSize.width / 2
        let halfH = wateringCanSize.height / 2
        return CGPoint(
            x: min(
                max(center.x, halfW - wateringOverflow),
                max(halfW - wateringOverflow, size.width - halfW + wateringOverflow)
            ),
            y: min(
                max(center.y, halfH - wateringOverflow),
                max(halfH - wateringOverflow, size.height - halfH + wateringOverflow)
            )
        )
    }

    private func updateWateringProgress(withSpout spoutPoint: CGPoint, in geo: GeometryProxy) {
        let now = Date()
        defer { wateringDragLastTimestamp = now }
        guard let lastTime = wateringDragLastTimestamp else { return }
        let dt = now.timeIntervalSince(lastTime)
        // Ignore non-positive or stale gaps (e.g. after a pause).
        guard dt > 0, dt < 1 else { return }
        guard isSpoutOverPlant(spoutPoint, in: geo) else { return }

        wateringProgress = min(wateringDurationRequired, wateringProgress + dt)
        if wateringProgress >= wateringDurationRequired {
            finishWateringMiniGame()
        }
    }

    private func isSpoutOverPlant(_ spoutPoint: CGPoint, in geo: GeometryProxy) -> Bool {
        guard let scene,
              let prop = wateringPlantProp,
              let plantFrame = scene.plantFrameInScene(for: prop) else { return false }
        let scenePoint = CGPoint(
            x: spoutPoint.x / max(geo.size.width, 1) * scene.size.width,
            y: scene.size.height - (spoutPoint.y / max(geo.size.height, 1) * scene.size.height)
        )
        return plantFrame.insetBy(dx: -30, dy: -30).contains(scenePoint)
    }

    private var wateringCanSpoutOffset: CGSize {
        CGSize(
            width: wateringCanFacesLeft ? wateringCanSpoutOffsetLeft.width : -wateringCanSpoutOffsetLeft.width,
            height: wateringCanSpoutOffsetLeft.height
        )
    }

    private var wateringCanTopAnchorOffset: CGSize {
        CGSize(
            width: wateringCanFacesLeft ? wateringCanTopAnchorOffsetLeft.width : -wateringCanTopAnchorOffsetLeft.width,
            height: wateringCanTopAnchorOffsetLeft.height
        )
    }

    private func shouldWateringCanFaceLeft(for prop: PetRoomScene.RoomProp) -> Bool {
        guard let scene, let frame = scene.plantFrameInScene(for: prop) else { return true }
        return frame.midX < scene.size.width * 0.5
    }

    private func assetImage(name: String) -> Image {
        if let processed = processedAssetImage(named: name) {
            return Image(uiImage: processed)
        }
        return Image(name)
    }

    private func processedAssetImage(named name: String) -> UIImage? {
        let key = NSString(string: name)
        if let cached = Self.transparentAssetCache.object(forKey: key) {
            return cached
        }
        guard let original = UIImage(named: name) else { return nil }
        let processed = removeBlackMatteIfNeeded(from: original)
        Self.transparentAssetCache.setObject(processed, forKey: key)
        return processed
    }

    /// Detects PNGs with an opaque black matte and converts that matte to alpha.
    private func removeBlackMatteIfNeeded(from image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let width = cg.width
        let height = cg.height
        guard width > 1, height > 1 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        func isNearBlack(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Bool {
            r <= 24 && g <= 24 && b <= 24
        }

        var borderOpaque = 0
        var borderBlack = 0
        for x in stride(from: 0, to: width, by: max(1, width / 80)) {
            for y in [0, height - 1] {
                let i = (y * width + x) * bytesPerPixel
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                if a > 220 {
                    borderOpaque += 1
                    if isNearBlack(r, g, b) { borderBlack += 1 }
                }
            }
        }
        for y in stride(from: 0, to: height, by: max(1, height / 80)) {
            for x in [0, width - 1] {
                let i = (y * width + x) * bytesPerPixel
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                if a > 220 {
                    borderOpaque += 1
                    if isNearBlack(r, g, b) { borderBlack += 1 }
                }
            }
        }

        guard borderOpaque > 0 else { return image }
        let borderBlackRatio = Double(borderBlack) / Double(borderOpaque)
        guard borderBlackRatio >= 0.80 else { return image }

        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
            if a >= 245 && isNearBlack(r, g, b) {
                pixels[i + 3] = 0
            }
        }

        guard let out = ctx.makeImage() else { return image }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }
}

private extension View {
    @ViewBuilder
    func successHapticIfAvailable(trigger: Int) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.success, trigger: trigger)
        } else {
            self
        }
    }
}

/// A five-bar equalizer that rises and falls with the live mic level, so the
/// trick-training banner shows the microphone actively hearing the user.
private struct MicLevelBars: View {
    var level: CGFloat   // 0…1

    private let weights: [CGFloat] = [0.55, 0.82, 1.0, 0.82, 0.55]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(weights.indices, id: \.self) { i in
                Capsule()
                    .fill(BabyTownTheme.accentGradient)
                    .frame(width: 4, height: barHeight(weights[i]))
            }
        }
        .frame(height: 22)
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private func barHeight(_ weight: CGFloat) -> CGFloat {
        let base: CGFloat = 5
        let maxH: CGFloat = 22
        return base + (maxH - base) * min(1, level * weight * 1.4)
    }
}
