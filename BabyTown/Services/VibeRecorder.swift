import AVFoundation
import AVFAudio
import Combine
import Foundation

final class VibeRecorder: NSObject, ObservableObject {
    private var recorder: AVAudioRecorder?
    private var sessionTempURL: URL?

    var isRecording: Bool { recorder?.isRecording == true }

    func start() {
        guard recorder == nil else { return }
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async { self?.beginRecording() }
        }
    }

    func stopAndTrimLast10Seconds() async -> URL? {
        guard let rec = recorder, rec.isRecording else {
            cancelAndDelete()
            return nil
        }
        let sourceURL = rec.url
        let duration = rec.currentTime
        rec.stop()
        recorder = nil
        return await trim(sourceURL: sourceURL, totalDuration: duration, maxSeconds: 10)
    }

    func cancelAndDelete() {
        let url = recorder?.url ?? sessionTempURL
        recorder?.stop()
        recorder = nil
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        sessionTempURL = nil
    }

    private func beginRecording() {
        guard recorder == nil else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            return
        }

        let url = makeTempURL()
        sessionTempURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.delegate = self
            rec.record()
            recorder = rec
        } catch {
            try? FileManager.default.removeItem(at: url)
            sessionTempURL = nil
        }
    }

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("vibe_\(UUID().uuidString).m4a")
    }

    private func trim(sourceURL: URL, totalDuration: TimeInterval, maxSeconds: TimeInterval) async -> URL? {
        let asset = AVURLAsset(url: sourceURL)
        let startSeconds = max(0, totalDuration - maxSeconds)
        let startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
        let endTime = CMTime(seconds: totalDuration, preferredTimescale: 600)
        let range = CMTimeRange(start: startTime, end: endTime)

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            try? FileManager.default.removeItem(at: sourceURL)
            return nil
        }

        let outputURL = makeTempURL()
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.timeRange = range
        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        try? FileManager.default.removeItem(at: sourceURL)
        sessionTempURL = nil

        if exporter.status == .completed {
            return outputURL
        } else {
            try? FileManager.default.removeItem(at: outputURL)
            return nil
        }
    }
}

extension VibeRecorder: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        cancelAndDelete()
    }
}

private enum GardenMusicSuppression {
    static func pauseIfPlaying(into didPause: inout Bool) {
        guard AudioManager.shared.gardenIsActive else { return }
        guard !didPause else { return }
        didPause = CoupleMusicPlaybackState.shared.isPlaying
        if didPause {
            AudioManager.shared.pauseGardenMusic()
        }
    }

    static func resumeIfPaused(_ didPause: inout Bool) {
        guard AudioManager.shared.gardenIsActive else { return }
        guard didPause else { return }
        didPause = false
        AudioManager.shared.resumeGardenMusic()
    }

    static func restorePlaybackAudioSession() {
        guard AudioManager.shared.gardenIsActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {}
    }
}

enum InAppCameraAudioSession {
    private static var didPauseHomeMusic = false
    private static var isCameraOpen = false

    /// Call when the in-app camera UI appears. Pauses OUR SONG if it was playing.
    static func enterCamera(needsMicCapture: Bool, forVideoRecording: Bool = false) {
        isCameraOpen = true
        GardenMusicSuppression.pauseIfPlaying(into: &didPauseHomeMusic)
        configureAudioSession(needsMicCapture: needsMicCapture, forVideoRecording: forVideoRecording)
    }

    /// Updates mic / reel audio routing while the camera stays open. Does not resume OUR SONG.
    static func updateAudioSession(needsMicCapture: Bool, forVideoRecording: Bool = false) {
        guard isCameraOpen else { return }
        configureAudioSession(needsMicCapture: needsMicCapture, forVideoRecording: forVideoRecording)
    }

    /// Call when the in-app camera UI is dismissed. Resumes OUR SONG if we paused it.
    static func leaveCamera() {
        guard isCameraOpen else { return }
        isCameraOpen = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        GardenMusicSuppression.restorePlaybackAudioSession()
        GardenMusicSuppression.resumeIfPaused(&didPauseHomeMusic)
    }

    static func activateForCamera(forVideoRecording: Bool = false) {
        enterCamera(needsMicCapture: true, forVideoRecording: forVideoRecording)
    }

    static func deactivateAfterCamera() {
        leaveCamera()
    }

    static func deactivateForReelPlayback() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func configureAudioSession(needsMicCapture: Bool, forVideoRecording: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if needsMicCapture {
                if forVideoRecording {
                    try session.setCategory(
                        .playAndRecord,
                        mode: .videoRecording,
                        options: [.defaultToSpeaker, .allowBluetooth]
                    )
                } else {
                    try session.setCategory(
                        .playAndRecord,
                        mode: .default,
                        options: [.defaultToSpeaker, .allowBluetoothHFP]
                    )
                }
            } else {
                try session.setCategory(.ambient, mode: .default)
            }
            try session.setActive(true)
        } catch {}
    }
}

enum WatchTogetherAudioSession {
    private static var didPauseHomeMusic = false
    private static var isPlayerOpen = false

    /// Call when the Watch Together player appears. Pauses OUR SONG if it was playing.
    static func enterPlayer() {
        guard !isPlayerOpen else { return }
        isPlayerOpen = true
        GardenMusicSuppression.pauseIfPlaying(into: &didPauseHomeMusic)
    }

    /// Call when the Watch Together player is dismissed. Resumes OUR SONG if we paused it.
    static func leavePlayer() {
        guard isPlayerOpen else { return }
        isPlayerOpen = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        GardenMusicSuppression.restorePlaybackAudioSession()
        GardenMusicSuppression.resumeIfPaused(&didPauseHomeMusic)
    }
}
