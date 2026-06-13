import SwiftUI
import WebKit

/// Full-screen video player shown after the cinematic zoom transition.
struct WatchTogetherPlayerView: View {
    let videoURL: URL
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    private var embedURL: URL {
        WatchTogetherURLValidator.embedURL(for: videoURL) ?? videoURL
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            WatchTogetherWebPlayer(url: embedURL)
                .ignoresSafeArea()

            Button {
                onDismiss?()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 6)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .ignoresSafeArea()
    }
}

/// WKWebView wired for inline autoplay — required for YouTube embeds.
private struct WatchTogetherWebPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = true
        webView.scrollView.isScrollEnabled = false
        // YouTube's player requires an iframe context. Loading the embed URL
        // directly via URLRequest causes error 153 (video player configuration
        // error) because the player detects it isn't running inside an iframe
        // on a host page. Wrapping in HTML with loadHTMLString+baseURL provides
        // the expected Referer/origin context, matching EmbeddedBackgroundMusicPlayer.
        let html = """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;overflow:hidden}
        iframe{position:fixed;inset:0;width:100%;height:100%;border:0}</style>
        </head><body>
        <iframe src="\(url.absoluteString)"
          allow="autoplay; encrypted-media; fullscreen; picture-in-picture"
          allowfullscreen></iframe>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: url)
        return webView
    }

    func updateUIView(_: WKWebView, context: Context) {}
}
