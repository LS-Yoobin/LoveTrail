import SwiftUI
import AVKit

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    
    func makeUIView(context: Context) -> UIView {
        return PlayerUIView(videoName: videoName)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private class PlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    
    init(videoName: String) {
        super.init(frame: .zero)
        
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            print("Video file not found: \(videoName).mp4")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        player = AVPlayer(url: url)
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer!)
        
        player?.isMuted = true
        player?.play()
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
