import Foundation

/// Normalizes covela-fs media paths and detects presigned S3 URLs.
enum CovelaMediaPath {
    private static let bucketName = "covela-fs"

    /// Strips a full S3 URL down to the permanent object key, or returns the key unchanged.
    static func normalizePermanentPath(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("file://") else { return nil }

        if !trimmed.hasPrefix("http://"), !trimmed.hasPrefix("https://") {
            return trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        }

        guard let url = URL(string: trimmed) else { return nil }
        let pathPrefix = "/\(bucketName)/"
        if url.path.hasPrefix(pathPrefix) {
            return String(url.path.dropFirst(pathPrefix.count))
        }
        if url.host?.hasPrefix("\(bucketName).") == true {
            return url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        }
        return nil
    }

    /// True only for a permanent server key in the form the API stores (e.g.
    /// `public/...`): no scheme (`file://`, `https://`), no leading `/`, no query, no
    /// `..`, no whitespace. Anything else is a local path or a URL and must never be
    /// written to a record such as `avatar_path` (BAB-147: the backend accepts them).
    static func isValidRemoteMediaPath(_ value: String?) -> Bool {
        guard let value, !value.isEmpty,
              !value.contains("://"), !value.lowercased().hasPrefix("file:"),
              !value.hasPrefix("/"), !value.hasPrefix("~"),
              !value.contains("?"), !value.contains("#"),
              value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !value.split(separator: "/").contains("..") else { return false }
        // A device path that lost its leading "/" during normalization.
        guard !localRoots.contains(where: { value.hasPrefix($0) }) else { return false }
        return normalizePermanentPath(value) == value
    }

    private static let localRoots = ["private/", "var/", "Users/", "Library/", "System/", "tmp/", "Applications/", "Volumes/"]

    /// True for a value that points at this device's file system rather than the
    /// file server: `file:` URLs and absolute paths under the app container, home or
    /// temporary directory or the usual system roots. Checked before
    /// `normalizePermanentPath`, which strips the leading "/" the file server uses.
    static func looksLikeLocalFilePath(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("file:") || trimmed.hasPrefix("~") { return true }
        guard trimmed.hasPrefix("/") else { return false }
        let deviceDirectories = [NSHomeDirectory(), NSTemporaryDirectory()]
            .filter { !$0.isEmpty && $0 != "/" }
        if deviceDirectories.contains(where: { trimmed.hasPrefix($0) }) { return true }
        return localRoots.contains { trimmed.dropFirst().hasPrefix($0) }
    }

    /// True when the URL includes AWS SigV4 query params from `getSignedUrl`.
    static func isSignedS3URL(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString) else { return false }
        return components.queryItems?.contains(where: { item in
            item.name.hasPrefix("X-Amz-") || item.name == "Signature"
        }) == true
    }
}
