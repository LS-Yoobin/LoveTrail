import AVFoundation
import Combine
import CoreLocation
import SwiftUI
import UIKit

final class BabyTownCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "babytown.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoDevice: AVCaptureDevice?
    private var hasAudioInput = false
    private var hasMovieOutput = false

    private var captureCompletion: ((UIImage?) -> Void)?
    private var momentVideoCompletion: ((URL?) -> Void)?
    private var momentVideoStopWorkItem: DispatchWorkItem?
    private var isManualStopMode = false

    static var momentVideoClipDuration: TimeInterval {
        ReelPreferences.maxDurationSeconds
    }

    @Published var isConfigured = false
    @Published var authorizationDenied = false
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published private(set) var isRecordingMomentVideo = false

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession(position: .back)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.setupSession(position: .back)
                } else {
                    DispatchQueue.main.async { self.authorizationDenied = true }
                }
            }
        default:
            DispatchQueue.main.async { self.authorizationDenied = true }
        }
    }

    private func setupSession(position: AVCaptureDevice.Position) {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            self.hasAudioInput = false

            do {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                    DispatchQueue.main.async { self.authorizationDenied = true }
                    self.session.commitConfiguration()
                    return
                }
                self.videoDevice = device
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                if !self.session.outputs.contains(self.photoOutput), self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }
                self.ensureMovieOutputConfiguredLocked()
                DispatchQueue.main.async { self.position = position }
            } catch {
                DispatchQueue.main.async { self.authorizationDenied = true }
                self.session.commitConfiguration()
                return
            }

            self.session.commitConfiguration()
            DispatchQueue.main.async { self.isConfigured = true }
        }
    }

    func flipCamera() {
        let nextPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        sessionQueue.async {
            self.session.beginConfiguration()
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            self.hasAudioInput = false
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: nextPosition) else {
                self.session.commitConfiguration()
                return
            }
            self.videoDevice = device
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            } catch {
                self.session.commitConfiguration()
                return
            }
            self.ensureMovieOutputConfiguredLocked()
            self.session.commitConfiguration()
            DispatchQueue.main.async { self.position = nextPosition }
        }
    }

    func cycleFlashMode() {
        guard position == .back else { return }
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async {
            guard self.isConfigured else { return }
            let settings = AVCapturePhotoSettings()
            if self.videoDevice?.hasFlash == true {
                settings.flashMode = self.flashMode
            }
            self.captureCompletion = completion
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startRunning() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopRunning() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func recordMomentVideo(completion: @escaping (URL?) -> Void) {
        AVAudioApplication.requestRecordPermission { _ in
            self.recordMomentVideoAfterMicPermission(completion: completion)
        }
    }

    private func recordMomentVideoAfterMicPermission(completion: @escaping (URL?) -> Void) {
        sessionQueue.async {
            guard self.isConfigured, !self.movieOutput.isRecording, self.session.isRunning else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.ensureMovieOutputConfiguredLocked()
            guard self.hasMovieOutput else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("reel_\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: url)

            self.momentVideoCompletion = completion
            self.momentVideoStopWorkItem?.cancel()
            let clipDuration = Self.momentVideoClipDuration
            let stopMode = ReelStopMode.current
            self.isManualStopMode = (stopMode == .manual)

            if stopMode == .auto {
                let stopWork = DispatchWorkItem { [weak self] in
                    self?.stopMomentVideoRecordingLocked()
                }
                self.momentVideoStopWorkItem = stopWork
                self.movieOutput.maxRecordedDuration = CMTime(seconds: clipDuration, preferredTimescale: 600)
                self.sessionQueue.asyncAfter(deadline: .now() + clipDuration, execute: stopWork)
            } else {
                self.movieOutput.maxRecordedDuration = CMTime(seconds: 120, preferredTimescale: 600)
            }

            if let connection = self.movieOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if let audioConnection = self.movieOutput.connection(with: .audio) {
                audioConnection.isEnabled = true
            }

            DispatchQueue.main.async {
                self.activateAudioSessionForVideoRecording()
                self.isRecordingMomentVideo = true
            }
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopMomentVideoRecording() {
        sessionQueue.async { self.stopMomentVideoRecordingLocked() }
    }

    func cancelMomentVideoRecording() {
        sessionQueue.async { self.cancelMomentVideoRecordingLocked() }
    }

    private func ensureMovieOutputConfiguredLocked() {
        let audioAlreadyInSession = session.inputs.contains { input in
            guard let deviceInput = input as? AVCaptureDeviceInput else { return false }
            return deviceInput.device.hasMediaType(.audio)
        }

        session.beginConfiguration()
        if !audioAlreadyInSession,
           let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            hasAudioInput = true
        } else if audioAlreadyInSession {
            hasAudioInput = true
        }
        if !hasMovieOutput, !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            hasMovieOutput = true
        }
        if hasMovieOutput, session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        session.commitConfiguration()
    }

    private func activateAudioSessionForVideoRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .videoRecording,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try? session.setActive(true)
    }

    private func stopMomentVideoRecordingLocked() {
        momentVideoStopWorkItem?.cancel()
        momentVideoStopWorkItem = nil
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    private func cancelMomentVideoRecordingLocked() {
        momentVideoStopWorkItem?.cancel()
        momentVideoStopWorkItem = nil
        if movieOutput.isRecording {
            momentVideoCompletion = nil
            movieOutput.stopRecording()
        }
        DispatchQueue.main.async { self.isRecordingMomentVideo = false }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let completion = captureCompletion
        captureCompletion = nil

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { completion?(nil) }
            return
        }

        DispatchQueue.main.async { completion?(image) }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        momentVideoStopWorkItem?.cancel()
        momentVideoStopWorkItem = nil
        let completion = momentVideoCompletion
        momentVideoCompletion = nil
        let wasManual = isManualStopMode
        let clipDuration = Self.momentVideoClipDuration

        DispatchQueue.main.async { self.isRecordingMomentVideo = false }

        if let error = error as NSError? {
            let finishedOK = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
            if !finishedOK {
                try? FileManager.default.removeItem(at: outputFileURL)
                DispatchQueue.main.async { completion?(nil) }
                return
            }
        }

        let recorded = (try? outputFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard recorded >= 1024 else {
            try? FileManager.default.removeItem(at: outputFileURL)
            DispatchQueue.main.async { completion?(nil) }
            return
        }

        if wasManual {
            Task {
                let finalURL = await Self.trimToLastSeconds(clipDuration, from: outputFileURL)
                DispatchQueue.main.async { completion?(finalURL) }
            }
        } else {
            DispatchQueue.main.async { completion?(outputFileURL) }
        }
    }

    private static func trimToLastSeconds(_ seconds: TimeInterval, from url: URL) async -> URL {
        let asset = AVAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return url }
        let durationSecs = duration.seconds
        guard durationSecs > seconds else { return url }

        let start = CMTime(seconds: durationSecs - seconds, preferredTimescale: 600)
        let range = CMTimeRange(start: start, duration: CMTime(seconds: seconds, preferredTimescale: 600))
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reel_trimmed_\(UUID().uuidString).mov")

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            return url
        }
        export.outputURL = outURL
        export.outputFileType = .mov
        export.timeRange = range
        await export.export()

        if export.status == .completed {
            try? FileManager.default.removeItem(at: url)
            return outURL
        }
        return url
    }

    static func thumbnailImage(from videoURL: URL) async -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewContainer {
        CameraPreviewContainer(session: session)
    }

    func updateUIView(_ uiView: CameraPreviewContainer, context: Context) {
        uiView.updateSession(session)
    }
}

final class CameraPreviewContainer: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    func updateSession(_ session: AVCaptureSession) {
        previewLayer.session = session
    }
}
