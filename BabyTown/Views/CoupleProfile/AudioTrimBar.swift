import SwiftUI

/// Dual-handle timeline for selecting an audio clip range.
struct AudioTrimBar: View {
    let duration: TimeInterval
    @Binding var startSeconds: TimeInterval
    @Binding var endSeconds: TimeInterval

    private let handleWidth: CGFloat = 24
    private let barHeight: CGFloat = 48
    private let minimumGap: TimeInterval = BackgroundMusicTrimmer.minimumSelectionDuration

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let startX = position(for: startSeconds, width: width)
                let endX = position(for: endSeconds, width: width)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: barHeight)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(BabyTownTheme.accent.opacity(0.35))
                        .frame(width: max(0, endX - startX), height: barHeight)
                        .offset(x: startX)

                    trimHandle
                        .offset(x: startX - handleWidth / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let proposed = seconds(at: value.location.x, width: width)
                                    let clamped = min(proposed, endSeconds - minimumGap)
                                    startSeconds = max(0, clamped)
                                }
                        )

                    trimHandle
                        .offset(x: endX - handleWidth / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let proposed = seconds(at: value.location.x, width: width)
                                    let clamped = max(proposed, startSeconds + minimumGap)
                                    endSeconds = min(duration, clamped)
                                }
                        )
                }
            }
            .frame(height: barHeight)

            HStack {
                Text(BackgroundMusicTrimmer.formatTime(startSeconds))
                Spacer()
                Text(BackgroundMusicTrimmer.formatTime(endSeconds - startSeconds))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(BackgroundMusicTrimmer.formatTime(endSeconds))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.primary)

            if endSeconds - startSeconds < minimumGap {
                Text("Selected clip must be at least 1 second.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var trimHandle: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: handleWidth, height: barHeight + 8)
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .fill(BabyTownTheme.accent)
                    .frame(width: 3, height: barHeight - 8)
            }
    }

    private func position(for seconds: TimeInterval, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let ratio = min(max(seconds / duration, 0), 1)
        return ratio * width
    }

    private func seconds(at x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0, duration > 0 else { return 0 }
        let ratio = min(max(x / width, 0), 1)
        return ratio * duration
    }
}
