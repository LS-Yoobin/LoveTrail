import SwiftUI

struct HomeMapScrollButton: View {
    let imageHeight: CGFloat
    let mapIsPresented: Bool
    let onUnfoldComplete: () -> Void

    /// Left-to-right in the source sheet: open → mostly → partial → closed.
    private static let frameNames = [
        "home_map_scroll_open",
        "home_map_scroll_mostly",
        "home_map_scroll_partial",
        "home_map_scroll_closed",
    ]
    private static let closedFrameIndex = frameNames.count - 1
    private static let frameInterval: TimeInterval = 0.18

    @State private var frameIndex = closedFrameIndex
    @State private var isAnimating = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Button(action: playUnfoldAnimation) {
            VStack(spacing: 4) {
                Image(Self.frameNames[frameIndex])
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: imageHeight)

                Text("Our Map")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black, in: Capsule())
                    .shadow(color: BabyTownTheme.cardShadow, radius: 2, y: 1)
                    .offset(x: -4)
            }
        }
        .buttonStyle(.plain)
        .disabled(isAnimating)
        .accessibilityLabel("Our Map")
        .onDisappear { stopAnimation(resetToClosed: true) }
        .onChange(of: mapIsPresented) { _, isPresented in
            if !isPresented {
                playFoldAnimation()
            }
        }
    }

    private func playUnfoldAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        stopAnimation(resetToClosed: false)

        animationTask = Task { @MainActor in
            for index in stride(from: Self.closedFrameIndex - 1, through: 0, by: -1) {
                guard !Task.isCancelled else { return }
                frameIndex = index
                try? await Task.sleep(nanoseconds: UInt64(Self.frameInterval * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }
            onUnfoldComplete()
            isAnimating = false
            animationTask = nil
        }
    }

    private func playFoldAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        stopAnimation(resetToClosed: false)
        frameIndex = 0

        animationTask = Task { @MainActor in
            for index in 1 ... Self.closedFrameIndex {
                guard !Task.isCancelled else { return }
                frameIndex = index
                try? await Task.sleep(nanoseconds: UInt64(Self.frameInterval * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }
            isAnimating = false
            animationTask = nil
        }
    }

    private func stopAnimation(resetToClosed: Bool) {
        animationTask?.cancel()
        animationTask = nil
        isAnimating = false
        if resetToClosed {
            frameIndex = Self.closedFrameIndex
        }
    }
}

#Preview {
    HomeMapScrollButton(imageHeight: 72, mapIsPresented: false, onUnfoldComplete: {})
        .padding()
        .background(BabyTownTheme.backgroundGradient)
}
