# Watch Together Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a free P2P 1:1 camera overlay to Watch Together so couples can see each other (bottom-right PiP) while watching YouTube, with mic/camera toggles and push/in-app invite join flow.

**Architecture:** `WatchTogetherCallController` owns WebRTC peer connection and local/remote tracks. `WatchTogetherSessionService` creates/joins sessions via `WatchTogetherAPIClientProtocol` (stub until backend ships) and exchanges SDP/ICE over `WatchTogetherSignalingClientProtocol`. `WatchTogetherCallOverlay` renders PiP feeds over the existing `WatchTogetherWebPlayer`. Partner invites route through `NotificationManager` (local stub now, APNs later).

**Tech Stack:** SwiftUI, WebKit (existing YouTube embed), WebRTC (`stasel/WebRTC` SPM), Network framework (`NWPathMonitor`), UserNotifications, MongoDB + WebSocket backend (stubbed on iOS until SUB-4)

**Spec:** `docs/superpowers/specs/2026-06-25-watch-together-camera-design.md`

## Global Constraints

- No ` - ` (space dash space) in any user-facing string, label, placeholder, or button copy
- All colors use `BabyTownTheme.*` tokens; no hardcoded hex or RGB values
- Both Pink and Blue themes must render correctly in all views
- Phase gate: Together only (`CoupleProfile.relationshipStage == .officialCouple`)
- YouTube playback stays local per device in v1; no playback sync
- P2P WebRTC only; no paid RTC vendor; STUN only (`stun:stun.l.google.com:19302`); no TURN in v1
- Camera overlay requires WiFi or cellular (`WatchTogetherNetworkGate`)
- Copy phase: Together (see spec copy table)

---

## File Map

**New files:**

| Path | Responsibility |
|---|---|
| `BabyTown/Models/WatchTogetherSession.swift` | Session + signaling message Codable types |
| `BabyTown/Services/WatchTogetherNetworkGate.swift` | `NWPathMonitor` wrapper |
| `BabyTown/Services/WatchTogetherAPIClient.swift` | Protocol + stub REST client |
| `BabyTown/Services/WatchTogetherSignalingClient.swift` | Protocol + stub WebSocket client |
| `BabyTown/Services/WatchTogetherSessionService.swift` | Orchestrates create/join/end + signaling |
| `BabyTown/Services/WatchTogetherCallController.swift` | WebRTC peer connection, tracks, mute/camera |
| `BabyTown/Components/RTCVideoView.swift` | `RTCVideoRenderer` UIViewRepresentable |
| `BabyTown/Views/WatchTogether/WatchTogetherCallOverlay.swift` | Bottom-right PiP + control bar |
| `BabyTown/Views/WatchTogether/WatchTogetherInviteBanner.swift` | In-app join banner |
| `BabyTown/ViewModels/WatchTogetherViewModel.swift` | Player + call state for `WatchTogetherPlayerView` |

**Modified files:**

| Path | Change |
|---|---|
| `BabyTown/Views/WatchTogether/WatchTogetherPlayerView.swift` | Add See each other toggle, overlay, view model |
| `BabyTown/Views/WatchTogether/WatchTogetherEntryView.swift` | Pass `sessionID` when joining from invite |
| `BabyTown/Services/NotificationManager.swift` | Add `watchTogetherInvite` partner event |
| `BabyTown/AppDelegate.swift` | Route watch-together notification tap |
| `BabyTown/Views/CoupleProfile/CoupleProfileView.swift` | Present player from deep link |
| `BabyTown.xcodeproj/project.pbxproj` | WebRTC SPM + new file refs |
| `BabyTown.xcodeproj/project.pbxproj` (build settings) | Update camera/mic Info.plist strings |

---

## Jira Structure (Backend — parallel track)

| Ticket | Title | Gates |
|---|---|---|
| SUB-1 | `watch_together_sessions` collection + TTL index | Unblocked |
| SUB-2 | REST endpoints (create/join/end/active) | Requires SUB-1 |
| SUB-3 | WebSocket signaling relay | Requires SUB-2 |
| SUB-4 | APNs push on session create | Requires SUB-2 |

iOS Tasks 1–12 ship with stubs. Replace stubs when SUB-2–SUB-4 land.

---

## Task 1: Session Models

**Files:**
- Create: `BabyTown/Models/WatchTogetherSession.swift`

**Interfaces:**
- Produces: `WatchTogetherSession`, `WatchTogetherSessionStatus`, `WatchTogetherSignalMessage` — used by Tasks 5–7

