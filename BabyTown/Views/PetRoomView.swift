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
    @State private var showMomentPicker = false
    @State private var customizeSnapshot: [String: NormalizedPoint] = [:]
    @State private var showCustomizeExitPrompt = false
    @State private var showRenameSheet = false
    @State private var selectedCustomizePropKey: String?
    @State private var selectedPropActionAnchor: CGPoint?

    @State private var isTrickMode = false
    @State private var showTrickBook = false
    @State private var isDraggingSnack = false
    @StateObject private var speechRecognizer = PetSpeechCommandRecognizer()
    @State private var trickProgressAlert: (trick: PetTrick, kind: PetTrickProgressAlertView.Kind, id: UUID)?
    @State private var voiceTrickCompletion: (trick: PetTrick, id: UUID)?
    @State private var voiceTrickCompletionHapticTick = 0

    private var petDisplayName: String {
        viewModel.displayName(for: skin)
    }

    var body: some View {
        GeometryReader { geo in
            // SpriteView (Metal) can obscure sibling ZStack content, so modals
            // and bottom controls use `.overlay`, which draws above the scene.
            sceneView(geo: geo)
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    VStack(spacing: 12) {
                        if showRenameSheet {
                            PetRenameSheet(
                                defaultName: skin.petName,
                                currentName: petDisplayName,
                                cost: PetEconomy.renameCost,
                                coinBalance: viewModel.coins,
                                onCancel: {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                        showRenameSheet = false
                                    }
                                },
                                onConfirm: { newName in
                                    let result = viewModel.renamePet(for: skin, to: newName)
                                    if let reason = result.blockedReason {
                                        return reason
                                    }
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                        showRenameSheet = false
                                    }
                                    showToast("Say hello to \(petDisplayName)!")
                                    return nil
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Group {
                            if isCustomizing {
                                customizeBottomBar
                            } else if isTrickMode {
                                trickModeBottomBar
                            } else {
                                playModeBottomBar
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, bottomBarPadding(safeArea: geo.safeAreaInsets.bottom))
                    .ignoresSafeArea(.keyboard, edges: .bottom)
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
                .animation(.spring(response: 0.34, dampingFraction: 0.82), value: voiceTrickCompletion?.id)
                .animation(.spring(response: 0.34, dampingFraction: 0.82), value: trickProgressAlert?.id)
                .sensoryFeedback(.success, trigger: voiceTrickCompletionHapticTick)
                .overlay {
                    if let prop = inspect {
                        ZStack {
                            Color.black.opacity(0.25).ignoresSafeArea()
                                .onTapGesture { inspect = nil }
                            BowlInspectCard(
                                prop: prop,
                                hunger: viewModel.hunger,
                                thirst: viewModel.thirst,
                                litter: viewModel.litter,
                                foodServings: viewModel.foodServings,
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
                                skin: skin,
                                displayName: petDisplayName,
                                birthDate: DataPersistenceManager.shared.loadOrCreateAppJoinedDate(),
                                onClose: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showPetProfile = false
                                    }
                                }
                            )
                            .offset(y: -petRoomModalCenterOffset(bottomSafeArea: geo.safeAreaInsets.bottom))
                            .transition(.scale.combined(with: .opacity))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if showRenameSheet {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    showRenameSheet = false
                                }
                            }
                            .transition(.opacity)
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
                        Button {
                            openMarket(category: .catTrees)
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
                            Button {
                                inspect = nil
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showPetProfile = true
                                }
                            } label: {
                                Label("Pet Profile", systemImage: "person.crop.rectangle")
                            }
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    showRenameSheet = true
                                }
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button {
                                enterTrickMode()
                            } label: {
                                Label("Trick Training", systemImage: "mic.fill")
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
            } else if isTrickMode {
                trickModeBanner
            } else {
                TimelineView(.periodic(from: .now, by: 5)) { _ in
                    PetHUDView(coins: viewModel.coins,
                               hunger: viewModel.hunger,
                               thirst: viewModel.thirst,
                               litter: viewModel.litter,
                               happiness: viewModel.happiness,
                               onInventoryTap: { openOwnedItems() },
                               onStatsTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showStatsDetail = true
                        }
                    })
                }
            }
        }
        .sheet(isPresented: $showMarket) {
            PetMarketSheet(viewModel: viewModel, initialCategory: marketInitialCategory) {
                showMomentPicker = true
            }
        }
        .sheet(isPresented: $showOwnedItems) {
            PetOwnedItemsSheet(viewModel: viewModel, initialCategory: ownedItemsInitialCategory) {
                showMomentPicker = true
            }
        }
        .sheet(isPresented: $showMomentPicker) {
            PetMomentGalleryPickerSheet(
                currentMomentID: viewModel.roomLayout.pictureFrameMomentID
            ) { momentID in
                viewModel.setPictureFrameMoment(momentID)
                refreshRoomLayout()
            }
        }
        .sheet(isPresented: $showTrickBook) {
            PetTrickBookSheet(viewModel: viewModel) {
                showTrickBook = false
            }
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
            refreshRoomLayout()
        }
        .onDisappear {
            if isTrickMode { exitTrickMode() }
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
                        if let heard = speechRecognizer.lastHeard, !heard.isEmpty {
                            Text("Heard: \"\(heard)\"")
                        } else {
                            Text("Listening... Try saying \"Paw\" and more!")
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
                .foregroundStyle(Color(red: 0.22, green: 0.2, blue: 0.22))
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

    private var playModeBottomBar: some View {
        VStack(spacing: 10) {
            if isPlaying {
                laserPlayProgressBar
                Text("Drag the laser to fill the bar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                trickTrainingEntryButton
                playButton
            }
        }
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

    private func handleTrickCommand(_ trick: PetTrick) {
        let outcome = viewModel.attemptTrick(trick, voiceRecognized: true)
        switch outcome {
        case .locked:
            showToast("\(trick.displayName) isn't unlocked yet — check Tricks")
            scene?.playTrick(trick, succeeded: false)
        case .ignored(let level):
            showToast("\(petDisplayName) didn't quite get it (Level \(level))")
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
            if scene == nil {
                installScene(makeConfiguredScene(skin: skin, size: geo.size), geo: geo)
                if viewModel.ownsShopItem(PetShopCatalog.pictureFrameID),
                   viewModel.roomLayout.pictureFrameMomentID == nil {
                    showMomentPicker = true
                }
            }
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
        .onChange(of: skin) { _, newSkin in
            installScene(makeConfiguredScene(skin: newSkin, size: geo.size), geo: geo)
        }
    }

    private func installScene(_ newScene: PetRoomScene, geo: GeometryProxy) {
        if isCustomizing { exitCustomizeMode() }
        if isTrickMode { exitTrickMode() }
        scene = newScene
        refreshRoomLayout()
    }

    private func makeConfiguredScene(skin: CatSkin, size: CGSize) -> PetRoomScene {
        let s = PetRoomScene(skin: skin, size: size)
        s.onTapProp = { prop in handleProp(prop) }
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
                let rewards = viewModel.rewardTreatTeaser()
                if rewards.smartMeterXP > 0 {
                    showToast("Treat teaser +\(rewards.smartMeterXP) Smart XP")
                }
            }
        }
        return s
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

    private func openMarket(category: PetShopCategory) {
        marketInitialCategory = category
        withAnimation { inspect = nil }
        showMarket = true
    }

    private func openOwnedItems(category: PetShopCategory? = nil) {
        if let category {
            ownedItemsInitialCategory = category
        } else if let first = viewModel.ownedItemCategories.first {
            ownedItemsInitialCategory = first
        } else {
            ownedItemsInitialCategory = .catTrees
        }
        withAnimation { inspect = nil }
        showOwnedItems = true
    }

    private func handleProp(_ prop: PetRoomScene.RoomProp) {
        switch prop {
        case .cat:
            if isTrickMode { return }
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
            result = viewModel.refillFood()
            if result.coinsAwarded > 0 { scene?.playReaction(.eat) }
        case .waterBowl:
            result = viewModel.fillWater()
            if result.coinsAwarded > 0 { scene?.playReaction(.drink) }
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
