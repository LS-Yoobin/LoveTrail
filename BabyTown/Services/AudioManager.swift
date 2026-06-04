import AVFoundation
import UIKit

class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    private var homeAudioPlayer: AVAudioPlayer?
    private var ringtonePlayer: AVAudioPlayer?
    private var footstepsPlayer: AVAudioPlayer?
    private var carSfxPlayer: AVAudioPlayer?
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

        if let importedURL = BackgroundMusicImporter.importedAudioURL {
            playImportedHomeMusic(url: importedURL)
            return
        }

        playBundledHomeMusic()
    }

    func reloadHomeMusic() {
        stopHomeMusic()
        playHomeMusic()
    }

    private var isHomeMusicPlaying: Bool {
        if let player = homeAudioPlayer, player.isPlaying { return true }
        return false
    }

    private func playImportedHomeMusic(url: URL) {
        do {
            activatePlaybackSession()
            homeAudioPlayer = try AVAudioPlayer(contentsOf: url)
            homeAudioPlayer?.numberOfLoops = -1
            homeAudioPlayer?.volume = 0.3
            homeAudioPlayer?.prepareToPlay()
            homeAudioPlayer?.play()
        } catch {
            print("Error playing imported home music: \(error.localizedDescription)")
            playBundledHomeMusic()
        }
    }

    private func playBundledHomeMusic() {

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
    }

    private func stopBundledHomeMusic() {
        if let player = homeAudioPlayer, player.isPlaying {
            player.stop()
        }
        homeAudioPlayer = nil
    }

    private func activatePlaybackSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
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
