import Foundation
import AVFoundation
import Combine

@MainActor
final class WatchTogetherViewModel: ObservableObject {
    @Published var isCameraModeEnabled = false
    @Published var showNetworkBlockedToast = false
    @Published var showPermissionDeniedAlert = false
    @Published var partnerLeftMessage: String?

    let networkGate = WatchTogetherNetworkGate()
    let sessionService = WatchTogetherSessionService()

    let videoURLString: String
    let sessionID: UUID?
    let isHost: Bool
    let hostName: String?

    private var wasConnected = false
    private var gateCancellable: AnyCancellable?

    var callController: WatchTogetherCallController { sessionService.callController }

    var isCameraEligible: Bool {
        DataPersistenceManager.shared.loadCoupleProfile().relationshipStage == .officialCouple
    }

    var partnerName: String {
        if let hostName, !isHost { return hostName }
        let dpm = DataPersistenceManager.shared
        if isHost {
            if dpm.isPartnerAccount() {
                return dpm.loadInviterName() ?? "your partner"
            }
            return "your partner"
        }
        return dpm.loadInviterName() ?? dpm.loadUserNickname() ?? "your partner"
    }

    var selfInitial: String {
        let name = DataPersistenceManager.shared.loadUserNickname() ?? "Y"
        return String(name.prefix(1)).uppercased()
    }

    init(videoURLString: String, sessionID: UUID? = nil, isHost: Bool = true, hostName: String? = nil) {
        self.videoURLString = videoURLString
        self.sessionID = sessionID
        self.isHost = isHost
        self.hostName = hostName
    }

    func startNetworkGate() {
        networkGate.start()
        gateCancellable = networkGate.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func enableCamera() async {
        guard !isCameraModeEnabled else { return }
        guard isCameraEligible else { return }
        guard networkGate.isCameraAllowed else {
            showNetworkBlockedToast = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                showNetworkBlockedToast = false
            }
            return
        }

        let cameraGranted = await requestCameraPermission()
        let micGranted = await requestMicrophonePermission()
        guard cameraGranted && micGranted else {
            showPermissionDeniedAlert = true
            return
        }

        do {
            if isHost {
                try await sessionService.startHosting(videoURL: videoURLString)
            } else if let sessionID {
                try await sessionService.join(sessionID: sessionID)
            }
            isCameraModeEnabled = true
            observeConnection()
        } catch {
            print("WatchTogether enableCamera error: \(error.localizedDescription)")
        }
    }

    func disableCamera() async {
        isCameraModeEnabled = false
        await sessionService.end()
        wasConnected = false
    }

    func teardown() async {
        await disableCamera()
        gateCancellable = nil
        networkGate.stop()
    }

    func toggleMic() {
        callController.toggleMic()
    }

    func toggleCamera() {
        callController.toggleCamera()
    }

    private func observeConnection() {
        wasConnected = callController.isConnected
    }

    func handleConnectionChange(isConnected: Bool) {
        if wasConnected && !isConnected {
            partnerLeftMessage = "\(partnerName) left"
            Task {
                try? await Task.sleep(for: .seconds(3))
                partnerLeftMessage = nil
            }
        }
        wasConnected = isConnected
    }

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
