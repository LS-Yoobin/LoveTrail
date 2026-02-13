import SwiftUI

struct PrimaryCTAButton: View {
    let text: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: StoryOnboardingTheme.cornerRadius)
                        .fill(isEnabled ? StoryOnboardingTheme.primaryRed : Color.gray.opacity(0.3))
                )
                .shadow(color: isEnabled ? StoryOnboardingTheme.primaryRed.opacity(0.3) : Color.clear, radius: StoryOnboardingTheme.shadowRadius, x: 0, y: 4)
        }
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.3), value: isEnabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryCTAButton(text: "Start the story", isEnabled: true) {}
        PrimaryCTAButton(text: "Answer the call", isEnabled: false) {}
    }
    .padding()
    .background(StoryOnboardingTheme.backgroundBlush)
}
