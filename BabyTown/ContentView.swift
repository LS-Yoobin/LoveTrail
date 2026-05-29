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
    }

    @State private var screen: Screen = .launch
    @State private var targetScreen: Screen = .welcome
    @State private var firstMetPhoto: UIImage?
    @State private var officialPhoto: UIImage?
    @State private var selectedPrompt: PromptItem?
    @State private var shouldScrollToNewMemory = false
    @StateObject private var homeViewModel: HomeViewModel
    
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
                        screen = .storyOnboarding
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
                        withAnimation(.easeInOut(duration: 0.35)) {
                            screen = .selectPhotos
                        }
                    },
                    onOpenPhotoViewer: { _, _ in },
                    onResetApp: {
                        DataPersistenceManager.shared.clearAllData()
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
                .transition(.opacity)
                .onAppear {
                    homeViewModel.checkAndReleasePhotos()
                    DataPersistenceManager.shared.saveLastActiveScreen("home")
                }

            case .selectPhotos:
                SelectPhotosView(
                    selectedPrompt: selectedPrompt,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            screen = .home
                        }
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
                .transition(.opacity)
                .onAppear {
                    DataPersistenceManager.shared.saveLastActiveScreen("selectPhotos")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.openCameraNotificationName)) { _ in
            // Switch to select photos screen when notification is tapped
            withAnimation(.easeInOut(duration: 0.35)) {
                
                // If we are in the welcome flow, we might want to finish onboarding first or just jump? 
                // Assuming we only want this to work if onboarding is done or we are in home/selectPhotos
                // For now, let's just switch if we are not in the middle of critical onboarding
                if screen == .home || screen == .selectPhotos {
                     screen = .selectPhotos
                } else if DataPersistenceManager.shared.hasCompletedOnboarding() {
                    // If onboarding is done but we are somehow elsewhere
                    screen = .selectPhotos
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