- [ ] **Step 1: Create `BabyTown/Models/WatchTogetherSession.swift`**

```swift
import Foundation

enum WatchTogetherSessionStatus: String, Codable {
    case waiting
    case active
    case ended
}

struct WatchTogetherSession: Identifiable, Codable, Equatable {
    let id: UUID
    let coupleID: String
    let hostUserID: String
    let videoURL: String
    var status: WatchTogetherSessionStatus
    let createdAt: Date
    let expiresAt: Date
}

enum WatchTogetherSignalType: String, Codable {
    case offer
    case answer
    case iceCandidate
}

struct WatchTogetherSignalMessage: Codable, Equatable {
    let type: WatchTogetherSignalType
    let fromUserID: String
    let payload: String
}
```

- [ ] **Step 2: Build** — ⌘B in Xcode. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/WatchTogetherSession.swift
git commit -m "feat: add WatchTogether session and signaling models"
```

---

## Task 2: Network Gate

**Files:**
- Create: `BabyTown/Services/WatchTogetherNetworkGate.swift`

**Interfaces:**
- Produces: `WatchTogetherNetworkGate` with `var isCameraAllowed: Bool { get }` and `func start()` / `func stop()`

- [ ] **Step 1: Create `BabyTown/Services/WatchTogetherNetworkGate.swift`**

```swift
import Foundation
import Network
import Combine

@MainActor
final class WatchTogetherNetworkGate: ObservableObject {
    @Published private(set) var isCameraAllowed = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "covela.watchtogether.network")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let allowed = path.status == .satisfied
                && (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.cellular))
            Task { @MainActor in self?.isCameraAllowed = allowed }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
        isCameraAllowed = false
    }
}
```

- [ ] **Step 2: Build** — ⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Services/WatchTogetherNetworkGate.swift
git commit -m "feat: add WatchTogether network gate for camera eligibility"
```

---

## Task 3: WebRTC Dependency + RTCVideoView

**Files:**
- Modify: `BabyTown.xcodeproj/project.pbxproj` (add SPM package)
- Create: `BabyTown/Components/RTCVideoView.swift`

**Interfaces:**
- Produces: `RTCVideoView` SwiftUI wrapper accepting `RTCVideoTrack?`

- [ ] **Step 1: Add WebRTC SPM package in Xcode**

File → Add Package Dependencies → URL: `https://github.com/stasel/WebRTC.git` → Up to Next Major from `124.0.0` → Add to BabyTown target.

- [ ] **Step 2: Create `BabyTown/Components/RTCVideoView.swift`**

```swift
import SwiftUI
import WebRTC

struct RTCVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        view.delegate = context.coordinator
        attach(track, to: view)
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        attach(track, to: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func attach(_ track: RTCVideoTrack?, to view: RTCMTLVideoView) {
        if let renderer = view as? RTCVideoRenderer {
            track?.add(renderer)
        }
    }

    final class Coordinator: NSObject, RTCVideoViewDelegate {
        func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {}
    }
}
```

- [ ] **Step 3: Build** — ⌘B. Expected: Build Succeeded (WebRTC links).

- [ ] **Step 4: Commit**

```bash
git add BabyTown.xcodeproj/project.pbxproj BabyTown/Components/RTCVideoView.swift
git commit -m "feat: add WebRTC dependency and RTCVideoView wrapper"
```

---

## Task 4: WatchTogetherCallController

**Files:**
- Create: `BabyTown/Services/WatchTogetherCallController.swift`

**Interfaces:**
- Consumes: `WatchTogetherSignalMessage` from Task 1
- Produces:
  - `@MainActor final class WatchTogetherCallController: ObservableObject`
  - `@Published var isConnected: Bool`
  - `@Published var isMicMuted: Bool`
  - `@Published var isCameraOff: Bool`
  - `var localVideoTrack: RTCVideoTrack?`
  - `var remoteVideoTrack: RTCVideoTrack?`
  - `func configure(isHost: Bool)`
  - `func createOffer() async throws -> WatchTogetherSignalMessage`
  - `func handleRemoteSignal(_ message: WatchTogetherSignalMessage) async throws`
  - `func toggleMic()`
  - `func toggleCamera()`
  - `func endCall()`

- [ ] **Step 1: Create `BabyTown/Services/WatchTogetherCallController.swift`**

