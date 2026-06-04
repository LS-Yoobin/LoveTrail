import AVFoundation
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum BackgroundMusicImporter {

    enum ImportError: LocalizedError {
        case unreadableVideo
        case noAudioTrack
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .unreadableVideo:
                return "Couldn't read that video. Try another screen recording."
            case .noAudioTrack:
                return "That recording has no audio. Make sure music was playing while you recorded."
            case .exportFailed:
                return "Couldn't extract audio from that recording. Try a shorter clip."
            }
        }
    }

    private static let hasImportedKey = "backgroundMusicHasImportedSong"
    private static let directoryName = "background_music"
    private static let fileName = "imported_song.m4a"

    private static var fileManager: FileManager { .default }

    private static var storageDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    static var storageURL: URL {
        storageDirectory.appendingPathComponent(fileName)
    }

    static var hasImportedSong: Bool {
        guard fileManager.fileExists(atPath: storageURL.path) else { return false }
        return UserDefaults.standard.bool(forKey: hasImportedKey)
    }

    static var importedAudioURL: URL? {
        guard hasImportedSong else { return nil }
        return storageURL
    }

    static func importFromVideo(at videoURL: URL) async throws {
        ensureStorageDirectory()

        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw ImportError.noAudioTrack
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ImportError.exportFailed
        }

        if fileManager.fileExists(atPath: storageURL.path) {
            try? fileManager.removeItem(at: storageURL)
        }

        exporter.outputURL = storageURL
        exporter.outputFileType = .m4a

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exporter.status == .completed else {
            try? fileManager.removeItem(at: storageURL)
            throw ImportError.exportFailed
        }

        UserDefaults.standard.set(true, forKey: hasImportedKey)
        UserDefaults.standard.removeObject(forKey: "customBackgroundMusicLink")
        NotificationCenter.default.post(name: .backgroundMusicPreferenceChanged, object: nil)

        cleanupTemporaryFile(at: videoURL)
    }

    static func clearImportedSong() {
        try? fileManager.removeItem(at: storageURL)
        UserDefaults.standard.set(false, forKey: hasImportedKey)
        NotificationCenter.default.post(name: .backgroundMusicPreferenceChanged, object: nil)
    }

    private static func ensureStorageDirectory() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    private static func cleanupTemporaryFile(at url: URL) {
        let tempRoot = fileManager.temporaryDirectory.path
        guard url.path.hasPrefix(tempRoot) else { return }
        try? fileManager.removeItem(at: url)
    }
}

struct PickedBackgroundMusicVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedBackgroundMusicVideo(url: destination)
        }
    }
}
