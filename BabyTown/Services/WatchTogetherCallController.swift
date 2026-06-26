import Foundation
import WebRTC
import AVFoundation
import Combine

@MainActor
final class WatchTogetherCallController: NSObject, ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isMicMuted = false
    @Published private(set) var isCameraOff = false
    @Published private(set) var localVideoTrack: RTCVideoTrack?
    @Published private(set) var remoteVideoTrack: RTCVideoTrack?
    /// Bumped when the local camera restarts so SwiftUI rebuilds RTC renderers.
    @Published private(set) var videoRendererNonce = 0

    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory()
    }()

    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var isHost = false

    private let stunServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
    ]

    func configure(isHost: Bool) {
        self.isHost = isHost
        tearDownPeerConnection()
        let config = RTCConfiguration()
        config.iceServers = stunServers
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        peerConnection = Self.factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )
        addLocalTracks()
    }

    private func addLocalTracks() {
        guard let pc = peerConnection else { return }
        let audioSource = Self.factory.audioSource(
            with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        )
        localAudioTrack = Self.factory.audioTrack(with: audioSource, trackId: "audio0")
        if let audio = localAudioTrack { pc.add(audio, streamIds: ["stream0"]) }

        let videoSource = Self.factory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        localVideoTrack = Self.factory.videoTrack(with: videoSource, trackId: "video0")
        if let video = localVideoTrack { pc.add(video, streamIds: ["stream0"]) }
        startFrontCamera()
    }

    private func startFrontCamera() {
        guard let capturer = videoCapturer else { return }
        let devices = RTCCameraVideoCapturer.captureDevices()
        guard let front = devices.first(where: { $0.position == .front }) ?? devices.first else { return }
        let formats = RTCCameraVideoCapturer.supportedFormats(for: front)
        let target = formats.first {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <= 640
        } ?? formats.first
        guard let format = target else { return }
        capturer.stopCapture()
        capturer.startCapture(with: front, format: format, fps: 24)
    }

    func createOffer() async throws -> WatchTogetherSignalMessage {
        guard let pc = peerConnection else { throw CallError.notConfigured }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
            optionalConstraints: nil
        )
        let sdp = try await pc.offer(for: constraints)
        try await pc.setLocalDescription(sdp)
        return WatchTogetherSignalMessage(type: .offer, fromUserID: currentUserID(), payload: sdp.sdp)
    }

    func handleRemoteSignal(_ message: WatchTogetherSignalMessage) async throws {
        guard let pc = peerConnection else { throw CallError.notConfigured }
        switch message.type {
        case .offer:
            let desc = RTCSessionDescription(type: .offer, sdp: message.payload)
            try await pc.setRemoteDescription(desc)
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
                optionalConstraints: nil
            )
            let answer = try await pc.answer(for: constraints)
            try await pc.setLocalDescription(answer)
            NotificationCenter.default.post(
                name: .watchTogetherLocalAnswerReady,
                object: WatchTogetherSignalMessage(
                    type: .answer,
                    fromUserID: currentUserID(),
                    payload: answer.sdp
                )
            )
        case .answer:
            let desc = RTCSessionDescription(type: .answer, sdp: message.payload)
            try await pc.setRemoteDescription(desc)
        case .iceCandidate:
            let candidate = try JSONDecoder().decode(
                IceCandidatePayload.self,
                from: Data(message.payload.utf8)
            )
            let ice = RTCIceCandidate(
                sdp: candidate.sdp,
                sdpMLineIndex: candidate.sdpMLineIndex,
                sdpMid: candidate.sdpMid
            )
            try await pc.add(ice)
        }
    }

    func toggleMic() {
        isMicMuted.toggle()
        localAudioTrack?.isEnabled = !isMicMuted
    }

    func toggleCamera() {
        isCameraOff.toggle()
        localVideoTrack?.isEnabled = !isCameraOff
        if isCameraOff {
            videoCapturer?.stopCapture()
        } else {
            startFrontCamera()
        }
    }

    /// Restarts the front camera capture when the session is active but preview is blank.
    func ensureCameraCaptureActive() {
        guard !isCameraOff else { return }
        startFrontCamera()
        videoRendererNonce += 1
    }

    func endCall() {
        videoCapturer?.stopCapture()
        tearDownPeerConnection()
        isConnected = false
        isMicMuted = false
        isCameraOff = false
        videoRendererNonce = 0
    }

    private func tearDownPeerConnection() {
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
        localVideoTrack = nil
        remoteVideoTrack = nil
        videoCapturer = nil
    }

    private func currentUserID() -> String {
        DataPersistenceManager.shared.loadUserNickname() ?? "local-user"
    }

    enum CallError: Error { case notConfigured }
}

extension WatchTogetherCallController: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Task { @MainActor in
            remoteVideoTrack = stream.videoTracks.first
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    nonisolated func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didAdd rtpReceiver: RTCRtpReceiver,
        streams: [RTCMediaStream]
    ) {
        guard let track = rtpReceiver.track as? RTCVideoTrack else { return }
        Task { @MainActor in
            remoteVideoTrack = track
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor in
            isConnected = newState == .connected || newState == .completed
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        guard let data = try? JSONEncoder().encode(
            IceCandidatePayload(
                sdp: candidate.sdp,
                sdpMLineIndex: candidate.sdpMLineIndex,
                sdpMid: candidate.sdpMid
            )
        ), let json = String(data: data, encoding: .utf8) else { return }
        let message = WatchTogetherSignalMessage(type: .iceCandidate, fromUserID: "", payload: json)
        NotificationCenter.default.post(name: .watchTogetherLocalIceCandidate, object: message)
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
}

extension Notification.Name {
    static let watchTogetherLocalAnswerReady = Notification.Name("watchTogetherLocalAnswerReady")
    static let watchTogetherLocalIceCandidate = Notification.Name("watchTogetherLocalIceCandidate")
    static let watchTogetherInviteReceived = Notification.Name("watchTogetherInviteReceived")
}

private struct IceCandidatePayload: Codable {
    let sdp: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
}

private extension RTCPeerConnection {
    func offer(for constraints: RTCMediaConstraints) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            offer(for: constraints) { sdp, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let sdp {
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: WatchTogetherCallController.CallError.notConfigured)
                }
            }
        }
    }

    func answer(for constraints: RTCMediaConstraints) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            answer(for: constraints) { sdp, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let sdp {
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: WatchTogetherCallController.CallError.notConfigured)
                }
            }
        }
    }

    func setLocalDescription(_ sdp: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setLocalDescription(sdp) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func setRemoteDescription(_ sdp: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setRemoteDescription(sdp) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func add(_ candidate: RTCIceCandidate) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(candidate) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