```swift
import Foundation
import WebRTC
import AVFoundation
import Combine

@MainActor
final class WatchTogetherCallController: NSObject, ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isMicMuted = false
    @Published private(set) var isCameraOff = false

    private(set) var localVideoTrack: RTCVideoTrack?
    private(set) var remoteVideoTrack: RTCVideoTrack?

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
        let audioSource = Self.factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
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
        let target = formats.first { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <= 640 } ?? formats.first
        guard let format = target else { return }
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
                object: WatchTogetherSignalMessage(type: .answer, fromUserID: currentUserID(), payload: answer.sdp)
            )
        case .answer:
            let desc = RTCSessionDescription(type: .answer, sdp: message.payload)
            try await pc.setRemoteDescription(desc)
        case .iceCandidate:
            let candidate = try JSONDecoder().decode(IceCandidatePayload.self, from: Data(message.payload.utf8))
            let ice = RTCIceCandidate(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid)
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

    func endCall() {
        videoCapturer?.stopCapture()
        tearDownPeerConnection()
        isConnected = false
        isMicMuted = false
        isCameraOff = false
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

    private struct IceCandidatePayload: Codable {
        let sdp: String
        let sdpMLineIndex: Int32
        let sdpMid: String?
    }
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
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor in
            isConnected = newState == .connected || newState == .completed
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        guard let data = try? JSONEncoder().encode(
            IceCandidatePayload(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid)
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
}
```

- [ ] **Step 2: Build** — ⌘B. Fix any `async` SDP bridging with `withCheckedThrowingContinuation` if compiler requires it.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Services/WatchTogetherCallController.swift
git commit -m "feat: add WatchTogether WebRTC call controller"
```

---

## Task 5: API + Signaling Clients (Stub)

**Files:**
- Create: `BabyTown/Services/WatchTogetherAPIClient.swift`
- Create: `BabyTown/Services/WatchTogetherSignalingClient.swift`

**Interfaces:**
- Produces:
  - `WatchTogetherAPIClientProtocol` with `createSession(videoURL:)`, `joinSession(id:)`, `endSession(id:)`, `activeSession()`
  - `WatchTogetherSignalingClientProtocol` with `connect(sessionID:)`, `send(_:)`, `onMessage: ((WatchTogetherSignalMessage) -> Void)?`, `disconnect()`

- [ ] **Step 1: Create `BabyTown/Services/WatchTogetherAPIClient.swift`**

```swift
import Foundation

protocol WatchTogetherAPIClientProtocol {
    func createSession(videoURL: String) async throws -> WatchTogetherSession
    func joinSession(id: UUID) async throws -> WatchTogetherSession
    func endSession(id: UUID) async throws
    func activeSession() async throws -> WatchTogetherSession?
}

final class StubWatchTogetherAPIClient: WatchTogetherAPIClientProtocol {
    static let shared = StubWatchTogetherAPIClient()
    private var sessions: [UUID: WatchTogetherSession] = [:]
    private init() {}

    func createSession(videoURL: String) async throws -> WatchTogetherSession {
        let profile = DataPersistenceManager.shared.loadCoupleProfile()
        let session = WatchTogetherSession(
            id: UUID(),
            coupleID: profile.coupleId ?? "local-couple",
            hostUserID: DataPersistenceManager.shared.loadUserNickname() ?? "host",
            videoURL: videoURL,
            status: .waiting,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(4 * 60 * 60)
        )
        sessions[session.id] = session
        return session
    }

    func joinSession(id: UUID) async throws -> WatchTogetherSession {
        guard var session = sessions[id] else { throw URLError(.fileDoesNotExist) }
        session.status = .active
        sessions[id] = session
        return session
    }

    func endSession(id: UUID) async throws {
        sessions.removeValue(forKey: id)
    }

    func activeSession() async throws -> WatchTogetherSession? {
        sessions.values.first { $0.status != .ended && $0.expiresAt > Date() }
    }
}
```

- [ ] **Step 2: Create `BabyTown/Services/WatchTogetherSignalingClient.swift`**

Stub uses `NotificationCenter` so two simulators on the same Mac can be tested manually via Settings debug action until SUB-3 ships. Real client uses `URLSessionWebSocketTask`.

```swift
import Foundation

protocol WatchTogetherSignalingClientProtocol: AnyObject {
    var onMessage: ((WatchTogetherSignalMessage) -> Void)? { get set }
    func connect(sessionID: UUID) async throws
    func send(_ message: WatchTogetherSignalMessage) async throws
    func disconnect()
}

