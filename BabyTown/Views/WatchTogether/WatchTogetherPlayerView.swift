import SwiftUI
import WebKit

/// Full-screen video player shown after the cinematic zoom transition.
struct WatchTogetherPlayerView: View {
    let videoURL: URL
    var sessionID: UUID? = nil
    var isHost: Bool = true
    var hostName: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var viewModel: WatchTogetherViewModel
    @State private var showConnectionFailedToast = false
    @State private var isYouTubeChromeActive = false
    @State private var youtubeChromeDismissTask: Task<Void, Never>?

    private static let youtubeControlsFadeDelay: Duration = .seconds(2)

    private var isPortraitLayout: Bool { verticalSizeClass == .regular }

    init(
        videoURL: URL,
        sessionID: UUID? = nil,
        isHost: Bool = true,
        hostName: String? = nil
    ) {
        self.videoURL = videoURL
        self.sessionID = sessionID
        self.isHost = isHost
        self.hostName = hostName
        _viewModel = StateObject(
            wrappedValue: WatchTogetherViewModel(
                videoURLString: videoURL.absoluteString,
                sessionID: sessionID,
                isHost: isHost,
                hostName: hostName
            )
        )
    }

    private var embedURL: URL {
        WatchTogetherURLValidator.embedURL(for: videoURL) ?? videoURL
    }

    var body: some View {
        Group {
            if isPortraitLayout {
                portraitLayout
            } else {
                landscapeLayout
            }
        }
        .background {
            Color.black.ignoresSafeArea()
        }
        .onAppear {
            WatchTogetherAudioSession.enterPlayer()
            viewModel.startNetworkGate()
            Task {
                await viewModel.enableCamera()
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                OrientationManager.shared.allowLandscape()
            }
        }
        .onDisappear {
            youtubeChromeDismissTask?.cancel()
            Task {
                await viewModel.teardown()
                WatchTogetherAudioSession.leavePlayer()
            }
        }
        .onChange(of: viewModel.callController.isConnected) { _, isConnected in
            viewModel.handleConnectionChange(isConnected: isConnected)
        }
        .alert(
            "Camera and microphone needed",
            isPresented: $viewModel.showPermissionDeniedAlert
        ) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Covela needs camera and microphone so you two can watch together")
        }
    }

    private var landscapeLayout: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WatchTogetherWebPlayer(url: embedURL, onUserInteraction: noteYouTubeInteraction)
                .ignoresSafeArea()
                .overlay { landscapeChromeOverlay.zIndex(1) }
        }
        .ignoresSafeArea()
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topChromeRow
                .padding(.top, 8)
                .padding(.horizontal, 20)

            if viewModel.isCameraEligible {
                HStack {
                    Spacer(minLength: 0)
                    callOverlay
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.22), value: isYouTubeChromeActive)
            }

            WatchTogetherWebPlayer(url: embedURL, onUserInteraction: noteYouTubeInteraction)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            playerToasts
                .padding(.bottom, 16)
        }
    }

    private var landscapeChromeOverlay: some View {
        VStack(spacing: 0) {
            topChromeRow
                .padding(.top, 20)
                .padding(.horizontal, 20)

            Spacer()
                .allowsHitTesting(false)

            if viewModel.isCameraEligible {
                HStack {
                    callOverlay
                        .padding(.leading, 20)
                        .allowsHitTesting(!isYouTubeChromeActive)
                    Spacer()
                        .allowsHitTesting(false)
                }
                .padding(.bottom, 20)
                .animation(.easeInOut(duration: 0.22), value: isYouTubeChromeActive)
            }

            playerToasts
                .padding(.bottom, 24)
        }
        .allowsHitTesting(true)
    }

    private var topChromeRow: some View {
        HStack {
            Spacer()
                .allowsHitTesting(false)
            closeButton
        }
    }

    private var callOverlay: some View {
        WatchTogetherCallOverlay(
            callController: viewModel.callController,
            partnerName: viewModel.partnerName,
            selfInitial: viewModel.selfInitial,
            isDimmedForVideoControls: isYouTubeChromeActive,
            sizeScale: isPortraitLayout ? 1.2 : 1,
            onToggleMic: { viewModel.toggleMic() },
            onToggleCamera: { viewModel.toggleCamera() }
        )
        .allowsHitTesting(!isYouTubeChromeActive)
    }

    @ViewBuilder
    private var playerToasts: some View {
        if viewModel.showNetworkBlockedToast {
            networkBlockedToast
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        if let partnerLeftMessage = viewModel.partnerLeftMessage {
            partnerLeftToast(partnerLeftMessage)
                .transition(.opacity)
        }

        if showConnectionFailedToast {
            connectionFailedToast
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var closeButton: some View {
        Button {
            Task {
                await viewModel.teardown()
                WatchTogetherAudioSession.leavePlayer()
                OrientationManager.shared.exitToPortrait {
                    dismiss()
                }
            }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(radius: 6)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }

    private var networkBlockedToast: some View {
        Text("Connect to WiFi or mobile data to see each other")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.75), in: Capsule())
            .padding(.horizontal, 24)
    }

    private func partnerLeftToast(_ message: String) -> some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.75), in: Capsule())
    }

    private var connectionFailedToast: some View {
        Text("Couldn't connect. Check your connection and try again.")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.75), in: Capsule())
            .padding(.horizontal, 24)
    }

    private func noteYouTubeInteraction() {
        if !isYouTubeChromeActive {
            withAnimation(.easeInOut(duration: 0.22)) {
                isYouTubeChromeActive = true
            }
        }
        youtubeChromeDismissTask?.cancel()
        youtubeChromeDismissTask = Task { @MainActor in
            try? await Task.sleep(for: Self.youtubeControlsFadeDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                isYouTubeChromeActive = false
            }
        }
    }
}

/// WKWebView wired for inline autoplay — required for YouTube embeds.
private struct WatchTogetherWebPlayer: UIViewRepresentable {
    let url: URL
    var onUserInteraction: () -> Void

    private static let parentBaseURL = URL(string: "\(WatchTogetherURLValidator.embedParentOrigin)/")!
    private static let safariUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    func makeCoordinator() -> Coordinator {
        Coordinator(onUserInteraction: onUserInteraction)
    }

    func makeUIView(context: Context) -> WatchTogetherWebPlayerContainer {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = true
        webView.scrollView.isScrollEnabled = false
        webView.customUserAgent = Self.safariUserAgent
        let html = """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;padding:0;background:#000;overflow:hidden}
        iframe{position:fixed;inset:0;width:100%;height:100%;border:0}</style>
        </head><body>
        <iframe src="\(url.absoluteString)"
          referrerpolicy="strict-origin-when-cross-origin"
          allow="autoplay; encrypted-media; fullscreen; picture-in-picture"
          allowfullscreen></iframe>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: Self.parentBaseURL)

        let container = WatchTogetherWebPlayerContainer(webView: webView)
        container.onUserInteraction = { context.coordinator.notifyInteraction() }
        return container
    }

    func updateUIView(_: WatchTogetherWebPlayerContainer, context: Context) {}

    final class Coordinator {
        private let onUserInteraction: () -> Void

        init(onUserInteraction: @escaping () -> Void) {
            self.onUserInteraction = onUserInteraction
        }

        func notifyInteraction() {
            Task { @MainActor in onUserInteraction() }
        }
    }
}

private final class WatchTogetherWebPlayerContainer: UIView {
    let webView: WKWebView
    var onUserInteraction: (() -> Void)?

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        backgroundColor = .black
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit != nil {
            onUserInteraction?()
        }
        return hit
    }
}
