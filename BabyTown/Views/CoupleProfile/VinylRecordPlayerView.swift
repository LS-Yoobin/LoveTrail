import SwiftUI

/// Tappable vinyl record player; cycles sprite frames while `isPlaying` is true.
struct VinylRecordPlayerView: View {
    let isPlaying: Bool
    var scale: CGFloat = 1
    var onTap: (() -> Void)? = nil

    private static let frameNames = [
        "prop_record_player_0",
        "prop_record_player_1",
        "prop_record_player_2",
        "prop_record_player_3",
    ]

    private static let frameInterval: TimeInterval = 0.22

    @State private var frameIndex = 0
    @State private var animationTask: Task<Void, Never>?

    private var size: CGFloat { 88 * scale }
    private var hasSpriteFrames: Bool {
        Self.frameNames.contains { UIImage(named: $0) != nil }
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    playerArt
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens music controls")
            } else {
                playerArt
            }
        }
        .accessibilityLabel(accessibilityLabelText)
        .onAppear { syncAnimation() }
        .onDisappear { stopFrameAnimation() }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startFrameAnimation()
            } else {
                stopFrameAnimation()
            }
        }
    }

    private var playerArt: some View {
        Group {
            if hasSpriteFrames {
                Image(Self.frameNames[frameIndex])
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                fallbackDisc
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
    }

    private var fallbackDisc: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.15), Color(white: 0.05)],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.36
                    )
                )
            Image(systemName: "opticaldisc")
                .font(.system(size: size * 0.28))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var accessibilityLabelText: String {
        if isPlaying {
            return "Our song, now playing"
        }
        return "Our song"
    }

    private func syncAnimation() {
        if isPlaying {
            startFrameAnimation()
        } else {
            frameIndex = 0
            stopFrameAnimation()
        }
    }

    private func startFrameAnimation() {
        guard hasSpriteFrames else { return }
        stopFrameAnimation()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.frameInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                frameIndex = (frameIndex + 1) % Self.frameNames.count
            }
        }
    }

    private func stopFrameAnimation() {
        animationTask?.cancel()
        animationTask = nil
        frameIndex = 0
    }
}
