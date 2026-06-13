//
//  ContentView.swift
//  BabyTown
//
//  Created by Justin Seo on 2/12/26.
//

import SwiftUI

struct ContentView: View {

    enum Screen {
        case launch, welcome, storyOnboarding, nickname, colorTheme, birthday
        case pathSelector          // NEW — branch point after birthday
        case firstMemories, howItWorks, photoAccess, home, selectPhotos
        case loveGarden   // TEMP (Slice 1): direct route to verify the garden; remove when the cat-room door lands.
        case prelude
        case preludeOnboarding     // NEW — prelude intro screen
        case archivedCouple
    }

    @State private var screen: Screen = .launch
    @State private var targetScreen: Screen = .welcome
    @State private var firstMetPhoto: UIImage?
    @State private var officialPhoto: UIImage?
    @State private var selectedPrompt: PromptItem?
    @State private var shouldScrollToNewMemory = false
    @StateObject private var homeViewModel: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase
    init() {
        let hasCompletedOnboarding = DataPersistenceManager.shared.hasCompletedOnboarding()
        
        // Always start with launch screen
        _screen = State(initialValue: .launch)
        
        if hasCompletedOnboarding {
            let lastScreen = DataPersistenceManager.shared.loadLastActiveScreen()
            let stage = DataPersistenceManager.shared.loadCoupleProfile().relationshipStage
            if lastScreen == "selectPhotos" {
                _targetScreen = State(initialValue: .selectPhotos)
            } else if stage == .prelude {
                _targetScreen = State(initialValue: .prelude)
            } else if stage == .archivedCouple {
                _targetScreen = State(initialValue: .archivedCouple)
            } else {
                _targetScreen = State(initialValue: .home)
            }
            
            _homeViewModel = StateObject(wrappedValue: HomeViewModel(
                pinnedFirstMet: nil,
                pinnedOfficial: UIImage(systemName: "heart.fill")!,
                loadFromPersistence: true
            ))
        } else {
            _targetScreen = State(initialValue: .welcome)
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
                        }
                    }
            
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
                            screen = .pathSelector
                        }
                    }
                )
                .transition(.opacity)

            case .pathSelector:
                PathSelectorView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .birthday
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
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .birthday
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
                        screen = .howItWorks
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
                    onResetApp: {
                        DataPersistenceManager.shared.clearAllData()
                        StoreManager.shared.resetForTesting()
                        homeViewModel.moments = []
                        homeViewModel.promptMemories = []
                        homeViewModel.pinnedFirstMet = nil
                        homeViewModel.pinnedOfficial = UIImage(systemName: "heart.fill")!
                        homeViewModel.polaroidStore.reset()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .welcome
                        }
                    },
                    onReplayStory: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .storyOnboarding
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
                    }
                )
                .transition(.opacity)

            case .archivedCouple:
                Group {
                    if let bundle = DataPersistenceManager.shared.loadArchiveBundle() {
                        ScrapbookHomeView(
                            bundle: bundle,
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
    }
}

#Preview {
    ContentView()
}
