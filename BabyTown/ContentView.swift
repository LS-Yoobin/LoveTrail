//
//  ContentView.swift
//  BabyTown
//
//  Created by Justin Seo on 2/12/26.
//

import SwiftUI

struct ContentView: View {

    enum Screen {
        case welcome, firstMemories, howItWorks, home, selectPhotos
    }

    @State private var screen: Screen = .welcome
    @State private var firstMetPhoto: UIImage?
    @State private var officialPhoto: UIImage?
    @State private var selectedPrompt: PromptItem?
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
                    
                    // Create pinned moments for the first two memories
                    var onboardingMoments: [Moment] = []
                    let now = Date()
                    
                    // Add "When we became official" as first pinned moment
                    let officialMoment = Moment(
                        id: UUID(),
                        dateTaken: now,
                        assetIdentifier: nil,
                        thumbnail: official,
                        placeName: "When we became official",
                        caption: nil,
                        voiceNotePath: nil,
                        isPinned: true,
                        pinnedAt: now
                    )
                    onboardingMoments.append(officialMoment)
                    
                    // Add "When we first met" as second pinned moment (if provided)
                    if let firstMet = firstMet {
                        let firstMetMoment = Moment(
                            id: UUID(),
                            dateTaken: now.addingTimeInterval(-1), // Slightly earlier so it appears second
                            assetIdentifier: nil,
                            thumbnail: firstMet,
                            placeName: "When we first met",
                            caption: nil,
                            voiceNotePath: nil,
                            isPinned: true,
                            pinnedAt: now.addingTimeInterval(-1)
                        )
                        onboardingMoments.append(firstMetMoment)
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
