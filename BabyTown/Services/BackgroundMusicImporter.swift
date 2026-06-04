import AVFoundation
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum BackgroundMusicImporter {

    enum ImportError: LocalizedError {
        case unreadableVideo
        case noAudioTrack
        case exportFailed
        case playlistFull

        var errorDescription: String? {
            switch self {
            case .unreadableVideo:
                return "Couldn't read that video. Try another screen recording."
            case .noAudioTrack:
                return "That recording has no audio. Make sure music was playing while you recorded."
            case .exportFailed:
                return "Couldn't extract audio from that recording. Try a shorter clip."
            case .playlistFull:
                return CouplePlaylistStore.PlaylistError.playlistFull.errorDescription
            }
        }
    }

    private static let directoryName = "background_music"
    private static var fileManager: FileManager { .default }

    private static var tempExportDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    static var hasImportedSong: Bool {
        CouplePlaylistStore.hasImportedSong
    }

    static var importedAudioURL: URL? {
        CouplePlaylistStore.importedAudioURL
    }

    /// Extracts audio from a screen recording and appends it to the couple playlist.
    @discardableResult
    static func importFromVideo(at videoURL: URL) async throws -> CouplePlaylistTrack {
        guard CouplePlaylistStore.canAddTrack else {
            throw ImportError.playlistFull
        }

        ensureTempDirectory()
        let tempURL = tempExportDirectory.appendingPathComponent("import_temp_\(UUID().uuidString).m4a")

        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw ImportError.noAudioTrack
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ImportError.exportFailed
        }

        if fileManager.fileExists(atPath: tempURL.path) {
            try? fileManager.removeItem(at: tempURL)
        }

        exporter.outputURL = tempURL
        exporter.outputFileType = .m4a

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exporter.status == .completed else {
            try? fileManager.removeItem(at: tempURL)
            throw ImportError.exportFailed
        }

        defer {
            try? fileManager.removeItem(at: tempURL)
            cleanupTemporaryFile(at: videoURL)
        }

        do {
            let track = try CouplePlaylistStore.addTrack(fromExportedAudioAt: tempURL)
            UserDefaults.standard.removeObject(forKey: "customBackgroundMusicLink")
            return track
        } catch CouplePlaylistStore.PlaylistError.playlistFull {
            throw ImportError.playlistFull
        }
    }

    static func clearImportedSong() {
        CouplePlaylistStore.clearAll()
    }

    private static func ensureTempDirectory() {
        if !fileManager.fileExists(atPath: tempExportDirectory.path) {
            try? fileManager.createDirectory(at: tempExportDirectory, withIntermediateDirectories: true)
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
