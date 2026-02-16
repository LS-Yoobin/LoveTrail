import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    private var homeAudioPlayer: AVAudioPlayer?
    private var ringtonePlayer: AVAudioPlayer?
    private var footstepsPlayer: AVAudioPlayer?
    private var carSfxPlayer: AVAudioPlayer?
    
    private init() {}
    
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
            // Configure audio session to play even if mute switch is on
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: musicUrl)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.5 // Set initial volume
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
        // Prevent restarting if already playing
        if let player = homeAudioPlayer, player.isPlaying {
            return
        }
        
        // Stop other music if playing? Maybe not if we want to support mixing, but usually one bgm at a time.
        stopMusic() 
        
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            homeAudioPlayer = try AVAudioPlayer(contentsOf: musicUrl)
            homeAudioPlayer?.numberOfLoops = -1 // Loop indefinitely
            homeAudioPlayer?.volume = 0.3 // Lower volume for home BGM
            homeAudioPlayer?.prepareToPlay()
            homeAudioPlayer?.play()
        } catch {
            print("Error playing home music: \(error.localizedDescription)")
        }
    }
    
    func stopHomeMusic() {
        if let player = homeAudioPlayer, player.isPlaying {
            player.stop()
        }
        homeAudioPlayer = nil
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

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

    /// Plays car door open, then car engine sequentially
    func playCarDoorThenEngine() {
        guard let doorUrl = Bundle.main.url(forResource: "dragon-studio-open-car-door-372469", withExtension: "mp3"),
              let engineUrl = Bundle.main.url(forResource: "dragon-studio-car-engine-372477", withExtension: "mp3") else {
            print("Car sound files not found")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            carSfxPlayer = try AVAudioPlayer(contentsOf: doorUrl)
            carSfxPlayer?.volume = 0.6
            carSfxPlayer?.prepareToPlay()
            carSfxPlayer?.play()

            // After door sound finishes, play engine
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

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
