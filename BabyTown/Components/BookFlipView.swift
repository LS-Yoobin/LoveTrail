import SwiftUI

struct BookFlipView: View {

    var animating: Bool = true
    var frameInterval: Double = 0.18
    var size: CGFloat = 180

    private static let frames = ["BookFlip1", "BookFlip2", "BookFlip3", "BookFlip4"]

    @State private var frameIndex = 0
    @State private var timer: Timer?

    var body: some View {
        Image(Self.frames[frameIndex])
            .resizable()
            .scaledToFit()
            .frame(width: size)
            .onAppear { startIfNeeded() }
            .onDisappear { stop() }
            .onChange(of: animating) { _, isOn in
                isOn ? startIfNeeded() : stop()
            }
    }

    private func startIfNeeded() {
        guard animating, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            frameIndex = (frameIndex + 1) % Self.frames.count
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    BookFlipView(animating: true, frameInterval: 0.18, size: 200)
        .padding()
}
