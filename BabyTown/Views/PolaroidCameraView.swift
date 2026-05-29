import SwiftUI
import Photos

private enum InAppCameraChromeLayout {
    static let horizontalInset: CGFloat = 16
    static let topInsetBelowSafeArea: CGFloat = 8
}

struct PolaroidCameraView: View {

    @ObservedObject var polaroidStore: LocalPolaroidStore
    @Environment(\.dismiss) private var dismiss
    var onPhotosReleased: ([PolaroidEntry]) -> Void

    @StateObject private var cameraController = BabyTownCameraController()
    @StateObject private var locationManager = CameraLocationManager()
    @StateObject private var vibeRecorder = VibeRecorder()

    @State private var showNotification = false
    @State private var notificationMessage = ""
    @State private var showLogModal = false
    @State private var flashOpacity: Double = 0
    @State private var vibePulse = false
    @State private var lastCaptureWasVibe = false
    @State private var momentVideoSecondsRemaining = 0
    @State private var momentVideoSecondsElapsed = 0
    @State private var momentVideoTimer: Timer?

    @AppStorage("babytown.camera.captureMode") private var captureModeRaw = CameraCaptureMode.photo.rawValue
    @AppStorage(ReelPreferences.userDefaultsKey) private var reelMaxDurationSeconds: Double = ReelPreferences.defaultDurationSeconds
    @AppStorage(ReelStopMode.userDefaultsKey) private var reelStopModeRaw = ReelStopMode.auto.rawValue
    @AppStorage("babytown.camera.saveToPhotosEnabled") private var saveToPhotosEnabled = false

    private var captureMode: CameraCaptureMode {
        CameraCaptureMode(rawValue: captureModeRaw) ?? .photo
    }

    private var reelStopMode: ReelStopMode {
        ReelStopMode(rawValue: reelStopModeRaw) ?? .auto
    }

    private var isVibeCaptureEnabled: Bool { captureMode == .vibe }
    private var isReelCaptureMode: Bool { captureMode == .reel }

    private var todaysCount: Int {
        polaroidStore.todaysCaptureCount()
    }

    private var todaysUnreleased: [PolaroidEntry] {
        polaroidStore.todaysUnreleasedEntries()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraController.authorizationDenied {
                cameraDeniedView
            } else if cameraController.isConfigured {
                CameraPreviewView(session: cameraController.session)
                    .ignoresSafeArea()
            } else {
                ProgressView("Preparing camera…")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            cameraOverlays

            Rectangle()
                .fill(Color.white)
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            shutterBar
                .padding(.vertical, 8)
        }
        .onChange(of: cameraController.isConfigured) { _, configured in
            if configured { cameraController.startRunning() }
        }
        .onAppear {
            InAppCameraAudioSession.activateForCamera()
            cameraController.startRunning()
            if isVibeCaptureEnabled { vibeRecorder.start() }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                vibePulse = true
            }
            locationManager.requestPermissionAndStart()
        }
        .onDisappear {
            momentVideoTimer?.invalidate()
            cameraController.cancelMomentVideoRecording()
            vibeRecorder.cancelAndDelete()
            cameraController.stopRunning()
            InAppCameraAudioSession.deactivateAfterCamera()
            locationManager.stop()
        }
        .onChange(of: cameraController.isRecordingMomentVideo) { _, isRecording in
            if isRecording {
                if reelStopMode == .manual {
                    beginMomentVideoElapsedTimer()
                } else {
                    beginMomentVideoCountdown()
                }
            } else {
                momentVideoSecondsRemaining = 0
                momentVideoSecondsElapsed = 0
                momentVideoTimer?.invalidate()
            }
        }
        .sheet(isPresented: $showLogModal) {
            CameraLogView(entries: todaysUnreleased)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Overlays

    private var cameraOverlays: some View {
        ZStack {
            if isReelCaptureMode && !cameraController.isRecordingMomentVideo {
                VStack {
                    reelStopModePicker
                    Spacer()
                }
                .padding(.top, InAppCameraChromeLayout.topInsetBelowSafeArea)
                .frame(maxWidth: .infinity)
            }

            if isVibeCaptureEnabled {
                VStack {
                    vibePill
                    Spacer()
                }
                .padding(.top, InAppCameraChromeLayout.topInsetBelowSafeArea)
            }

            HStack(alignment: .top, spacing: 12) {
                backButton
                Spacer(minLength: 0)
                topRightControls
            }
            .padding(.horizontal, InAppCameraChromeLayout.horizontalInset)
            .padding(.top, InAppCameraChromeLayout.topInsetBelowSafeArea)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if showNotification {
                VStack {
                    Spacer()
                    notificationBanner
                        .padding(.bottom, 180)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var backButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text("Back")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10)
        }
    }

    private var topRightControls: some View {
        VStack(spacing: 16) {
            circleControlButton(systemName: "camera.rotate") {
                cameraController.flipCamera()
            }
            .accessibilityLabel("Flip camera")

            circleControlButton(systemName: flashIconName) {
                cameraController.cycleFlashMode()
            }
            .disabled(cameraController.position == .front)
            .accessibilityLabel(flashAccessibilityLabel)

            circleControlButton(
                systemName: "arrow.down.to.line.compact",
                isActive: saveToPhotosEnabled
            ) {
                toggleSaveToPhotos()
            }
            .accessibilityLabel(saveToPhotosEnabled ? "Save to Photos on" : "Save to Photos off")

            if isReelCaptureMode {
                reelMaxDurationButton
            }
        }
    }

    private func circleControlButton(
        systemName: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .background(isActive ? Color(red: 0.95, green: 0.26, blue: 0.35).opacity(0.22) : Color.clear)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        isActive ? Color(red: 0.95, green: 0.26, blue: 0.35).opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
                )
        }
    }

