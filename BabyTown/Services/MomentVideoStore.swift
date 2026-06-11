import Foundation

/// On-disk store for reel videos attached to moments.
final class MomentVideoStore: @unchecked Sendable {

    static let shared = MomentVideoStore()

    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.babytown.momentvideostore", attributes: .concurrent)

    private let polaroidVideosDirectoryName = "polaroid_videos"
    private let momentVideosDirectoryName = "moment_videos"

    private lazy var momentVideosDirectory: URL = {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(momentVideosDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private var polaroidVideosDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(polaroidVideosDirectoryName, isDirectory: true)
    }

    private init() {}

    func fileName(for momentId: UUID) -> String {
        "\(momentId.uuidString).mov"
    }

    func url(for momentId: UUID) -> URL {
        momentVideosDirectory.appendingPathComponent(fileName(for: momentId))
    }

    func hasVideo(for momentId: UUID) -> Bool {
        fileManager.fileExists(atPath: url(for: momentId).path)
            || fileManager.fileExists(atPath: polaroidVideosDirectory.appendingPathComponent(fileName(for: momentId)).path)
    }

    func resolvedURL(for momentId: UUID, fileName storedFileName: String? = nil) -> URL? {
        let momentURL = url(for: momentId)
        if fileManager.fileExists(atPath: momentURL.path) {
            return momentURL
        }

        if let storedFileName {
            let polaroidURL = polaroidVideosDirectory.appendingPathComponent(storedFileName)
            if fileManager.fileExists(atPath: polaroidURL.path) {
                return polaroidURL
            }
        }

        let fallbackPolaroidURL = polaroidVideosDirectory.appendingPathComponent(fileName(for: momentId))
        if fileManager.fileExists(atPath: fallbackPolaroidURL.path) {
            return fallbackPolaroidURL
        }

        return nil
    }

    /// Copies a reel from the polaroid capture directory into long-term moment storage.
    func importFromPolaroid(momentId: UUID, polaroidFileName: String) {
        let source = polaroidVideosDirectory.appendingPathComponent(polaroidFileName)
        guard fileManager.fileExists(atPath: source.path) else { return }

        let destination = url(for: momentId)
        try? fileManager.removeItem(at: destination)
        try? fileManager.copyItem(at: source, to: destination)
    }

    func delete(for momentId: UUID) {
        let momentURL = url(for: momentId)
        ioQueue.async(flags: .barrier) {
            try? FileManager.default.removeItem(at: momentURL)
        }
    }

    func removeAll() {
        ioQueue.async(flags: .barrier) {
            try? FileManager.default.removeItem(at: self.momentVideosDirectory)
            try? FileManager.default.createDirectory(
                at: self.momentVideosDirectory,
                withIntermediateDirectories: true
            )
        }
    }
}
