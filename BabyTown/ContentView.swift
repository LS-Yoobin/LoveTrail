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
                    onOpenPhotoViewer: { _, _ in }
                )
                .transition(.opacity)
                .onAppear {
                    homeViewModel.checkAndReleasePhotos()
                }

            case .selectPhotos:
                SelectPhotosView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            screen = .home
                        }
                    },
                    onSaveMoments: { moments in
                        homeViewModel.addMoments(moments)
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
