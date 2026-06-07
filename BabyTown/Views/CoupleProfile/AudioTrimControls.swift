import SwiftUI

/// Shared play/pause + trim bar controls for import trim and edit flows.
struct AudioTrimControls: View {
    let audioURL: URL
    let duration: TimeInterval
    @Binding var startSeconds: TimeInterval
    @Binding var endSeconds: TimeInterval

    @StateObject private var previewPlayer = AudioTrimPreviewPlayer()
    @State private var didLoadPreview = false
    @State private var scrubSeconds: TimeInterval = 0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 20) {
            VinylRecordPlayerView(
                isPlaying: previewPlayer.isPlaying,
                scale: 1.2
            )
            .allowsHitTesting(false)

            Button(action: togglePreview) {
                Label(
                    previewPlayer.isPlaying ? "Pause preview" : "Play preview",
                    systemImage: previewPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(BabyTownTheme.accent)
            }
            .buttonStyle(.plain)
            .disabled(!isSelectionValid)

            AudioTrimBar(
                duration: duration,
                startSeconds: $startSeconds,
                endSeconds: $endSeconds
            )

            scrubSection
        }
        .onAppear {
            loadPreviewIfNeeded()
            syncScrubPosition()
        }
        .onDisappear {
            previewPlayer.stop()
        }
        .onChange(of: startSeconds) { _, _ in
            previewPlayer.pause()
            previewPlayer.updateLoopRange(start: startSeconds, end: endSeconds)
            syncScrubPosition()
        }
        .onChange(of: endSeconds) { _, _ in
            previewPlayer.pause()
            previewPlayer.updateLoopRange(start: startSeconds, end: endSeconds)
            syncScrubPosition()
        }
        .onChange(of: scrubSeconds) { _, newValue in
            guard isScrubbing, isSelectionValid else { return }
            previewPlayer.seek(
                to: newValue,
                clampedTo: startSeconds,
                rangeEnd: endSeconds
            )
        }
        .onChange(of: previewPlayer.currentTime) { _, newTime in
            guard previewPlayer.isPlaying, !isScrubbing else { return }
            if newTime >= startSeconds, newTime <= endSeconds {
                scrubSeconds = newTime
            }
        }
    }

    private var scrubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scrub to preview")
                .font(.subheadline.weight(.semibold))

            Text("Drag to any point — especially the end — to hear how your cut will sound.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isSelectionValid {
                Slider(
                    value: $scrubSeconds,
                    in: scrubRange,
                    onEditingChanged: handleScrubEditingChanged
                )
                .tint(BabyTownTheme.accent)

                HStack {
                    Text(BackgroundMusicTrimmer.formatTime(scrubSeconds))
                        .font(.caption.monospacedDigit())
                    Spacer()
                    if scrubSeconds >= endSeconds - 0.5 {
                        Text("At end cut")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BabyTownTheme.accent)
                    }
                    Spacer()
                    Text(BackgroundMusicTrimmer.formatTime(endSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scrubRange: ClosedRange<Double> {
        let lower = startSeconds
        let upper = max(startSeconds + BackgroundMusicTrimmer.minimumSelectionDuration, endSeconds)
        return lower...upper
    }

    private var isSelectionValid: Bool {
        endSeconds - startSeconds >= BackgroundMusicTrimmer.minimumSelectionDuration
    }

    private func loadPreviewIfNeeded() {
        guard !didLoadPreview else { return }
        didLoadPreview = true
        try? previewPlayer.load(url: audioURL)
    }

    private func syncScrubPosition() {
        scrubSeconds = min(max(scrubSeconds, startSeconds), endSeconds)
        if scrubSeconds < startSeconds {
            scrubSeconds = startSeconds
        }
    }

    private func handleScrubEditingChanged(_ editing: Bool) {
        isScrubbing = editing
        guard isSelectionValid else { return }

        if editing {
            previewPlayer.pause()
            previewPlayer.seek(
                to: scrubSeconds,
                clampedTo: startSeconds,
                rangeEnd: endSeconds
            )
        } else {
            let playbackStart: TimeInterval
            if scrubSeconds >= endSeconds - 0.25 {
                playbackStart = max(startSeconds, endSeconds - 2)
            } else {
                playbackStart = scrubSeconds
            }
            previewPlayer.playOnce(from: playbackStart, to: endSeconds)
        }
    }

    private func togglePreview() {
        guard isSelectionValid else { return }
        if previewPlayer.isPlaying {
            previewPlayer.pause()
        } else {
            scrubSeconds = startSeconds
            previewPlayer.play(from: startSeconds, to: endSeconds)
        }
    }
}
