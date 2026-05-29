import SwiftUI
import WebKit

/// Minimal in-app web view. Loads `url` once and reloads only when `url` changes.
struct EmbeddedWebView: UIViewRepresentable {
    let url: URL

    final class Coordinator {
        var lastRequestedURL: URL?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastRequestedURL != url else { return }
        context.coordinator.lastRequestedURL = url
        webView.load(URLRequest(url: url))
    }
}
