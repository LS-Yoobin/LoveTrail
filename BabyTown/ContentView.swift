//
//  ContentView.swift
//  BabyTown
//
//  Created by Justin Seo on 2/12/26.
//

import SwiftUI

struct ContentView: View {

    enum Screen: Equatable {
        case launch, auth, welcome, storyOnboarding, nickname, colorTheme, birthday
        case checkInviteCode       // NEW — "do you have a code?" before pathSelector
        case joinWithCode          // NEW — code entry reached from checkInviteCode
        case pathSelector          // branch point after checkInviteCode
        case firstMemories, howItWorks, photoAccess, home, selectPhotos
        case loveGarden   // TEMP (Slice 1): direct route to verify the garden; remove when the cat-room door lands.
        case prelude
        case preludeOnboarding     // NEW — prelude intro screen
        case archivedCouple
        case partnerOnboarding(inviterName: String)
        case invitePartner
        case officialPending
        case partnerGiftReveal(captures: [PreludeCapture], revealerName: String)
        case justPickPhotos
    }

    @State private var screen: Screen = .launch
    @State private var targetScreen: Screen = .welcome
    @State private var firstMetPhoto: UIImage?
    @State private var officialPhoto: UIImage?
    @State private var selectedPrompt: PromptItem?
    @State private var shouldScrollToNewMemory = false
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var firstMemoriesViewModel = FirstMemoriesViewModel()
    @Environment(\.scenePhase) private var scenePhase

    private func resetAppToWelcome() {
        AudioManager.shared.setGardenActive(false)
        DataPersistenceManager.shared.clearAllData()
        StoreManager.shared.resetForTesting()
        ThemeManager.shared.setTheme(DataPersistenceManager.shared.loadColorTheme())
        homeViewModel.moments = []
        homeViewModel.promptMemories = []
        homeViewModel.pinnedFirstMet = nil
        homeViewModel.pinnedOfficial = UIImage(systemName: "heart.fill")!
        homeViewModel.polaroidStore.reset()
        firstMetPhoto = nil
        officialPhoto = nil
        selectedPrompt = nil
        firstMemoriesViewModel.reset()
        targetScreen = .welcome
        withAnimation(.easeInOut(duration: 0.4)) {
            screen = .welcome
        }
    }

    /// Routes straight to Home when the backend says this account is already
    /// an official couple, even though local onboarding state didn't know it
    /// (e.g. reinstall, or a prior test run that never signed out). Skips the
    /// invite/join screens entirely rather than leaving the user stuck on a
    /// "you're already paired" error with no way to proceed.
    private func resolveAlreadyPaired(partnerName: String? = nil) {
        if let partnerName, !partnerName.isEmpty {
            DataPersistenceManager.shared.saveInviterName(partnerName)
        }
        var profile = DataPersistenceManager.shared.loadCoupleProfile()
        profile.relationshipStage = .officialCouple
        DataPersistenceManager.shared.saveCoupleProfile(profile)
        DataPersistenceManager.shared.clearPendingInviteState()
        DataPersistenceManager.shared.setOnboardingCompleted(true)
        withAnimation(.easeInOut(duration: 0.4)) {
            screen = .home
        }
    }

    private func syncBackgroundMusic(for screen: Screen) {
        let shouldPlay: Bool
        switch screen {
        case .home, .selectPhotos, .officialPending, .loveGarden:
            shouldPlay = true
        default:
            shouldPlay = false
        }
        AudioManager.shared.setGardenActive(shouldPlay)
    }

    /// Resolves the main app screen for a user who has already finished onboarding locally.
    private static func completedOnboardingScreen() -> Screen {
        let lastScreen = DataPersistenceManager.shared.loadLastActiveScreen()
        let stage = DataPersistenceManager.shared.loadCoupleProfile().relationshipStage
        if lastScreen == "officialPending" || DataPersistenceManager.shared.hasPendingPartnerInvite() {
            return .officialPending
        }
        if lastScreen == "selectPhotos" {
            return .selectPhotos
        }
        if stage == .prelude {
            return .prelude
        }
        if stage == .archivedCouple {
            return .archivedCouple
        }
        return .home
    }

    private func applyServerRelationshipStage(_ stage: RelationshipStage, inviteSent: Bool) {
        var profile = DataPersistenceManager.shared.loadCoupleProfile()
        profile.relationshipStage = stage
        profile.inviteSent = inviteSent
        DataPersistenceManager.shared.saveCoupleProfile(profile)
    }

