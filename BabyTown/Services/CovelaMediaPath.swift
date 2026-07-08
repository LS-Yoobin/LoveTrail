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

    /// True when the URL includes AWS SigV4 query params from `getSignedUrl`.
    static func isSignedS3URL(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString) else { return false }
        return components.queryItems?.contains(where: { item in
            item.name.hasPrefix("X-Amz-") || item.name == "Signature"
        }) == true
    }
}
