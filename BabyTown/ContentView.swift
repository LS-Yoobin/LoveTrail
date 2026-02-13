//
//  ContentView.swift
//  BabyTown
//
//  Created by Justin Seo on 2/12/26.
//

import SwiftUI

struct ContentView: View {

    enum Screen {
        case welcome, storyOnboarding, firstMemories, howItWorks, home, selectPhotos
    }

    @State private var screen: Screen = .welcome
    @State private var firstMetPhoto: UIImage?
    @State private var officialPhoto: UIImage?
    @State private var selectedPrompt: PromptItem?
    @State private var shouldScrollToNewMemory = false
    @StateObject private var homeViewModel: HomeViewModel
    
    init() {
        let hasCompletedOnboarding = DataPersistenceManager.shared.hasCompletedOnboarding()
        
        if hasCompletedOnboarding {
            _screen = State(initialValue: .home)
            _homeViewModel = StateObject(wrappedValue: HomeViewModel(
                pinnedFirstMet: nil,
                pinnedOfficial: UIImage(systemName: "heart.fill")!,
                loadFromPersistence: true
            ))
        } else {
            _screen = State(initialValue: .welcome)
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
                        screen = .firstMemories
                    }
                }
                .transition(.opacity)

            case .firstMemories:
                FirstMemoriesView { firstMet, official in
                    firstMetPhoto = firstMet
                    officialPhoto = official
                    homeViewModel.pinnedFirstMet = firstMet
                    homeViewModel.pinnedOfficial = official
                    
                    // Create moments for the first two memories
                    var onboardingMoments: [Moment] = []
                    let now = Date()
                    
                    // Add "When we became official" - both pinned and unpinned versions
                    let officialMomentPinned = Moment(
                        id: UUID(),
                        dateTaken: now,
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
                        dateTaken: now,
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
                        // Use a date 1 day earlier so it appears in a separate card
                        let firstMetDate = now.addingTimeInterval(-86400)
                        
                        let firstMetMomentPinned = Moment(
                            id: UUID(),
                            dateTaken: firstMetDate,
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
                            dateTaken: firstMetDate,
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
            }
        }
    }
}

#Preview {
    ContentView()
}