    private func screenForServerRelationshipStage(_ stage: RelationshipStage) -> Screen {
        switch stage {
        case .prelude:
            return .prelude
        case .officialCouple:
            return .home
        case .archivedCouple:
            return .archivedCouple
        }
    }

    /// After sign-in, skip onboarding when local state or the backend says this account
    /// already has a home in Covela.
    private func routeAfterAuthentication() {
        Task {
            if DataPersistenceManager.shared.hasCompletedOnboarding() {
                let destination = Self.completedOnboardingScreen()
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = destination
                    }
                    syncBackgroundMusic(for: destination)
                }
                return
            }

            if let status = try? await InviteAPI.client.checkPairingStatus() {
                if status.paired {
                    await MainActor.run {
                        resolveAlreadyPaired(partnerName: status.partnerName)
                    }
                    return
                }

                if let stage = status.relationshipStage, stage != .officialCouple {
                    await MainActor.run {
                        applyServerRelationshipStage(stage, inviteSent: status.inviteSent)
                        DataPersistenceManager.shared.setOnboardingCompleted(true)
                        let destination = screenForServerRelationshipStage(stage)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = destination
                        }
                        syncBackgroundMusic(for: destination)
                    }
                    return
                }
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    screen = .welcome
                }
            }
        }
    }

    init() {
        let hasCompletedOnboarding = DataPersistenceManager.shared.hasCompletedOnboarding()
        
        // Always start with launch screen
        _screen = State(initialValue: .launch)
        
        if hasCompletedOnboarding {
            _targetScreen = State(initialValue: Self.completedOnboardingScreen())
            
            _homeViewModel = StateObject(wrappedValue: HomeViewModel(
                pinnedFirstMet: nil,
                pinnedOfficial: UIImage(systemName: "heart.fill")!,
                loadFromPersistence: true
            ))
        } else {
            _targetScreen = State(initialValue: .auth)
            _homeViewModel = StateObject(wrappedValue: HomeViewModel(
                pinnedFirstMet: nil,
                pinnedOfficial: UIImage(systemName: "heart.fill")!,
                moments: []
            ))
        }
    }

    var body: some View {
        ZStack {
            switch screen {
            case .launch:
                LaunchScreenView()
                    .transition(.opacity)
                    .onAppear {
                        // Transition to target screen after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                screen = targetScreen
                            }
                            syncBackgroundMusic(for: targetScreen)
                        }
                    }
            
            case .auth:
                CovelaAuthView(onAuthenticated: routeAfterAuthentication)
                .transition(.opacity)

            case .welcome:
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        // Story onboarding is skipped in the main flow; its
                        // code is preserved (still reachable via Replay story
                        // and reserved for the partner-invite experience).
                        screen = .nickname
                    }
                }
                .transition(.opacity)

            case .storyOnboarding:
                StoryOnboardingFlow(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .home
                        }
                    },
                    onFinishedStory: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .nickname
                        }
                    }
                )
                .transition(.opacity)

            case .nickname:
                NicknameView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .welcome
                        }
                    },
                    onContinue: { nickname in
                        DataPersistenceManager.shared.saveUserNickname(nickname)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .colorTheme
                        }
                    }
                )
                .transition(.opacity)

            case .colorTheme:
                ColorThemeView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .nickname
                        }
                    },
                    onContinue: { theme in
                        ThemeManager.shared.setTheme(theme)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .birthday
                        }
                    }
                )
                .transition(.opacity)

            case .birthday:
                UserBirthdayView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .colorTheme
                        }
                    },
                    onContinue: { birthday in
                        let nickname = DataPersistenceManager.shared.loadUserNickname() ?? ""
                        DataPersistenceManager.shared.saveOnboardingUserBirthday(birthday, nickname: nickname)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .checkInviteCode
                        }
                    }
                )
                .transition(.opacity)

            case .checkInviteCode:
                InviteCodeCheckView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .birthday
                        }
                    },
                    onHaveCode: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .joinWithCode
                        }
                    },
                    onNoCode: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .pathSelector
                        }
                    }
                )
                .transition(.opacity)
                .task {
                    // Local onboarding state can diverge from the backend (reinstall,
                    // stale test account) — confirm we're not already paired before
                    // walking the user through invite/join screens that would dead-end.
                    guard let status = try? await InviteAPI.client.checkPairingStatus(), status.paired else { return }
                    resolveAlreadyPaired(partnerName: status.partnerName)
                }

            case .joinWithCode:
                JoinWithCodeView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .checkInviteCode
                        }
                    },
                    onJoined: { captures, revealerName in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            if captures.isEmpty {
                                screen = .justPickPhotos
                            } else {
                                screen = .partnerGiftReveal(captures: captures, revealerName: revealerName)
                            }
                        }
                    },
                    onAlreadyPaired: { resolveAlreadyPaired() }
                )
                .transition(.opacity)

            case .pathSelector:
                PathSelectorView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .checkInviteCode
                        }
                    },
                    onSelectPrelude: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .preludeOnboarding
                        }
                    },
                    onSelectOfficial: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .firstMemories
                        }
                    }
                )
                .transition(.opacity)

            case .preludeOnboarding:
                PreludeOnboardingView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .pathSelector
                        }
                    },
                    onBegin: {
                        var profile = DataPersistenceManager.shared.loadCoupleProfile()
                        profile.relationshipStage = .prelude
                        DataPersistenceManager.shared.saveCoupleProfile(profile)
                        DataPersistenceManager.shared.setOnboardingCompleted(true)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .prelude
                        }
                    }
                )
                .transition(.opacity)

            case .firstMemories:
                FirstMemoriesView(
                    viewModel: firstMemoriesViewModel,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .pathSelector
                        }
                    },
                    onFinished: { firstMet, official, firstMetDate, officialDate in
                    firstMetPhoto = firstMet
                    officialPhoto = official

                    let now = Date()
                    let officialPhotoDate = officialDate ?? now

                    // Replace any prior founding rows (e.g. user went back and changed photos).
                    homeViewModel.upsertFoundingMoment(
                        promptText: "When we became official",
                        image: official,
                        dateTaken: officialPhotoDate,
                        assetIdentifier: nil,
                        latitude: nil,
                        longitude: nil,
                        pinnedAt: now
                    )

                    if let firstMet {
                        let firstMetPhotoDate = firstMetDate ?? now
                        homeViewModel.upsertFoundingMoment(
                            promptText: "When we first met",
                            image: firstMet,
                            dateTaken: firstMetPhotoDate,
                            assetIdentifier: nil,
                            latitude: nil,
                            longitude: nil,
                            pinnedAt: now.addingTimeInterval(-1)
                        )
                    }

                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .invitePartner
                    }
                    }
                )
                .transition(.opacity)

            case .howItWorks:
                HowItWorksView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .firstMemories
                        }
                    },
                    onEnterHome: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .photoAccess
                        }
                    }
                )
                .transition(.opacity)

            case .photoAccess:
                PhotoAccessView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .howItWorks
                        }
                    },
                    onContinue: {
                        DataPersistenceManager.shared.setOnboardingCompleted(true)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .home
                        }
                    }
                )
                .transition(.opacity)

            case .home:
                HomeView(
                    viewModel: homeViewModel,
                    onSelectPhotos: {
                        screen = .selectPhotos
                    },
                    onOpenPhotoViewer: { _, _ in },
                    onResetApp: resetAppToWelcome,
                    onReplayStory: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .storyOnboarding
                        }
                    },
                    onLogOut: {
                        AuthService.shared.signOut()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .auth
                        }
                    },
                    onDeleteAccount: {
                        resetAppToWelcome()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .auth
                        }
                    },
                    selectedPrompt: $selectedPrompt
                )
                .transition(.identity)
                .onAppear {
                    homeViewModel.checkAndReleasePhotos()
                    DataPersistenceManager.shared.saveLastActiveScreen("home")
                }

            case .selectPhotos:
                SelectPhotosView(
                    selectedPrompt: selectedPrompt,
                    onBack: {
                        screen = .home
                    },
                    onSaveMoments: { moments in
                        homeViewModel.addMoments(moments)
                        selectedPrompt = nil
                        shouldScrollToNewMemory = true
                    },
                    onSavePromptMemory: { memory in
                        homeViewModel.addPromptMemory(memory)
                        selectedPrompt = nil
                        shouldScrollToNewMemory = true
                    }
                )
                .transition(.identity)
                .onAppear {
                    DataPersistenceManager.shared.saveLastActiveScreen("selectPhotos")
                }

            case .loveGarden:
                CoupleProfileView(homeViewModel: homeViewModel, onBack: {
                    withAnimation(.easeInOut(duration: 0.4)) { screen = .home }
                })
                .transition(.opacity)

            case .prelude:
                PreludeHomeView(
                    onReturnToOnboarding: {
                        DataPersistenceManager.shared.setOnboardingCompleted(false)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .welcome
                        }
                    },
                    onSwitchToOfficial: {
                        var profile = DataPersistenceManager.shared.loadCoupleProfile()
                        profile.relationshipStage = .officialCouple
                        DataPersistenceManager.shared.saveCoupleProfile(profile)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .home
                        }
                    },
                    onSimulatePartnerInvite: {
                        let testName = "Alex"
                        DataPersistenceManager.shared.saveInviterName(testName)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .partnerOnboarding(inviterName: testName)
                        }
                    }
                )
                .transition(.opacity)

            case .archivedCouple:
                Group {
                    if let bundle = DataPersistenceManager.shared.loadArchiveBundle() {
                        ScrapbookHomeView(
                            bundle: bundle,
                            onClose: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    screen = .prelude
                                }
                            },
                            onStepOut: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    screen = .prelude
                                }
                            },
                            onReconnect: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    screen = .home
                                }
                            }
                        )
                    } else {
                        Color.clear.onAppear { screen = .home }
                    }
                }
                .transition(.opacity)

            case .partnerOnboarding(let inviterName):
                PartnerOnboardingFlow(
                    inviterName: inviterName,
                    onComplete: {
                        var profile = DataPersistenceManager.shared.loadCoupleProfile()
                        profile.relationshipStage = .officialCouple
                        DataPersistenceManager.shared.saveCoupleProfile(profile)
                        DataPersistenceManager.shared.saveInviterName(inviterName)
                        DataPersistenceManager.shared.setPartnerAccount(true)
                        DataPersistenceManager.shared.setOnboardingCompleted(true)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .home
                        }
                    }
                )
                .transition(.opacity)

            case .invitePartner:
                OnboardingInviteView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .firstMemories
                        }
                    },
                    onSkip: {
                        DataPersistenceManager.shared.setOnboardingCompleted(true)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .officialPending
                        }
                    },
                    onPartnerJoined: { captures, revealerName in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            if captures.isEmpty {
                                screen = .justPickPhotos
                            } else {
                                screen = .partnerGiftReveal(captures: captures, revealerName: revealerName)
                            }
                        }
                    },
                    onAlreadyPaired: { resolveAlreadyPaired() }
                )
                .transition(.opacity)

            case .officialPending:
                PendingHomeView(
                    onPartnerJoined: { captures, revealerName in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            if captures.isEmpty {
                                screen = .justPickPhotos
                            } else {
                                screen = .partnerGiftReveal(captures: captures, revealerName: revealerName)
                            }
                        }
                    },
                    onResetApp: resetAppToWelcome,
                    onLogOut: {
                        AuthService.shared.signOut()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .auth
                        }
                    },
                    onDeleteAccount: {
                        resetAppToWelcome()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .auth
                        }
                    }
                )
                .transition(.opacity)
                .onAppear {
                    DataPersistenceManager.shared.saveLastActiveScreen("officialPending")
                }

            case .partnerGiftReveal(let captures, let revealerName):
                PartnerGiftRevealView(
                    captures: captures,
                    revealerName: revealerName,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .justPickPhotos
                        }
                    }
                )
                .transition(.opacity)

            case .justPickPhotos:
                JustPickPhotosView(
                    officialPhoto: officialPhoto ?? UIImage(systemName: "heart.fill")!,
                    firstMetPhoto: firstMetPhoto,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .howItWorks
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.openCameraNotificationName)) { _ in
            if screen == .home || screen == .selectPhotos {
                screen = .selectPhotos
            } else if DataPersistenceManager.shared.hasCompletedOnboarding() {
                screen = .selectPhotos
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.openScrapbookNotificationName)) { _ in
            guard screen != .archivedCouple else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .archivedCouple
            }
        }
        .task {
            StoreManager.shared.start()
        }
        .onAppear {
            NotificationManager.shared.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                NotificationManager.shared.refresh()
            }
        }
        .onChange(of: screen) { _, newScreen in
            syncBackgroundMusic(for: newScreen)
        }
        .onOpenURL { url in
            guard url.scheme == "babytown",
                  url.host == "invite" else { return }
            let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "from" })?
                .value ?? "your partner"
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .partnerOnboarding(inviterName: name)
            }
        }
    }
}

#Preview {
    ContentView()
}
