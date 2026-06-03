import Foundation

enum BackgroundMusicStreamResolver {

    enum ResolverError: LocalizedError {
        case unsupportedLink
        case noPlayableStream
        case networkFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedLink:
                return "This link format isn't supported yet. Try a YouTube, Spotify, Apple Music, or direct audio URL."
            case .noPlayableStream:
                return "Couldn't find playable audio for this link."
            case .networkFailed:
                return "Couldn't reach the music service. Check your connection and try again."
            }
        }
    }

    /// Returns a URL suitable for `AVPlayer`, or nil when embed playback should be used instead.
    static func resolveStreamURL(for link: BackgroundMusicLink) async throws -> URL? {
        switch link.kind {
        case .directAudio:
            return link.originalURL
        case .youtube:
            guard let videoID = link.resourceID, !videoID.isEmpty else {
                throw ResolverError.unsupportedLink
            }
            return try await resolveYouTubeStream(videoID: videoID)
        case .spotify, .appleMusic:
            return nil
        case .unknown:
            throw ResolverError.unsupportedLink
        }
    }

    static func shouldUseEmbedPlayer(for link: BackgroundMusicLink) -> Bool {
        switch link.kind {
        case .spotify, .appleMusic:
            return true
        case .youtube:
            return link.resourceID != nil
        case .directAudio, .unknown:
            return false
        }
    }

    static func embedURL(for link: BackgroundMusicLink) -> URL? {
        switch link.kind {
        case .youtube:
            guard let id = link.resourceID else { return nil }
            var components = URLComponents(string: "https://www.youtube.com/embed/\(id)")
            components?.queryItems = [
                URLQueryItem(name: "autoplay", value: "1"),
                URLQueryItem(name: "loop", value: "1"),
                URLQueryItem(name: "playlist", value: id),
                URLQueryItem(name: "playsinline", value: "1"),
            ]
            return components?.url
        case .spotify:
            guard let path = link.embedPath, !path.isEmpty else { return nil }
            let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
            var components = URLComponents(string: "https://open.spotify.com/embed/\(trimmed)")
            components?.queryItems = [URLQueryItem(name: "utm_source", value: "generator")]
            return components?.url
        case .appleMusic:
            guard let embedPath = link.embedPath, !embedPath.isEmpty else { return link.originalURL }
            if link.originalURL.absoluteString.contains("embed.music.apple.com") {
                return link.originalURL
            }
            return URL(string: "https://embed.music.apple.com\(embedPath)")
        case .directAudio, .unknown:
            return nil
        }
    }

    // MARK: - YouTube (Piped API)

    private struct PipedResponse: Decodable {
        let audioStreams: [PipedStream]?
        let videoStreams: [PipedStream]?
    }

    private struct PipedStream: Decodable {
        let url: String
        let mimeType: String?
        let videoOnly: Bool?
        let format: String?
    }

    private static let pipedInstances = [
        "https://api.piped.private.coffee",
        "https://pipedapi.darkness.services",
        "https://pipedapi.orangenet.cc",
        "https://pipedapi.kavin.rocks",
        "https://api.piped.yt",
    ]

    private static func resolveYouTubeStream(videoID: String) async throws -> URL {
        for base in pipedInstances {
            guard let apiURL = URL(string: "\(base)/streams/\(videoID)") else { continue }
            do {
                var request = URLRequest(url: apiURL)
                request.timeoutInterval = 12
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    continue
                }
                let decoded = try JSONDecoder().decode(PipedResponse.self, from: data)
                if let streamURL = pickPipedPlayableURL(from: decoded) {
                    return streamURL
                }
            } catch {
                continue
            }
        }
        throw ResolverError.noPlayableStream
    }

    private static func pickPipedPlayableURL(from response: PipedResponse) -> URL? {
        let audioCandidates = (response.audioStreams ?? []).map { ($0, prefersVideo: false) }
        let videoCandidates = (response.videoStreams ?? [])
            .filter { $0.videoOnly != true }
            .map { ($0, prefersVideo: true) }

        let ranked = (audioCandidates + videoCandidates).sorted { lhs, rhs in
            streamSortRank(lhs.0, prefersVideo: lhs.prefersVideo) < streamSortRank(rhs.0, prefersVideo: rhs.prefersVideo)
        }

        for (stream, _) in ranked {
            if let url = URL(string: stream.url) {
                return url
            }
        }
        return nil
    }

    private static func streamSortRank(_ stream: PipedStream, prefersVideo: Bool) -> Int {
        let mime = (stream.mimeType ?? "").lowercased()
        let format = (stream.format ?? "").uppercased()
        var rank = prefersVideo ? 10 : 0
        if mime.contains("audio") { rank -= 8 }
        if format == "MPEG_4" || mime.contains("video/mp4") { rank -= 4 }
        if mime.contains("mpegurl") || format == "HLS" { rank += 6 }
        if mime.contains("webm") { rank += 2 }
        return rank
    }
}