/// Dev stub: forwards signals via NotificationCenter. Replace with WebSocket when SUB-3 lands.
final class StubWatchTogetherSignalingClient: WatchTogetherSignalingClientProtocol {
    var onMessage: ((WatchTogetherSignalMessage) -> Void)?
    private var sessionID: UUID?
    private var observer: NSObjectProtocol?

    func connect(sessionID: UUID) async throws {
        self.sessionID = sessionID
        observer = NotificationCenter.default.addObserver(
            forName: .watchTogetherSignalReceived,
            object: sessionID,
            queue: .main
        ) { [weak self] note in
            guard let message = note.userInfo?["message"] as? WatchTogetherSignalMessage else { return }
            self?.onMessage?(message)
        }
    }

    func send(_ message: WatchTogetherSignalMessage) async throws {
        guard let sessionID else { return }
        NotificationCenter.default.post(
            name: .watchTogetherSignalReceived,
            object: sessionID,
            userInfo: ["message": message]
        )
    }

    func disconnect() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        sessionID = nil
    }
}

extension Notification.Name {
    static let watchTogetherSignalReceived = Notification.Name("watchTogetherSignalReceived")
}
```

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Services/WatchTogetherAPIClient.swift BabyTown/Services/WatchTogetherSignalingClient.swift
git commit -m "feat: add stub WatchTogether API and signaling clients"
```

---

## Task 6: WatchTogetherSessionService

**Files:**
- Create: `BabyTown/Services/WatchTogetherSessionService.swift`

**Interfaces:**
- Consumes: API client (Task 5), signaling client (Task 5), `WatchTogetherCallController` (Task 4)
- Produces: `@MainActor final class WatchTogetherSessionService` with `startHosting(videoURL:)`, `join(sessionID:)`, `end()`, `callController: WatchTogetherCallController`

- [ ] **Step 1: Create `BabyTown/Services/WatchTogetherSessionService.swift`**

Orchestration logic:
1. `startHosting` → `api.createSession` → `signaling.connect` → `callController.configure(isHost: true)` → `createOffer` → `signaling.send(offer)` → fire partner invite via `NotificationManager`
2. `join` → `api.joinSession` → `signaling.connect` → `callController.configure(isHost: false)`
3. Wire `signaling.onMessage` → `callController.handleRemoteSignal`
4. Wire `watchTogetherLocalAnswerReady` / ICE notifications → `signaling.send`
5. `end` → `callController.endCall` → `signaling.disconnect` → `api.endSession`

- [ ] **Step 2: Build** — ⌘B.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Services/WatchTogetherSessionService.swift
git commit -m "feat: add WatchTogether session orchestration service"
```

---

## Task 7: Call Overlay UI

**Files:**
- Create: `BabyTown/Views/WatchTogether/WatchTogetherCallOverlay.swift`

**Interfaces:**
- Consumes: `WatchTogetherCallController` published state, partner display name `String`
- Produces: `WatchTogetherCallOverlay` view

- [ ] **Step 1: Create overlay with spec layout**

```swift
import SwiftUI

struct WatchTogetherCallOverlay: View {
    @ObservedObject var callController: WatchTogetherCallController
    let partnerName: String
    let selfInitial: String
    var onToggleMic: () -> Void
    var onToggleCamera: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                RTCVideoView(track: callController.remoteVideoTrack)
                    .frame(width: 140, height: 186)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        if !callController.isConnected {
                            waitingOverlay
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(BabyTownTheme.accent.opacity(0.3), lineWidth: 1)
                    )

                if callController.isCameraOff {
                    selfAvatarInset
                } else {
                    RTCVideoView(track: callController.localVideoTrack)
                        .frame(width: 56, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(8)
                }
            }

