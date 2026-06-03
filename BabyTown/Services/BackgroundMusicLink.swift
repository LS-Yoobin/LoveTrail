import Foundation

enum BackgroundMusicLinkKind: String, CaseIterable {
    case youtube
    case spotify
    case appleMusic
    case directAudio
    case unknown

    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        case .directAudio: return "Audio link"
        case .unknown: return "Link"
        }
    }
}

struct BackgroundMusicLink: Equatable {
    let kind: BackgroundMusicLinkKind
    let originalURL: URL
    /// Platform id (YouTube video id, Spotify track id, etc.) when available.
    let resourceID: String?
    /// Path/query preserved for Apple Music embed conversion.
    let embedPath: String?
}

enum BackgroundMusicLinkParser {

    static func parse(_ url: URL) -> BackgroundMusicLink {
        if url.scheme?.lowercased() == "spotify" {
            let host = (url.host ?? "").lowercased()
            let id = url.path.split(separator: "/").first.map(String.init) ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let types = ["track", "album", "playlist", "episode"]
            if types.contains(host), !id.isEmpty {
                return BackgroundMusicLink(
                    kind: .spotify,
                    originalURL: url,
                    resourceID: id,
                    embedPath: "/\(host)/\(id)"
                )
            }
        }

        let host = (url.host ?? "").lowercased()
        let path = url.path

        if host.contains("youtu.be") {
            let id = String(path.dropFirst()).split(separator: "?").first.map(String.init)
            return BackgroundMusicLink(kind: .youtube, originalURL: url, resourceID: id, embedPath: nil)
        }

        if host.contains("youtube.com") || host.contains("youtube-nocookie.com") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let id = components.queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
                return BackgroundMusicLink(kind: .youtube, originalURL: url, resourceID: id, embedPath: nil)
            }
            if path.hasPrefix("/shorts/") {
                let id = path.replacingOccurrences(of: "/shorts/", with: "").split(separator: "/").first.map(String.init)
                return BackgroundMusicLink(kind: .youtube, originalURL: url, resourceID: id, embedPath: nil)
            }
        }

        if host.contains("spotify.com") {
            let id = spotifyResourceID(from: path)
            return BackgroundMusicLink(kind: .spotify, originalURL: url, resourceID: id, embedPath: path)
        }

        if host.contains("music.apple.com") {
            return BackgroundMusicLink(
                kind: .appleMusic,
                originalURL: url,
                resourceID: nil,
                embedPath: path + (url.query.map { "?\($0)" } ?? "")
            )
        }

        if isLikelyDirectAudio(url) {
            return BackgroundMusicLink(kind: .directAudio, originalURL: url, resourceID: nil, embedPath: nil)
        }

        return BackgroundMusicLink(kind: .unknown, originalURL: url, resourceID: nil, embedPath: nil)
    }

    static func isValidMusicURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return false
        }
        guard scheme == "http" || scheme == "https" || scheme == "spotify" else { return false }
        let link = parse(url)
        return link.kind != .unknown
    }

    private static func spotifyResourceID(from path: String) -> String? {
        let prefixes = ["/track/", "/episode/", "/album/", "/playlist/"]
        for prefix in prefixes where path.contains(prefix) {
            let segment = path.components(separatedBy: prefix).dropFirst().first ?? ""
            return segment.split(separator: "/").first.map(String.init)
        }
        return nil
    }

    /// `spotify:track:…` URI for the Embed iFrame API (not the open.spotify.com page URL).
    static func spotifyURI(for link: BackgroundMusicLink) -> String? {
        guard link.kind == .spotify else { return nil }

        let path = link.embedPath ?? link.originalURL.path
        let segments = path.split(separator: "/").map(String.init)
        let types = ["track", "album", "playlist", "episode"]

        for index in segments.indices where index + 1 < segments.count {
            let type = segments[index]
            guard types.contains(type) else { continue }
            let id = segments[index + 1].split(separator: "?").first.map(String.init) ?? segments[index + 1]
            guard !id.isEmpty else { continue }
            return "spotify:\(type):\(id)"
        }

        if let id = link.resourceID {
            return "spotify:track:\(id)"
        }
        return nil
    }

    private static func isLikelyDirectAudio(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ["mp3", "m4a", "aac", "wav", "mp4", "caf"].contains(ext) { return true }
        let host = (url.host ?? "").lowercased()
        return host.contains("soundcloud.com") || host.contains("audio")
    }
}
