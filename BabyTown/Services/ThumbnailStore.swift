import UIKit
import ImageIO

/// On-disk store for moment / prompt-photo thumbnails, fronted by an in-memory `NSCache`.
///
/// Keeps photo bytes out of `moments.json` / `prompt_memories.json` so that:
/// - launch no longer decodes every photo into RAM, and
/// - memory stays bounded (the cache evicts under pressure and off-screen).
///
/// Thread-safe: `NSCache` is thread-safe, disk writes are serialized on a private queue,
/// so the synchronous `image(for:)` accessor can be called from any context (it backs
/// `Moment.thumbnail` / `PromptPhoto.thumbnail`).
final class ThumbnailStore: @unchecked Sendable {

    static let shared = ThumbnailStore()

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.babytown.thumbnailstore", attributes: .concurrent)

    private lazy var directory: URL = {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("thumbnails", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024 // ~64 MB of decoded thumbnails
    }

    // MARK: - Paths

    func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).jpg")
    }

    func hasFile(for id: UUID) -> Bool {
        fileManager.fileExists(atPath: url(for: id).path)
    }

    private func cost(of image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
    }

    // MARK: - Writing

    /// Keep an image in memory without touching disk. Called when a `Moment` is constructed,
    /// so its thumbnail is available immediately (the next save persists it to disk).
    func cache(_ image: UIImage, for id: UUID) {
        cache.setObject(image, forKey: id.uuidString as NSString, cost: cost(of: image))
    }

    /// Cache + write to disk immediately.
    func store(_ image: UIImage, for id: UUID) {
        cache(image, for: id)
        writeToDisk(image, for: id)
    }

    /// One-time migration of a legacy inline thumbnail. Caches the decoded image for display
    /// AND writes the original JPEG bytes straight to disk (no re-encode), immediately, so the
    /// photo survives even if the in-memory cache evicts it before the next save. Idempotent.
    func importLegacyData(_ data: Data, for id: UUID) {
        if let image = UIImage(data: data) {
            cache(image, for: id)
        }
        guard !hasFile(for: id) else { return }
        let fileURL = url(for: id)
        ioQueue.async(flags: .barrier) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Write the cached image to disk if there's no file yet. Idempotent and cheap once
    /// the file exists — covers brand-new moments whose bytes only exist in memory.
    func persistIfNeeded(for id: UUID) {
        guard !hasFile(for: id) else { return }
        guard let image = cache.object(forKey: id.uuidString as NSString) else { return }
        writeToDisk(image, for: id)
    }

    private func writeToDisk(_ image: UIImage, for id: UUID) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileURL = url(for: id)
        ioQueue.async(flags: .barrier) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func remove(for id: UUID) {
        cache.removeObject(forKey: id.uuidString as NSString)
        let fileURL = url(for: id)
        ioQueue.async(flags: .barrier) {
            try? self.fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Reading

    /// Full (as-stored) image: memory cache → disk → nil. Backs the synchronous
    /// `thumbnail` accessors used by non-feed call sites (viewer, share, map).
    func image(for id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: url(for: id)), let image = UIImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: key, cost: cost(of: image))
        return image
    }

    /// Downsampled decode for grids/cards, intended to be called off the main thread.
    /// Cached per size bucket so repeat appearances are instant. Falls back to the cached
    /// full image when there's no file yet (e.g. a brand-new, not-yet-persisted moment).
    func downsampledImage(for id: UUID, maxPixel: CGFloat) -> UIImage? {
        let key = "\(id.uuidString)#\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let source = CGImageSourceCreateWithURL(url(for: id) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return image(for: id)
        }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key, cost: cost(of: image))
        return image
    }
}
