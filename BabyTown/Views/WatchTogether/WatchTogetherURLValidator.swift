import Foundation

enum WatchTogetherURLKind {
    case youtube
    case directVideo
    case unsupported
}

enum WatchTogetherURLValidator {
    /// Distinct parent origin for the WKWebView HTML wrapper. Must NOT be youtube.com
    /// (same-origin parent causes YouTube error 152-4).
    static let embedParentOrigin = "https://covela.app"

    static func classify(_ raw: String) -> WatchTogetherURLKind {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let host = url.host?.lowercased() else { return .unsupported }

        // YouTube
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return .youtube
        }

        // Direct video by extension
        let path = url.path.lowercased()
        if path.hasSuffix(".mp4") || path.hasSuffix(".mov") || path.hasSuffix(".webm") {
            return .directVideo
        }

        // Cloudflare Stream or self-hosted with video query param
        if host.contains("cloudflarestream.com") { return .directVideo }

        return .unsupported
    }

    static func isValid(_ raw: String) -> Bool {
        classify(raw) != .unsupported
    }

    /// Human-readable inline error shown on the TV screen for bad URLs.
    static let unsupportedMessage = "This link isn't supported. Try a YouTube or direct video link."

    /// Converts a validated YouTube URL to its embed form for WKWebView playback.
    /// Returns the original URL unchanged for direct video links.
    static func embedURL(for url: URL) -> URL? {
        guard classify(url.absoluteString) == .youtube else { return url }
        let host = url.host?.lowercased() ?? ""
        var videoID: String?

        if host.contains("youtu.be") {
            videoID = url.pathComponents.dropFirst().first
        } else if host.contains("youtube.com") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let v = components?.queryItems?.first(where: { $0.name == "v" })?.value {
                videoID = v
            } else if let idx = url.pathComponents.firstIndex(of: "shorts"),
                      idx + 1 < url.pathComponents.count {
                videoID = url.pathComponents[idx + 1]
            } else if url.pathComponents.contains("embed") {
                return youTubeEmbedURL(videoID: extractYouTubeVideoID(from: url))
            }
        }

        guard let id = videoID else { return url }
        return youTubeEmbedURL(videoID: id)
    }

    private static func extractYouTubeVideoID(from url: URL) -> String? {
        let pathID = url.pathComponents.last
        if let pathID, !pathID.isEmpty, pathID != "embed" { return pathID }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "v" })?.value
    }

    private static func youTubeEmbedURL(videoID: String?) -> URL? {
        guard let videoID, !videoID.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.youtube.com/embed/\(videoID)")
        components?.queryItems = [
            URLQueryItem(name: "autoplay", value: "1"),
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "origin", value: embedParentOrigin),
        ]
        return components?.url
    }
}
