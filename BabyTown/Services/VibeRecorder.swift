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

enum InAppCameraAudioSession {
    static func activateForCamera() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {}
    }

    static func deactivateAfterCamera() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
