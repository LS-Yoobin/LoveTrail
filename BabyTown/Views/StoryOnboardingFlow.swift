import SwiftUI

struct StoryOnboardingFlow: View {
    let onFinishedStory: () -> Void
    
    @State private var currentSceneIndex = 0
    @State private var interactionComplete = false
    @State private var scene1AnimationTriggered = false
    @State private var completedScenes: Set<Int> = []
    
    private let scenes = StoryScene.allScenes
    
    var body: some View {
        ZStack {
            StoryOnboardingTheme.backgroundBlush
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HeartProgressIndicator(
                    totalScenes: scenes.count,
                    currentScene: currentSceneIndex
                )
                .padding(.top, 20)
                
                TabView(selection: $currentSceneIndex) {
                    ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                        SceneContentView(
                            scene: scene,
                            isInteractionComplete: Binding(
                                get: { index == currentSceneIndex ? interactionComplete : false },
                                set: { newValue in
                                    if index == currentSceneIndex {
                                        interactionComplete = newValue
                                    }
                                }
                            )
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentSceneIndex) { oldValue, newValue in
                    // Prevent forward navigation to incomplete scenes
                    if newValue > oldValue && !completedScenes.contains(oldValue) {
                        // Revert to previous scene if trying to swipe forward without completing
                        DispatchQueue.main.async {
                            currentSceneIndex = oldValue
                        }
                        return
                    }

                    // Start ringtone when arriving at "The Unexpected Call" (scene index 1)
                    if newValue == 1 {
                        AudioManager.shared.playRingtone()
                    } else if oldValue == 1 {
                        AudioManager.shared.stopRingtone()
                    }

                    // Start footsteps when arriving at "Knight in Pajamas" (scene index 2)
                    if newValue == 2 {
                        AudioManager.shared.playFootsteps()
                    } else if oldValue == 2 {
                        AudioManager.shared.stopFootsteps()
                    }

                    // Reset interaction state when changing scenes
                    interactionComplete = completedScenes.contains(newValue)
                }
                
                Spacer()
                    .frame(height: 20)
                
                PrimaryCTAButton(
                    text: currentSceneIndex == 0 && !scene1AnimationTriggered ? "Concert Lights" : (currentSceneIndex == 0 && scene1AnimationTriggered ? "Next" : scenes[currentSceneIndex].ctaText),
                    isEnabled: currentSceneIndex == 0 ? true : interactionComplete,
                    action: handleCTAAction
                )
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled()
    }
    
    private func handleCTAAction() {
        // Special handling for Scene 1 - trigger animation first
        if currentSceneIndex == 0 && !scene1AnimationTriggered {
            scene1AnimationTriggered = true
            interactionComplete = true
             AudioManager.shared.playConcertMusic()
            return
        }
        
        // Mark current scene as completed before advancing
        completedScenes.insert(currentSceneIndex)

        // Stop music if we are moving away from scene 1
        if currentSceneIndex == 0 {
             AudioManager.shared.stopMusic()
        }

        // Stop ringtone when answering the call (scene 2)
        if currentSceneIndex == 1 {
            AudioManager.shared.stopRingtone()
        }

        // Stop footsteps when riding into the night (scene 3)
        if currentSceneIndex == 2 {
            AudioManager.shared.stopFootsteps()
        }
        
        if currentSceneIndex < scenes.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentSceneIndex += 1
                interactionComplete = false
                scene1AnimationTriggered = false
            }
        } else {
            onFinishedStory()
        }
    }
}

struct SceneContentView: View {
    let scene: StoryScene
    @Binding var isInteractionComplete: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(scene.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(StoryOnboardingTheme.textDark)
                        .multilineTextAlignment(.center)
                    
                    if let subtitle = scene.subtitle {
                        Text(subtitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(StoryOnboardingTheme.textDark.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                
                interactionView
                    .padding(.vertical, 20)
                
                Text(scene.storyText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(StoryOnboardingTheme.textDark.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                
                Spacer()
                    .frame(minHeight: 40)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(scene.id == 5)
    }
    
    @ViewBuilder
    private var interactionView: some View {
        switch scene.interactionType {
        case .concertLight:
            Scene1ConcertView(isInteractionComplete: $isInteractionComplete)
        case .phoneCall:
            Scene2PhoneCallView(isInteractionComplete: $isInteractionComplete)
        case .checklist:
            Scene3ChecklistView(isInteractionComplete: $isInteractionComplete)
        case .mapNavigate:
            Scene4MapView(isInteractionComplete: $isInteractionComplete)
        case .heartTrail:
            Scene5HeartTrailView(isInteractionComplete: $isInteractionComplete)
        }
    }
}

#Preview {
    StoryOnboardingFlow {
        print("Story finished!")
    }
}

#Preview("Scene 1 Only") {
    SceneContentView(
        scene: StoryScene.allScenes[0],
        isInteractionComplete: .constant(false)
    )
    .background(StoryOnboardingTheme.backgroundBlush)
}

#Preview("Scene 2 Only") {
    SceneContentView(
        scene: StoryScene.allScenes[1],
        isInteractionComplete: .constant(false)
    )
    .background(StoryOnboardingTheme.backgroundBlush)
}

#Preview("Scene 3 Only") {
    SceneContentView(
        scene: StoryScene.allScenes[2],
        isInteractionComplete: .constant(false)
    )
    .background(StoryOnboardingTheme.backgroundBlush)
}

#Preview("Scene 4 Only") {
    SceneContentView(
        scene: StoryScene.allScenes[3],
        isInteractionComplete: .constant(false)
    )
    .background(StoryOnboardingTheme.backgroundBlush)
}

#Preview("Scene 5 Only") {
    SceneContentView(
        scene: StoryScene.allScenes[4],
        isInteractionComplete: .constant(false)
    )
    .background(StoryOnboardingTheme.backgroundBlush)
}
