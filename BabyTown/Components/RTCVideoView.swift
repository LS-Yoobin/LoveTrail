import SwiftUI
import WebRTC

struct RTCVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?
    var mirroredHorizontally: Bool = false

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        view.delegate = context.coordinator
        applyMirror(to: view)
        context.coordinator.attach(track, to: view)
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        applyMirror(to: uiView)
        context.coordinator.attach(track, to: uiView)
    }

    private func applyMirror(to view: RTCMTLVideoView) {
        view.transform = mirroredHorizontally
            ? CGAffineTransform(scaleX: -1, y: 1)
            : .identity
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, RTCVideoViewDelegate {
        private var currentTrack: RTCVideoTrack?
        private weak var currentView: RTCMTLVideoView?

        func attach(_ track: RTCVideoTrack?, to view: RTCMTLVideoView) {
            if currentTrack === track, currentView === view { return }
            if let currentTrack, let currentView {
                currentTrack.remove(currentView)
            }
            currentTrack = track
            currentView = view
            track?.add(view)
        }

        func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {}
    }
}
