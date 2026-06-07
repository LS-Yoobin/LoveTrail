import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioTrimPreviewPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var loopStart: TimeInterval = 0
    private var loopEnd: TimeInterval = 0
    private var loopsPlayback = true
    private var timer: Timer?

    func load(url: URL) throws {
        stop()
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.prepareToPlay()
        player = newPlayer
        currentTime = 0
    }

    func play(from start: TimeInterval, to end: TimeInterval) {
        guard let player else { return }

        loopStart = start
        loopEnd = end
        loopsPlayback = true

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        player.currentTime = start
        currentTime = start
        player.play()
        isPlaying = true
        startTimer()
    }

    /// Plays from `start` to `end` once, then stops (no loop).
    func playOnce(from start: TimeInterval, to end: TimeInterval) {
        guard let player else { return }

        loopStart = start
        loopEnd = end
        loopsPlayback = false

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        player.currentTime = start
        currentTime = start
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        loopStart = 0
        loopEnd = 0
        loopsPlayback = true
        stopTimer()
    }

    func seek(to time: TimeInterval, clampedTo rangeStart: TimeInterval, rangeEnd: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(time, rangeStart), rangeEnd)
        player.currentTime = clamped
        currentTime = clamped
    }

    func updateLoopRange(start: TimeInterval, end: TimeInterval) {
        loopStart = start
        loopEnd = end
        guard let player else { return }

        if player.currentTime < start || player.currentTime > end {
            player.currentTime = start
            currentTime = start
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let player, isPlaying else { return }

        currentTime = player.currentTime

        if player.currentTime >= loopEnd - 0.02 {
            if loopsPlayback {
                player.currentTime = loopStart
                currentTime = loopStart
                if !player.isPlaying {
                    player.play()
                }
            } else {
                player.pause()
                player.currentTime = loopEnd
                currentTime = loopEnd
                isPlaying = false
                stopTimer()
            }
        }
    }
}
