//
//  ContentView.swift
//  BabyTown
//
//  Created by Justin Seo on 2/12/26.
//

import SwiftUI

struct ContentView: View {

    enum Screen {
        case launch, welcome, storyOnboarding, nickname, firstMemories, howItWorks, photoAccess, home, selectPhotos
        case loveGarden   // TEMP (Slice 1): direct route to verify the garden; remove when the cat-room door lands.
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
            // Check if user was last on the camera screen
            let lastScreen = DataPersistenceManager.shared.loadLastActiveScreen()
            if lastScreen == "selectPhotos" {
                _targetScreen = State(initialValue: .selectPhotos)
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
                StoryOnboardingFlow {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .nickname
                    }
                }
                .transition(.opacity)

            case .nickname:
                NicknameView { nickname in
                    DataPersistenceManager.shared.saveUserNickname(nickname)
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .firstMemories
                    }
                }
                .transition(.opacity)

            case .firstMemories:
                FirstMemoriesView { firstMet, official, firstMetDate, officialDate in
                    firstMetPhoto = firstMet
                    officialPhoto = official
                    homeViewModel.pinnedFirstMet = firstMet
                    homeViewModel.pinnedOfficial = official
                    
                    // Create moments for the first two memories
                    var onboardingMoments: [Moment] = []
                    let now = Date()
                    
                    // Use the actual photo date or fallback to current date
                    let officialPhotoDate = officialDate ?? now
                    
                    // Add "When we became official" - both pinned and unpinned versions
                    let officialMomentPinned = Moment(
                        id: UUID(),
                        dateTaken: officialPhotoDate,
                        assetIdentifier: nil,
                        thumbnail: official,
                        placeName: nil,
                        caption: nil,
                        voiceNotePath: nil,
                        promptText: "When we became official",
                        isPinned: true,
                        pinnedAt: now
                    )
                    onboardingMoments.append(officialMomentPinned)
                    
                    let officialMomentUnpinned = Moment(
                        id: UUID(),
                        dateTaken: officialPhotoDate,
                        assetIdentifier: nil,
                        thumbnail: official,
                        placeName: nil,
                        caption: nil,
                        voiceNotePath: nil,
                        promptText: "When we became official",
                        isPinned: false,
                        pinnedAt: nil
                    )
                    onboardingMoments.append(officialMomentUnpinned)
                    
                    // Add "When we first met" - both pinned and unpinned versions (if provided)
                    if let firstMet = firstMet {
                        // Use the actual photo date or fallback to current date
                        let firstMetPhotoDate = firstMetDate ?? now
                        
                        let firstMetMomentPinned = Moment(
                            id: UUID(),
                            dateTaken: firstMetPhotoDate,
                            assetIdentifier: nil,
                            thumbnail: firstMet,
                            placeName: nil,
                            caption: nil,
                            voiceNotePath: nil,
                            promptText: "When we first met",
                            isPinned: true,
                            pinnedAt: now.addingTimeInterval(-1)
                        )
                        onboardingMoments.append(firstMetMomentPinned)
                        
                        let firstMetMomentUnpinned = Moment(
                            id: UUID(),
                            dateTaken: firstMetPhotoDate,
                            assetIdentifier: nil,
                            thumbnail: firstMet,
                            placeName: nil,
                            caption: nil,
                            voiceNotePath: nil,
                            promptText: "When we first met",
                            isPinned: false,
                            pinnedAt: nil
                        )
                        onboardingMoments.append(firstMetMomentUnpinned)
                    }
                    
                    DataPersistenceManager.shared.saveFoundingPhotoDate(officialPhotoDate, promptText: "When we became official")
                    if let firstMetDate {
                        DataPersistenceManager.shared.saveFoundingPhotoDate(firstMetDate, promptText: "When we first met")
                    }

                    homeViewModel.addMoments(onboardingMoments)
                    
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .howItWorks
                    }
                }
                .transition(.opacity)

            case .howItWorks:
                HowItWorksView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .photoAccess
                    }
                }
                .transition(.opacity)

            case .photoAccess:
                PhotoAccessView {
                    DataPersistenceManager.shared.setOnboardingCompleted(true)
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .home
                    }
                }
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.openCameraNotificationName)) { _ in
            if screen == .home || screen == .selectPhotos {
                screen = .selectPhotos
            } else if DataPersistenceManager.shared.hasCompletedOnboarding() {
                screen = .selectPhotos
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
