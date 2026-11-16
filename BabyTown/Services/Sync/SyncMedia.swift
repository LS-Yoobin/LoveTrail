import Foundation
import CryptoKit

/// Remembers, per account, which local media has been uploaded (and under which
/// covela-fs key) and which remote media has been downloaded, so sync never uploads
/// or downloads the same bytes twice.
///
/// Keys are stable strings chosen by each resource, e.g. `"avatar.me"`,
/// `"special-date.<objectId>"`, `"moment.<objectId>"`.
@MainActor
final class SyncMediaRegistry {
    static let shared = SyncMediaRegistry()

    struct Entry: Codable, Equatable {
        /// Permanent covela-fs key (never a signed URL).
        var remotePath: String
        /// SHA-256 prefix of the local bytes this path holds.
        var fingerprint: String?
        /// Size + modification date of the local file when it was fingerprinted, so an
        /// unchanged file is recognised with a `stat` instead of re-reading and hashing.
        var fileStamp: String?
    }

    private var entries: [String: Entry] = [:]
    private var loadedScopeId: String?
    private static let fileName = "couple_sync_media.json"

    private init() {}

    private var fileURL: URL {
        DataPersistenceManager.shared.currentScopeDirectory.appendingPathComponent(Self.fileName)
    }

    private func loadIfNeeded() {
        let scope = DataPersistenceManager.shared.activeScopeId
        guard loadedScopeId != scope else { return }
        loadedScopeId = scope
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        } else {
            entries = [:]
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func entry(for key: String) -> Entry? {
        loadIfNeeded()
        return entries[key]
    }

    /// The uploaded path for these exact bytes, or `nil` if they still need uploading.
    func remotePath(for key: String, fingerprint: String) -> String? {
        guard let entry = entry(for: key), entry.fingerprint == fingerprint else { return nil }
        return entry.remotePath
    }

    func record(key: String, remotePath: String, fingerprint: String?, fileStamp: String? = nil) {
        loadIfNeeded()
        entries[key] = Entry(remotePath: remotePath, fingerprint: fingerprint, fileStamp: fileStamp)
        save()
    }

    /// File-based variant of `remotePath(for:fingerprint:)` for large media sets
    /// (moments): trusts the stored fingerprint while the file's size and modification
    /// date are unchanged, and only re-hashes when they differ.
    func remotePath(for key: String, fileAt url: URL) -> String? {
        guard let entry = entry(for: key), let stamp = Self.fileStamp(at: url) else { return nil }
        if entry.fileStamp == stamp { return entry.remotePath }
        guard let data = try? Data(contentsOf: url),
              Self.fingerprint(of: data) == entry.fingerprint else { return nil }
        entries[key]?.fileStamp = stamp
        save()
        return entry.remotePath
    }

    nonisolated static func fileStamp(at url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return "\(size.int64Value)-\(Int64(modified.timeIntervalSince1970 * 1000))"
    }

    func remove(key: String) {
        loadIfNeeded()
        guard entries.removeValue(forKey: key) != nil else { return }
        save()
    }

    func reset() {
        entries = [:]
        loadedScopeId = DataPersistenceManager.shared.activeScopeId
        try? FileManager.default.removeItem(at: fileURL)
    }

    nonisolated static func fingerprint(of data: Data) -> String {
        SHA256.hash(data: data).prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}

/// Network side of media sync.
enum SyncMediaTransfer {
    enum TransferError: Error {
        case offline
        case rejected
    }

    /// Uploads JPEG bytes and returns the permanent covela-fs key.
    static func uploadJPEG(_ data: Data, filename: String) async throws -> String {
        try await run { try await CovelaMediaUploadClient.shared.uploadJPEGData(data, filename: filename) }
    }

    /// Uploads a transparent PNG cutout (kept PNG by the file server) and returns the key.
    static func uploadPNG(_ data: Data, filename: String) async throws -> String {
        try await run { try await CovelaMediaUploadClient.shared.uploadSticker(data, filename: filename) }
    }

    /// Uploads audio bytes (m4a) and returns the key.
    static func uploadAudio(_ data: Data, filename: String) async throws -> String {
        try await run { try await CovelaMediaUploadClient.shared.uploadVoiceMemo(data, filename: filename) }
    }

    /// Uploads a video (`.mov` / `.mp4`, max 100 MB) and returns the key.
    static func uploadVideo(_ data: Data, filename: String) async throws -> String {
        try await run { try await CovelaMediaUploadClient.shared.uploadVideo(data, filename: filename) }
    }

    /// Only "couldn't reach the server" stops a sync run (`offline`). Anything the
    /// server refused is `rejected`, so the resource skips that file and moves on.
    private static func run(_ upload: () async throws -> String) async throws -> String {
        do {
            return try await upload()
        } catch CovelaMediaUploadError.network, CovelaMediaUploadError.notSignedIn {
            throw TransferError.offline
        } catch let CovelaMediaUploadError.httpError(status, _) where status >= 500 {
            throw TransferError.offline
        } catch {
            throw TransferError.rejected
        }
    }

    /// Downloads media, preferring the signed URL the DTO already carries and falling
    /// back to asking the API to sign the permanent path.
    static func download(signedURL: String?, path: String?) async -> Data? {
        if let signedURL, let url = URL(string: signedURL),
           let data = try? await fetch(url) {
            return data
        }
        guard let path,
              let url = try? await CovelaAPIClient.shared.signedMediaURL(forPath: path) else {
            return nil
        }
        return try? await fetch(url)
    }

    private static func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
            throw TransferError.rejected
        }
        return data
    }
}
