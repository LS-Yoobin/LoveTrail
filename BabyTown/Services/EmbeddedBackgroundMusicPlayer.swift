import WebKit

/// Plays Spotify / Apple Music / YouTube embeds when a direct stream URL isn't available.
@MainActor
final class EmbeddedBackgroundMusicPlayer: NSObject {

    static let shared = EmbeddedBackgroundMusicPlayer()

    private var webView: WKWebView?
    private weak var hostView: UIView?

    private override init() {
        super.init()
    }

    func play(link: BackgroundMusicLink, in host: UIView?) {
        stop()
        guard let host else { return }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        if #available(iOS 17.0, *) {
            config.allowsAirPlayForMediaPlayback = true
        }

        // Spotify's embed needs a real layout size; a 1×1 view often never starts playback.
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 280, height: 160), configuration: config)
        webView.isHidden = true
        webView.isUserInteractionEnabled = false
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.alpha = 0.01
        host.addSubview(webView)
        self.webView = webView
        hostView = host

        let (html, baseURL) = htmlPage(for: link)
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func stop() {
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
        hostView = nil
    }

    private func htmlPage(for link: BackgroundMusicLink) -> (html: String, baseURL: URL?) {
        if link.kind == .spotify, let uri = BackgroundMusicLinkParser.spotifyURI(for: link) {
            return (spotifyIframeAPIPage(uri: uri), URL(string: "https://open.spotify.com"))
        }

        guard let embedURL = BackgroundMusicStreamResolver.embedURL(for: link) else {
            return ("<!DOCTYPE html><html><body></body></html>", nil)
        }

        let base = embedURL
        let html = """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;overflow:hidden}
        iframe{position:fixed;inset:0;width:100%;height:100%;border:0}</style>
        </head><body>
        <iframe src="\(embedURL.absoluteString)"
          allow="autoplay; encrypted-media; fullscreen"
          allowfullscreen></iframe>
        </body></html>
        """
        return (html, base)
    }

    /// Spotify autoplay requires the official iFrame API + `controller.play()`, not a static embed URL.
    private func spotifyIframeAPIPage(uri: String) -> String {
        let escapedURI = uri
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;overflow:hidden}</style>
        <script>
        window.onSpotifyIframeApiReady = function(IFrameAPI) {
          var element = document.getElementById('embed-iframe');
          var options = { uri: '\(escapedURI)', width: '100%', height: '80' };
          var callback = function(controller) {
            controller.addListener('ready', function() { controller.play(); });
            controller.play();
          };
          IFrameAPI.createController(element, options, callback);
        };
        </script>
        <script src="https://open.spotify.com/embed/iframe-api/v1"></script>
        </head>
        <body><div id="embed-iframe"></div></body>
        </html>
        """
    }
}

extension EmbeddedBackgroundMusicPlayer: WKNavigationDelegate {}