    private var vibePill: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(vibePulse ? 0 : 0.45))
                    .frame(width: 9, height: 9)
                    .scaleEffect(vibePulse ? 1.5 : 1.0)
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 6, height: 6)
            }
            Text("Capturing Vibe")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .background(Color.cyan.opacity(0.22))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Shutter bar

    private var shutterBar: some View {
        VStack(spacing: 0) {
            if cameraController.isRecordingMomentVideo {
                reelRecordingIndicator
                    .padding(.bottom, 12)
            }

            if cameraController.position == .back {
                zoomControl
                    .padding(.bottom, 12)
            }

            ZStack {
                Group {
                    if isReelCaptureMode {
                        reelShutterControl
                    } else {
                        photoShutterButton
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        showLogModal = true
                    } label: {
                        todaysCaptureButton
                    }
                    .disabled(cameraController.isRecordingMomentVideo)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            captureModePicker
        }
        .padding(.horizontal, 24)
    }

    private var zoomControl: some View {
        HStack(spacing: 20) {
            ForEach(CameraZoomPreset.allCases, id: \.self) { preset in
                let isSelected = abs(cameraController.displayZoomFactor - preset.displayFactor) < 0.01
                let isAvailable = cameraController.availableZoomPresets.contains(preset.displayFactor)

                Button {
                    cameraController.setDisplayZoom(preset.displayFactor)
                } label: {
                    Text(preset.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .yellow : .white)
                        .frame(width: 36, height: 36)
                        .background {
                            if isSelected {
                                Circle()
                                    .fill(Color.white.opacity(0.22))
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable || cameraController.isRecordingMomentVideo)
                .opacity(isAvailable ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .disabled(cameraController.isRecordingMomentVideo)
        .opacity(cameraController.isRecordingMomentVideo ? 0.5 : 1)
    }

    private var photoShutterButton: some View {
        Button {
            performPhotoCapture()
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 74, height: 74)

                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 80, height: 80)

                if let catImage = UIImage(named: "First Page Cat") {
                    Image(uiImage: catImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .disabled(cameraController.isRecordingMomentVideo)
        .accessibilityLabel(isVibeCaptureEnabled ? "Take photo with vibe" : "Take photo")
    }

    private var reelShutterControl: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 4)
                .frame(width: 74, height: 74)

            if cameraController.isRecordingMomentVideo {
                Circle()
                    .trim(from: 0, to: momentVideoClipProgress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(-90))
            }

            RoundedRectangle(
                cornerRadius: cameraController.isRecordingMomentVideo ? 7 : 29,
                style: .continuous
            )
            .fill(Color.red)
            .frame(
                width: cameraController.isRecordingMomentVideo ? 28 : 58,
                height: cameraController.isRecordingMomentVideo ? 28 : 58
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: cameraController.isRecordingMomentVideo)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if cameraController.isRecordingMomentVideo {
                cameraController.stopMomentVideoRecording()
            } else {
                startReelRecording()
            }
        }
        .accessibilityLabel(cameraController.isRecordingMomentVideo ? "Stop recording" : "Record reel")
    }

    private var todaysCaptureButton: some View {
        let previewSize: CGFloat = 56
        let latestImage = todaysUnreleased.last.flatMap { polaroidStore.loadImage(for: $0) }

        return ZStack {
            if let image = latestImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: previewSize, height: previewSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                lastCaptureWasVibe
                                    ? LinearGradient(colors: [.cyan, .green], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                                lineWidth: 2.5
                            )
                    )
            } else {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: previewSize, height: previewSize)
            }

            if todaysCount > 0 {
                Text("\(todaysCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.95, green: 0.26, blue: 0.35))
                    .clipShape(Capsule())
                    .shadow(color: latestImage != nil ? .black.opacity(0.35) : .clear, radius: 2, y: 1)
            }
        }
        .frame(width: previewSize, height: previewSize)
    }

    private var captureModePicker: some View {
        HStack(spacing: 0) {
            ForEach(CameraCaptureMode.allCases) { mode in
                Button {
                    setCaptureMode(mode)
                } label: {
                    Text(mode.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(captureMode == mode ? .white : .white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if captureMode == mode {
                                Capsule()
                                    .fill(Color.white.opacity(0.22))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .disabled(cameraController.isRecordingMomentVideo)
    }

    private var reelStopModePicker: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach([ReelStopMode.auto, ReelStopMode.manual], id: \.self) { mode in
                    let selected = reelStopMode == mode
                    Button {
                        reelStopModeRaw = mode.rawValue
                    } label: {
                        Text(mode.shortLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selected ? .white : .white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background {
                                if selected {
                                    Capsule().fill(Color.white.opacity(0.22))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .frame(width: 168)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Text(reelStopMode == .manual
                ? "Records until you stop · last \(ReelPreferences.label(for: reelMaxDurationSeconds)) saved"
                : "Auto-stops after \(ReelPreferences.label(for: reelMaxDurationSeconds))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
    }

    private var reelMaxDurationButton: some View {
        Menu {
            ForEach(ReelPreferences.choices, id: \.self) { seconds in
                Button {
                    reelMaxDurationSeconds = seconds
                } label: {
                    if seconds == reelMaxDurationSeconds {
                        Label(ReelPreferences.label(for: seconds), systemImage: "checkmark")
                    } else {
                        Text(ReelPreferences.label(for: seconds))
                    }
                }
            }
        } label: {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .disabled(cameraController.isRecordingMomentVideo)
    }

    private var reelRecordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
            Text(reelRecordingElapsedLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var notificationBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                Text(notificationMessage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Take another photo if you'd like")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private var cameraDeniedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.7))
            Text("Camera access is required")
                .font(.headline)
                .foregroundStyle(.white)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Capture logic

    private func setCaptureMode(_ mode: CameraCaptureMode) {
        guard mode != captureMode else { return }
        if mode != .reel {
            cameraController.cancelMomentVideoRecording()
        }
        if mode == .vibe {
            vibeRecorder.start()
        } else {
            vibeRecorder.cancelAndDelete()
        }
        captureModeRaw = mode.rawValue
    }

    private func performPhotoCapture() {
        guard !cameraController.isRecordingMomentVideo else { return }
        triggerFlashEffect()

        let capturedVibeEnabled = isVibeCaptureEnabled
        let vibeTask: Task<URL?, Never> = capturedVibeEnabled
            ? Task { await vibeRecorder.stopAndTrimLast10Seconds() }
            : Task { nil }

        cameraController.capturePhoto { image in
            Task { @MainActor in
                guard let image else { return }
                let vibeURL = await vibeTask.value
                if capturedVibeEnabled { vibeRecorder.start() }
                lastCaptureWasVibe = capturedVibeEnabled && vibeURL != nil
                await handleCapturedPhoto(image, vibeURL: vibeURL)
                if saveToPhotosEnabled {
                    saveImageToPhotosLibrary(image)
                }
            }
        }
    }

    private func startReelRecording() {
        cameraController.recordMomentVideo { videoURL in
            Task { @MainActor in
                guard let videoURL else { return }
                let thumbnail = await BabyTownCameraController.thumbnailImage(from: videoURL)
                let image = thumbnail ?? UIImage()
                lastCaptureWasVibe = false
                await handleCapturedPhoto(image, videoSourceURL: videoURL)
                if saveToPhotosEnabled, let thumbnail {
                    saveImageToPhotosLibrary(thumbnail)
                }
            }
        }
    }

    private func handleCapturedPhoto(
        _ image: UIImage,
        vibeURL: URL? = nil,
        videoSourceURL: URL? = nil
    ) async {
        var placeName: String?
        let location = locationManager.currentLocation
        if let location {
            placeName = await SmartPlaceResolver.shared.resolvePlaceName(for: location)
        }

        guard polaroidStore.savePhoto(
            image,
            placeName: placeName,
            location: location,
            vibeSourceURL: vibeURL,
            videoSourceURL: videoSourceURL
        ) != nil else { return }

        notificationMessage = "This photo will be available later"

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showNotification = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation {
                showNotification = false
            }
        }
    }

    private func triggerFlashEffect() {
        flashOpacity = 1
        withAnimation(.easeOut(duration: 0.2)) {
            flashOpacity = 0
        }
    }

    private func toggleSaveToPhotos() {
        if saveToPhotosEnabled {
            saveToPhotosEnabled = false
            return
        }
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            await MainActor.run {
                saveToPhotosEnabled = status == .authorized || status == .limited
            }
        }
    }

    private func saveImageToPhotosLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    // MARK: - Reel timing

    private var momentVideoClipProgress: CGFloat {
        let duration = reelMaxDurationSeconds
        guard duration > 0 else { return 0 }
        if reelStopMode == .manual {
            let elapsed = Double(momentVideoSecondsElapsed)
            return CGFloat(min(1, elapsed / duration))
        }
        let remaining = Double(momentVideoSecondsRemaining)
        return CGFloat(min(1, max(0, (duration - remaining) / duration)))
    }

    private var reelRecordingElapsedLabel: String {
        if reelStopMode == .manual {
            return String(format: "%d:%02d", momentVideoSecondsElapsed / 60, momentVideoSecondsElapsed % 60)
        }
        return "\(momentVideoSecondsRemaining)s"
    }

    private func beginMomentVideoCountdown() {
        momentVideoTimer?.invalidate()
        momentVideoSecondsRemaining = Int(reelMaxDurationSeconds)
        momentVideoTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if momentVideoSecondsRemaining > 0 {
                momentVideoSecondsRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func beginMomentVideoElapsedTimer() {
        momentVideoTimer?.invalidate()
        momentVideoSecondsElapsed = 0
        momentVideoTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            momentVideoSecondsElapsed += 1
        }
    }

    // MARK: - Flash helpers

    private var flashIconName: String {
        switch cameraController.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        @unknown default: return "bolt.slash"
        }
    }

    private var flashAccessibilityLabel: String {
        switch cameraController.flashMode {
        case .off: return "Flash off"
        case .on: return "Flash on"
        case .auto: return "Flash auto"
        @unknown default: return "Flash"
        }
    }
}
