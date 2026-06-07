import AVFoundation
import Foundation

enum BackgroundMusicTrimmer {

    static let minimumSelectionDuration: TimeInterval = 1.0

    enum TrimError: LocalizedError {
        case invalidRange
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .invalidRange:
                return "Selected clip must be at least 1 second long."
            case .exportFailed:
                return "Couldn't trim that clip. Try a shorter selection."
            }
        }
    }

    static func duration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let loadedDuration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(loadedDuration)
        guard seconds.isFinite, seconds > 0 else {
            throw TrimError.invalidRange
        }
        return seconds
    }

    static func exportTrimmed(
        sourceURL: URL,
        startSeconds: TimeInterval,
        endSeconds: TimeInterval
    ) async throws -> URL {
        guard startSeconds >= 0,
              endSeconds > startSeconds,
              endSeconds - startSeconds >= minimumSelectionDuration else {
            throw TrimError.invalidRange
        }

        let asset = AVURLAsset(url: sourceURL)
        let startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
        let endTime = CMTime(seconds: endSeconds, preferredTimescale: 600)
        let range = CMTimeRange(start: startTime, end: endTime)

        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw TrimError.exportFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trim_\(UUID().uuidString).m4a")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.timeRange = range

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exporter.status == .completed else {
            try? FileManager.default.removeItem(at: outputURL)
            throw TrimError.exportFailed
        }

        return outputURL
    }

    static func isFullClipSelection(
        startSeconds: TimeInterval,
        endSeconds: TimeInterval,
        duration: TimeInterval
    ) -> Bool {
        let epsilon = 0.05
        return startSeconds <= epsilon && endSeconds >= duration - epsilon
    }

    static func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}
