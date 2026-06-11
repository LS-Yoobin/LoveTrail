import AVKit
import SwiftUI

enum ReelPlayerStyle {
    case hero
    case immersive
}

struct ReelPlayerView: View {

    let url: URL
    var style: ReelPlayerStyle = .hero
    var isActive: Bool = true

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            switch style {
            case .hero:
                ReelHeroPlayerRepresentable(player: player, isActive: isActive)
            case .immersive:
                VideoPlayer(player: player)
            }
        }
        .onAppear { preparePlayer() }
        .onChange(of: isActive) { _, active in
            setPlayback(active: active)
        }
        .onDisappear {
            player?.pause()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
        ) { notification in
            guard style == .hero,
                  let item = notification.object as? AVPlayerItem,
                  item == player?.currentItem else { return }
            player?.seek(to: .zero)
            player?.play()
        }
    }

    private func preparePlayer() {
        if player == nil {
            let newPlayer = AVPlayer(url: url)
            if style == .hero {
                newPlayer.actionAtItemEnd = .none
            }
            player = newPlayer
        }
        setPlayback(active: isActive)
    }

    private func setPlayback(active: Bool) {
        guard let player else { return }
        if active {
            player.play()
        } else {
            player.pause()
        }
    }
}

private struct ReelHeroPlayerRepresentable: UIViewRepresentable {

    let player: AVPlayer?
    let isActive: Bool

    func makeUIView(context: Context) -> ReelHeroPlayerUIView {
        let view = ReelHeroPlayerUIView()
        view.attach(player: player)
        view.setActive(isActive)
        return view
    }

    func updateUIView(_ uiView: ReelHeroPlayerUIView, context: Context) {
        uiView.attach(player: player)
        uiView.setActive(isActive)
    }
}

private final class ReelHeroPlayerUIView: UIView {

    private var playerLayer: AVPlayerLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func attach(player: AVPlayer?) {
        guard playerLayer?.player !== player else { return }

        playerLayer?.removeFromSuperlayer()
        guard let player else {
            playerLayer = nil
            return
        }

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        playerLayer = layer
        setNeedsLayout()
    }

    func setActive(_ active: Bool) {
        guard let player = playerLayer?.player else { return }
        if active {
            player.play()
        } else {
            player.pause()
        }
    }
}
