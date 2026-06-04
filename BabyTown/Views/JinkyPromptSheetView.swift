import SwiftUI

struct JinkyPromptSheetView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var generator = JinkyPromptGenerator()
    
    var onProceed: (PromptItem) -> Void
    
    @State private var promptOfDay: PromptItem?
    @State private var alternativePrompts: [PromptItem] = []
    @State private var selectedPrompt: PromptItem?
    @State private var showAlternatives = false
    @State private var allShownPrompts: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            handle
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    greeting
                    
                    if !showAlternatives {
                        promptOfDaySection
                    } else {
                        alternativesSection
                    }
                    
                    if !showAlternatives {
                        moreButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            
            Spacer()
            
            continueButton
        }
        .background(
            Color.white
                .ignoresSafeArea()
        )
        .onAppear {
            promptOfDay = generator.getPromptOfTheDay()
            selectedPrompt = promptOfDay
            if let prompt = promptOfDay {
                allShownPrompts.insert(prompt.text)
            }
        }
    }
    
    // MARK: - Handle
    
    private var handle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
    
    // MARK: - Greeting
    
    private var greeting: some View {
        let name = DataPersistenceManager.shared.loadUserNickname() ?? "there"
        return ChatBubbleView(
            message: "Hi \(name)! Here is the prompt of the day!",
            isFromJinky: true
        )
    }
    
    // MARK: - Prompt of Day
    
    private var promptOfDaySection: some View {
        Group {
            if let prompt = promptOfDay {
                PromptCardView(
                    prompt: prompt,
                    isSelected: selectedPrompt?.id == prompt.id,
                    onTap: {
                        selectedPrompt = prompt
                        onProceed(prompt)
                    }
                )
            }
        }
    }
    
    // MARK: - Alternatives
    
    private var alternativesSection: some View {
        VStack(spacing: 12) {
            ForEach(alternativePrompts) { prompt in
                PromptCardView(
                    prompt: prompt,
                    isSelected: selectedPrompt?.id == prompt.id,
                    onTap: {
                        selectedPrompt = prompt
                    }
                )
            }
            
            refreshButton
        }
    }
    
    // MARK: - More Button
    
    private var moreButton: some View {
        Button {
            loadNewAlternatives()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text("Give me 3 more")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BabyTownTheme.accentMuted)
                    .shadow(color: BabyTownTheme.accent.opacity(0.2), radius: 6, y: 2)
            )
        }
    }
    
    private var refreshButton: some View {
        Button {
            loadNewAlternatives()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Refresh for 3 New Prompts")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BabyTownTheme.accentGradient)
                    .shadow(color: BabyTownTheme.buttonShadow, radius: 8, y: 3)
            )
        }
        .padding(.top, 8)
    }
    
    private func loadNewAlternatives() {
        withAnimation(.easeInOut(duration: 0.3)) {
            var newPrompts: [PromptItem] = []
            var attempts = 0
            let maxAttempts = 20
            
            while newPrompts.count < 3 && attempts < maxAttempts {
                let candidates = generator.getThreeAlternatives(excluding: promptOfDay)
                for candidate in candidates {
                    if !allShownPrompts.contains(candidate.text) && newPrompts.count < 3 {
                        newPrompts.append(candidate)
                        allShownPrompts.insert(candidate.text)
                    }
                }
                attempts += 1
            }
            
            if newPrompts.isEmpty {
                generator.resetUsedPrompts()
                allShownPrompts.removeAll()
                if let prompt = promptOfDay {
                    allShownPrompts.insert(prompt.text)
                }
                newPrompts = generator.getThreeAlternatives(excluding: promptOfDay)
                newPrompts.forEach { allShownPrompts.insert($0.text) }
            }
            
            alternativePrompts = newPrompts
            selectedPrompt = alternativePrompts.first
            showAlternatives = true
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        VStack {
            Button {
                if let selected = selectedPrompt {
                    onProceed(selected)
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                            .shadow(color: BabyTownTheme.buttonShadow, radius: 12, y: 6)
                    )
            }
            .disabled(selectedPrompt == nil)
            .opacity(selectedPrompt == nil ? 0.5 : 1.0)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(
            Color.white
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        )
    }
}

#Preview {
    JinkyPromptSheetView { prompt in
        print("Selected: \(prompt.text)")
    }
}
