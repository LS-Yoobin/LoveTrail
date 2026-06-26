import SwiftUI

/// Entry point for Watch Together.
/// Drives the 4-state TV graphic, URL input, and the cinematic zoom-to-black
/// transition that hands off to the video player (Sprint 3).
struct WatchTogetherEntryView: View {
    @Environment(\.dismiss) private var dismiss

    var joinSessionID: UUID? = nil
    var joinVideoURL: String? = nil

    // MARK: - State

    @State private var tvState: WatchTogetherTVState = .idle
    @State private var urlText = ""
    @State private var urlError: String? = nil
    @State private var isZooming = false
    @State private var showRotatePrompt = false
    @State private var orientationObserver: NSObjectProtocol?
    @State private var isLandscapeLocked = false
    @State private var showPlayer = false
    @State private var sheetDetent: PresentationDetent = .medium

    // MARK: - Derived

    private var urlIsValid: Bool { WatchTogetherURLValidator.isValid(urlText) }

    private var tvScale: CGFloat {
        let width = min(UIScreen.main.bounds.width - 64, 280)
        return width / WatchTogetherTVView.gardenBaseSide
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                sheetContent
                if isZooming { zoomOverlay }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .onDisappear { tearDownOrientation() }
        .onAppear {
            if let joinVideoURL, !joinVideoURL.isEmpty {
                urlText = joinVideoURL
                tvState = .input
                sheetDetent = .large
            } else {
                advanceFromIdle()
            }
        }
        .fullScreenCover(isPresented: $showPlayer, onDismiss: onPlayerDismissed) {
            if let url = URL(string: urlText) {
                WatchTogetherPlayerView(
                    videoURL: url,
                    sessionID: joinSessionID,
                    isHost: joinSessionID == nil
                )
            }
        }
    }

    // MARK: - Sheet content

    private var sheetContent: some View {
        VStack(spacing: 0) {
            // Fixed top block — TV never moves, even when the keyboard is up
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Watch Together")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(tvState == .idle ? "Watch together, feel closer" : "Add a link to get started")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .animation(.easeInOut(duration: 0.3), value: tvState)
                }

                WatchTogetherTVView(state: tvState, scale: tvScale, onTap: tvTapHandler)
                    .animation(.easeInOut(duration: 0.25), value: tvState)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // Scrollable section — keyboard pushes this up without touching the TV
            ScrollView {
                inputSectionIfNeeded
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - TV tap

    private var tvTapHandler: (() -> Void)? {
        tvState == .idle ? { advanceFromIdle() } : nil
    }

    // MARK: - URL input section

    @ViewBuilder
    private var inputSectionIfNeeded: some View {
        if tvState == .input {
            VStack(spacing: 12) {
                urlField
                errorLabel
                pasteButton
                playButton
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var urlField: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))

            TextField("", text: $urlText, prompt: Text("YouTube link or video URL")
                .foregroundColor(Color(.placeholderText)))
                .foregroundStyle(.primary)
                .font(.system(size: 15))
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: urlText) { _, _ in validateURL() }

            if !urlText.isEmpty {
                Button { urlText = ""; urlError = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    urlError != nil ? Color.red.opacity(0.6) : Color(.separator).opacity(0.6),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private var errorLabel: some View {
        if let error = urlError {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                Text(error)
                    .font(.caption)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var pasteButton: some View {
        Button(action: pasteFromClipboard) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                Text("Paste").fontWeight(.semibold)
            }
            .font(.system(size: 16))
            .foregroundStyle(BabyTownTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(BabyTownTheme.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(BabyTownTheme.accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var playButton: some View {
        Button(action: confirmURL) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Watch Together").fontWeight(.semibold)
            }
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(urlIsValid ? BabyTownTheme.buttonGradient : LinearGradient(
                        colors: [Color.black.opacity(0.75), Color.black.opacity(0.75)],
                        startPoint: .leading, endPoint: .trailing
                    ))
            )
            .opacity(urlIsValid ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!urlIsValid)
        .animation(.easeInOut(duration: 0.2), value: urlIsValid)
    }

    // MARK: - Zoom overlay (stays black — cinematic transition)

    private var zoomOverlay: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .scaleEffect(isZooming ? 1.0 : 0.12)
                .opacity(isZooming ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.65), value: isZooming)

            if showRotatePrompt {
                rotatePrompt.transition(.opacity)
            }
        }
    }

    private var rotatePrompt: some View {
        VStack(spacing: 20) {
            if isLandscapeLocked {
                Text("Loading…")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Image(systemName: "rotate.right")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Rotate your phone")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Watch Together plays in landscape")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - State machine

    private func advanceFromIdle() {
        withAnimation(.easeInOut(duration: 0.25)) {
            tvState = .turningOn
            sheetDetent = .large
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(.easeInOut(duration: 0.3)) { tvState = .input }
        }
    }

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !pasted.isEmpty else { return }
        urlText = pasted
        validateURL()
    }

    private func validateURL() {
        guard !urlText.isEmpty else { urlError = nil; return }
        withAnimation {
            urlError = WatchTogetherURLValidator.classify(urlText) == .unsupported
                ? WatchTogetherURLValidator.unsupportedMessage
                : nil
        }
    }

    private func confirmURL() {
        guard urlIsValid else { return }
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        withAnimation(.easeInOut(duration: 0.2)) { tvState = .black }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            isZooming = true
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation(.easeIn(duration: 0.4)) { showRotatePrompt = true }
            startOrientationMonitor()
        }
    }

    // MARK: - Orientation

    private func startOrientationMonitor() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        OrientationManager.shared.allowLandscape()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let o = UIDevice.current.orientation
            guard o == .landscapeLeft || o == .landscapeRight else { return }
            lockLandscape()
        }
    }

    private func lockLandscape() {
        guard !isLandscapeLocked else { return }
        isLandscapeLocked = true
        OrientationManager.shared.lockLandscape()
        tearDownObserver()
        showPlayer = true
    }

    private func onPlayerDismissed() {
        tearDownObserver()
        OrientationManager.shared.setPortraitMaskOnly()
        dismiss()
    }

    private func tearDownOrientation() {
        tearDownObserver()
        OrientationManager.shared.setPortraitMaskOnly()
    }

    private func tearDownObserver() {
        if let obs = orientationObserver {
            NotificationCenter.default.removeObserver(obs)
            orientationObserver = nil
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}
