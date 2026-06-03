import AVFoundation
import UIKit

class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    private var homeAudioPlayer: AVAudioPlayer?
    private var homeStreamPlayer: AVPlayer?
    private var homeStreamEndObserver: NSObjectProtocol?
    private var ringtonePlayer: AVAudioPlayer?
    private var footstepsPlayer: AVAudioPlayer?
    private var carSfxPlayer: AVAudioPlayer?
    private var isLoadingCustomHomeMusic = false
    private var preferenceObserver: NSObjectProtocol?

    private init() {
        preferenceObserver = NotificationCenter.default.addObserver(
            forName: .backgroundMusicPreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadHomeMusic()
        }
    }

    func playConcertMusic() {
        let musicFiles = [
            "The Chainsmokers - Closer (Lyric) ft. Halsey",
            "concert_lights"
        ]

        var url: URL?
        for file in musicFiles {
            if let fileUrl = Bundle.main.url(forResource: file, withExtension: "mp3") {
                url = fileUrl
                break
            }
        }

        guard let musicUrl = url else {
            print("Background music file not found. Tried: \(musicFiles)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: musicUrl)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.5
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing background music: \(error.localizedDescription)")
        }
    }

    func stopMusic() {
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
    }

    func playHomeMusic() {
        if isHomeMusicPlaying { return }

        stopMusic()
        stopEmbeddedHomeMusic()

        guard let link = BackgroundMusicPreferences.parsedLink else {
            playBundledHomeMusic()
            return
        }

        guard !isLoadingCustomHomeMusic else { return }
        isLoadingCustomHomeMusic = true
        Task { @MainActor in
            defer { isLoadingCustomHomeMusic = false }
            await playCustomHomeMusic(link: link)
        }
    }

    func reloadHomeMusic() {
        isLoadingCustomHomeMusic = false
        stopHomeMusic()
        playHomeMusic()
    }

    private var isHomeMusicPlaying: Bool {
        if let player = homeAudioPlayer, player.isPlaying { return true }
        if let player = homeStreamPlayer, player.rate > 0 { return true }
        return false
    }

    @MainActor
    private func playCustomHomeMusic(link: BackgroundMusicLink) async {
        stopBundledHomeMusic()
        stopStreamHomeMusic()
        stopEmbeddedHomeMusic()

        activatePlaybackSession()

        do {
            if let streamURL = try await BackgroundMusicStreamResolver.resolveStreamURL(for: link) {
                playStreamHomeMusic(url: streamURL)
                return
            }
        } catch {
            print("Custom stream resolve failed: \(error.localizedDescription)")
        }

        if BackgroundMusicStreamResolver.shouldUseEmbedPlayer(for: link),
           await playEmbeddedHomeMusic(link: link) {
            return
        }

        print("Falling back to bundled home music after custom link failed.")
        playBundledHomeMusic()
    }

    private func playStreamHomeMusic(url: URL) {
        stopStreamHomeMusic()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = 0.3
        homeStreamPlayer = player

        if let observer = homeStreamEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        homeStreamEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        player.play()
    }

    private func playBundledHomeMusic() {
        stopStreamHomeMusic()
        stopEmbeddedHomeMusic()

        let musicFiles = [
            "The Weeknd - The Abyss (Audio)",
            "The weekend - the abyss",
            "the_weekend_the_abyss",
            "The Weeknd - The Abyss"
        ]

        var url: URL?
        for file in musicFiles {
            if let fileUrl = Bundle.main.url(forResource: file, withExtension: "mp3") {
                url = fileUrl
                break
            }
        }

        guard let musicUrl = url else {
            print("Home music file not found. Tried: \(musicFiles)")
            return
        }

        do {
            activatePlaybackSession()
            homeAudioPlayer = try AVAudioPlayer(contentsOf: musicUrl)
            homeAudioPlayer?.numberOfLoops = -1
            homeAudioPlayer?.volume = 0.3
            homeAudioPlayer?.prepareToPlay()
            homeAudioPlayer?.play()
        } catch {
            print("Error playing home music: \(error.localizedDescription)")
        }
    }

    func stopHomeMusic() {
        stopBundledHomeMusic()
        stopStreamHomeMusic()
        stopEmbeddedHomeMusic()
    }

    private func stopBundledHomeMusic() {
        if let player = homeAudioPlayer, player.isPlaying {
            player.stop()
        }
        homeAudioPlayer = nil
    }

    private func stopStreamHomeMusic() {
        homeStreamPlayer?.pause()
        homeStreamPlayer = nil
        if let observer = homeStreamEndObserver {
            NotificationCenter.default.removeObserver(observer)
            homeStreamEndObserver = nil
        }
    }

    @MainActor
    private func stopEmbeddedHomeMusic() {
        EmbeddedBackgroundMusicPlayer.shared.stop()
    }

    private func activatePlaybackSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    @MainActor
    private func playEmbeddedHomeMusic(link: BackgroundMusicLink) async -> Bool {
        guard link.kind == .spotify || BackgroundMusicStreamResolver.embedURL(for: link) != nil else {
            return false
        }

        for attempt in 0..<5 {
            if let host = embedHostView() {
                EmbeddedBackgroundMusicPlayer.shared.play(link: link, in: host)
                return true
            }
            if attempt < 4 {
                try? await Task.sleep(nanoseconds: 80_000_000 * UInt64(attempt + 1))
            }
        }
        print("Embedded background music failed: no host view for WKWebView.")
        return false
    }

    private func embedHostView() -> UIView? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .view
    }

    func playRingtone() {
        if let player = ringtonePlayer, player.isPlaying {
            return
        }

        guard let url = Bundle.main.url(forResource: "ringtone", withExtension: "mp3") else {
            print("Ringtone file not found")
            return
        }

        do {
            activatePlaybackSession()
            ringtonePlayer = try AVAudioPlayer(contentsOf: url)
            ringtonePlayer?.numberOfLoops = -1
            ringtonePlayer?.volume = 0.6
            ringtonePlayer?.prepareToPlay()
            ringtonePlayer?.play()
        } catch {
            print("Error playing ringtone: \(error.localizedDescription)")
        }
    }

    func stopRingtone() {
        if let player = ringtonePlayer, player.isPlaying {
            player.stop()
        }
        ringtonePlayer = nil
    }

    func playFootsteps() {
        if let player = footstepsPlayer, player.isPlaying {
            return
        }

        guard let url = Bundle.main.url(forResource: "minecraft-footsteps-sound-effect-made-with-Voicemod", withExtension: "mp3") else {
            print("Footsteps file not found")
            return
        }

        do {
            activatePlaybackSession()
            footstepsPlayer = try AVAudioPlayer(contentsOf: url)
            footstepsPlayer?.numberOfLoops = -1
            footstepsPlayer?.volume = 0.5
            footstepsPlayer?.prepareToPlay()
            footstepsPlayer?.play()
        } catch {
            print("Error playing footsteps: \(error.localizedDescription)")
        }
    }

    func stopFootsteps() {
        if let player = footstepsPlayer, player.isPlaying {
            player.stop()
        }
        footstepsPlayer = nil
    }

    func playCarDoorThenEngine() {
        guard let doorUrl = Bundle.main.url(forResource: "dragon-studio-open-car-door-372469", withExtension: "mp3"),
              let engineUrl = Bundle.main.url(forResource: "dragon-studio-car-engine-372477", withExtension: "mp3") else {
            print("Car sound files not found")
            return
        }

        do {
            activatePlaybackSession()
            carSfxPlayer = try AVAudioPlayer(contentsOf: doorUrl)
            carSfxPlayer?.volume = 0.6
            carSfxPlayer?.prepareToPlay()
            carSfxPlayer?.play()

            let doorDuration = carSfxPlayer?.duration ?? 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + doorDuration) { [weak self] in
                do {
                    self?.carSfxPlayer = try AVAudioPlayer(contentsOf: engineUrl)
                    self?.carSfxPlayer?.volume = 0.6
                    self?.carSfxPlayer?.prepareToPlay()
                    self?.carSfxPlayer?.play()
                } catch {
                    print("Error playing car engine: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error playing car door: \(error.localizedDescription)")
        }
    }

    func stopCarSfx() {
        if let player = carSfxPlayer, player.isPlaying {
            player.stop()
        }
        carSfxPlayer = nil
    }

    func playYipee() {
        guard let url = Bundle.main.url(forResource: "freesound_community-yipee-45360", withExtension: "mp3") else {
            print("Yipee sound file not found")
            return
        }

        do {
            activatePlaybackSession()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.volume = 0.7
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing yipee: \(error.localizedDescription)")
        }
    }
}
