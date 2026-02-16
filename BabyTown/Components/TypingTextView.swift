import SwiftUI

struct TypingTextView: View {
    let text: String
    let font: Font
    let color: Color
    
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    var body: some View {
        Text(displayedText)
            .font(font)
            .foregroundStyle(color)
            .onAppear {
                startTypingAnimation()
            }
    }
    
    private func startTypingAnimation() {
        displayedText = ""
        currentIndex = 0

        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText.append(text[index])
                currentIndex += 1
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    startTypingAnimation()
                }
            }
        }
    }
}