            HStack(spacing: 16) {
                controlButton(
                    systemName: callController.isMicMuted ? "mic.slash.fill" : "mic.fill",
                    label: callController.isMicMuted ? "Unmute microphone" : "Mute microphone",
                    action: onToggleMic
                )
                controlButton(
                    systemName: callController.isCameraOff ? "video.slash.fill" : "video.fill",
                    label: callController.isCameraOff ? "Turn on camera" : "Turn off camera",
                    action: onToggleCamera
                )
            }
        }
        .padding(12)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
    }

    private var waitingOverlay: some View {
        VStack(spacing: 8) {
            ProgressView().tint(BabyTownTheme.accent)
            Text("Waiting for \(partnerName)…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.55))
    }

    private var selfAvatarInset: some View {
        ZStack {
            Circle().fill(BabyTownTheme.accent.opacity(0.25))
            Text(selfInitial.prefix(1).uppercased())
                .font(.headline.weight(.semibold))
                .foregroundStyle(BabyTownTheme.accent)
        }
        .frame(width: 56, height: 74)
        .padding(8)
    }

    private func controlButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.55), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
```

- [ ] **Step 2: Preview in Xcode with mock disconnected state. Expected: layout matches spec sizes.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/WatchTogether/WatchTogetherCallOverlay.swift
git commit -m "feat: add WatchTogether call overlay PiP UI"
```

---

## Task 8: ViewModel + Player Integration

**Files:**
- Create: `BabyTown/ViewModels/WatchTogetherViewModel.swift`
- Modify: `BabyTown/Views/WatchTogether/WatchTogetherPlayerView.swift`

**Interfaces:**
- Produces: `WatchTogetherViewModel` with `@Published var isCameraModeEnabled`, `func enableCamera()`, `func disableCamera()`, `sessionService`

- [ ] **Step 1: Create `BabyTown/ViewModels/WatchTogetherViewModel.swift`**

Gate on `relationshipStage == .officialCouple`. Request `AVCaptureDevice` + `AVAudioSession` permissions before enabling camera. Own `WatchTogetherNetworkGate`, `WatchTogetherSessionService`.

- [ ] **Step 2: Update `WatchTogetherPlayerView`**

Add parameters:
```swift
var sessionID: UUID? = nil   // non-nil when joining from invite
var isHost: Bool = true
```

Layout:
```swift
ZStack {
    // existing YouTube layer
  if viewModel.isCameraModeEnabled {
    VStack {
      Spacer()
      HStack {
        Spacer()
        WatchTogetherCallOverlay(...)
          .padding(.trailing, 20)
          .padding(.bottom, 20)
      }
    }
  }
  // top-left See each other toggle
  // top-right close
}
.onAppear { viewModel.startNetworkGate() }
.onDisappear { viewModel.teardown() }
```

See each other toggle:
- Off → `video.badge.plus` + **See each other**
- On → `video.fill` + **Camera on** with `BabyTownTheme.accent` fill
- Disabled when `!networkGate.isCameraAllowed`

- [ ] **Step 3: Build on device** (simulator camera is limited). Expected: YouTube plays; overlay appears when toggled.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/ViewModels/WatchTogetherViewModel.swift BabyTown/Views/WatchTogether/WatchTogetherPlayerView.swift
git commit -m "feat: integrate camera overlay into WatchTogether player"
```

---

## Task 9: Partner Invite + Deep Link

**Files:**
- Modify: `BabyTown/Services/NotificationManager.swift`
- Modify: `BabyTown/AppDelegate.swift`
- Create: `BabyTown/Views/WatchTogether/WatchTogetherInviteBanner.swift`
- Modify: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`
- Modify: `BabyTown/Views/WatchTogether/WatchTogetherEntryView.swift`

**Interfaces:**
- Produces: `Notification.Name.watchTogetherInviteReceived` with `userInfo`: `sessionID`, `videoURL`, `hostName`

- [ ] **Step 1: Extend `NotificationManager.PartnerEvent`**

```swift
case watchTogetherInvite(hostName: String, sessionID: UUID, videoURL: String)
```

Body: *"Tap to join and watch"*. Title: *"[Name] wants to watch together"*. Identifier: `watch_together_invite_<sessionID>`.

Post `NotificationCenter` event for in-app banner.

- [ ] **Step 2: Create `WatchTogetherInviteBanner.swift`**

Banner at top of `CoupleProfileView` when invite received: *"[Name] started Watch Together"* + **Join** button.

- [ ] **Step 3: Update `AppDelegate.didReceive`**

```swift
} else if identifier.hasPrefix("watch_together_invite_") {
    // parse sessionID + videoURL from userInfo
    NotificationCenter.default.post(name: .watchTogetherInviteReceived, object: nil, userInfo: ...)
}
```

- [ ] **Step 4: Wire `CoupleProfileView`**

`@State private var pendingWatchTogetherInvite: WatchTogetherInvite?`

On **Join**: set landscape orientation, present `WatchTogetherPlayerView(videoURL:sessionID:isHost: false)`.

- [ ] **Step 5: Manual test with Settings debug action** (add temporary debug button mirroring `handlePartnerEvent` pattern) firing a fake invite.

- [ ] **Step 6: Commit**

```bash
git add BabyTown/Services/NotificationManager.swift BabyTown/AppDelegate.swift \
  BabyTown/Views/WatchTogether/WatchTogetherInviteBanner.swift \
  BabyTown/Views/CoupleProfile/CoupleProfileView.swift \
  BabyTown/Views/WatchTogether/WatchTogetherEntryView.swift
git commit -m "feat: add WatchTogether partner invite and deep link routing"
```

---

## Task 10: Info.plist Permission Strings

**Files:**
- Modify: `BabyTown.xcodeproj/project.pbxproj` (Debug + Release `INFOPLIST_KEY_*`)

- [ ] **Step 1: Update build settings**

```
INFOPLIST_KEY_NSCameraUsageDescription = "Covela uses your camera so you and your partner can see each other while watching together.";
INFOPLIST_KEY_NSMicrophoneUsageDescription = "Covela uses your microphone so you and your partner can talk while watching together.";
```

Keep existing strings merged if Xcode only allows one — append Watch Together sentence to existing values.

- [ ] **Step 2: Commit**

```bash
git add BabyTown.xcodeproj/project.pbxproj
git commit -m "chore: update camera and mic usage strings for Watch Together"
```

---

## Task 11: Backend — Sessions REST (SUB-1 + SUB-2)

**Files:** Backend repo (not in iOS tree)

- [ ] **Step 1: Create `watch_together_sessions` collection** per spec schema with TTL index on `expires_at`.

- [ ] **Step 2: Implement endpoints**

| Method | Path | Logic |
|---|---|---|
| POST | `/watch_together/sessions` | Validate couple membership, create doc, enqueue push |
| GET | `/watch_together/sessions/active` | Return non-expired waiting/active for caller's couple |
| POST | `/watch_together/sessions/{id}/join` | Verify partner, set status `active` |
| POST | `/watch_together/sessions/{id}/end` | Set status `ended` or delete |

- [ ] **Step 3: Add iOS `WatchTogetherAPIClient` real implementation** replacing stub calls with JWT-authenticated `URLSession`.

- [ ] **Step 4: Integration test** — two test users, create + join returns 200.

---

## Task 12: Backend — WebSocket Signaling (SUB-3)

- [ ] **Step 1: Add `wss://…/watch_together/{session_id}/signal`** authenticated with JWT.

- [ ] **Step 2: Relay `WatchTogetherSignalMessage` JSON to the other peer only.**

- [ ] **Step 3: Replace `StubWatchTogetherSignalingClient` with `WebSocketWatchTogetherSignalingClient`.**

- [ ] **Step 4: Two-device test on WiFi** — verify P2P connects, video flows, mute/camera toggles work.

---

## Task 13: Backend — APNs Push (SUB-4)

- [ ] **Step 1: Register `registerForRemoteNotifications` in `AppDelegate`** and store device token on user doc.

- [ ] **Step 2: On session create, send push** with payload `{ type: "watch_together_invite", session_id, host_name, video_url }`.

- [ ] **Step 3: Handle remote notification tap** in `AppDelegate` (same path as local invite).

- [ ] **Step 4: Remove Settings debug invite action** once APNs path verified.

---

## Manual QA Checklist (from spec)

- [ ] Host enables camera → partner receives invite (local stub or push)
- [ ] Partner joins → both PiP overlays show
- [ ] Mic mute silences local track; icon updates
- [ ] Camera off shows avatar inset; remote sees frozen/black per WebRTC behavior
- [ ] Offline → See each other disabled with toast
- [ ] Host closes player → partner sees "[Name] left"
- [ ] Pink + Blue themes: accent border on PiP
- [ ] Prelude user cannot access camera mode

---

## Spec Coverage Self-Review

| Spec requirement | Task |
|---|---|
| Bottom-right PiP overlay | Task 7, 8 |
| Mic mute + camera off | Task 4, 7 |
| See each other toggle | Task 8 |
| Push/in-app invite (Option A) | Task 9, 13 |
| P2P WebRTC $0 | Task 4, 12 |
| WiFi/cellular gate | Task 2, 8 |
| Together phase only | Task 8 |
| Copy table | Tasks 7–9 |
| Backend sessions + signaling | Tasks 11–12 |
| No playback sync | Out of scope (not in tasks) |
| No TURN v1 | Task 4 (STUN only) |

---

## Execution Notes

- **Two physical devices required** for real WebRTC QA. Simulator can validate UI only.
- **Stub signaling** (Task 5) does not work across two phones; complete Task 12 before cross-device WebRTC testing, or run a temporary Node signaling server locally.
- Replace `StubWatchTogetherAPIClient.shared` with production client via dependency injection when SUB-2 ships; do not fork call sites.
