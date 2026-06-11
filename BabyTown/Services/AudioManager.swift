import AVFoundation
import UIKit

class AudioManager: NSObject {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    private var homeAudioPlayer: AVAudioPlayer?
    private var ringtonePlayer: AVAudioPlayer?
    private var footstepsPlayer: AVAudioPlayer?
    private var carSfxPlayer: AVAudioPlayer?
    private var preferenceObserver: NSObjectProtocol?

    private var shuffleQueue: [UUID] = []
    private var shuffleQueueIndex = 0
    private var currentPlayingTrackID: UUID?
    private var isGardenActive = false
    private var isUserPaused = false

    var gardenIsActive: Bool { isGardenActive }

    private override init() {
        super.init()
        preferenceObserver = NotificationCenter.default.addObserver(
            forName: .backgroundMusicPreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self?.isGardenActive == true else { return }
            self?.reloadGardenMusic()
        }
    }

    func setGardenActive(_ active: Bool) {
        isGardenActive = active
        if active {
            isUserPaused = false
            playGardenMusic()
        } else {
            stopGardenMusic()
            isUserPaused = false
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

    func playGardenMusic() {
        guard isGardenActive else { return }
        stopMusic()
        _ = CouplePlaylistStore.tracks
        if CouplePlaylistStore.hasTracks {
            playCurrentPlaylistTrack()
        } else {
            stopGardenMusicForEmptyPlaylist()
        }
    }

    func reloadGardenMusic() {
        guard isGardenActive else { return }
        stopBundledGardenMusic()
        currentPlayingTrackID = nil
        resetShuffleQueue()
        if CouplePlaylistStore.hasTracks {
            playCurrentPlaylistTrack()
        } else {
            stopGardenMusicForEmptyPlaylist()
        }
    }

    func pauseGardenMusic() {
        guard isGardenActive else { return }
        homeAudioPlayer?.pause()
        isUserPaused = true
        updatePlaybackState(isPlaying: false, track: resolvedNowPlayingTrack())
    }

    func resumeGardenMusic() {
        guard isGardenActive, CouplePlaylistStore.hasTracks else { return }
        isUserPaused = false
        if let player = homeAudioPlayer {
            player.play()
            updatePlaybackState(isPlaying: true, track: resolvedNowPlayingTrack())
        } else {
            playCurrentPlaylistTrack()
        }
    }

    func toggleGardenPlayback() {
        if isGardenMusicPlaying {
            pauseGardenMusic()
        } else {
            resumeGardenMusic()
        }
    }

    func skipToNextTrack() {
        guard isGardenActive, CouplePlaylistStore.hasTracks else { return }
        guard let nextID = nextTrackID() else { return }
        CouplePlaylistStore.setNowPlaying(id: nextID)
        stopBundledGardenMusic()
        currentPlayingTrackID = nil
        resetShuffleQueueIfNeeded()
        playCurrentPlaylistTrack()
    }

    func skipToPreviousTrack() {
        guard isGardenActive, CouplePlaylistStore.hasTracks else { return }
        guard let previousID = previousTrackID() else { return }
        CouplePlaylistStore.setNowPlaying(id: previousID)
        stopBundledGardenMusic()
        currentPlayingTrackID = nil
        playCurrentPlaylistTrack()
    }

    private var isGardenMusicPlaying: Bool {
        if let player = homeAudioPlayer, player.isPlaying { return true }
        return false
    }

    private func playCurrentPlaylistTrack() {
        guard isGardenActive else { return }
        guard let track = resolvedNowPlayingTrack() else {
            stopGardenMusicForEmptyPlaylist()
            return
        }
        let url = CouplePlaylistStore.audioURL(for: track)
        guard FileManager.default.fileExists(atPath: url.path) else {
            stopGardenMusicForEmptyPlaylist()
            return
        }

        if currentPlayingTrackID == track.id, isGardenMusicPlaying {
            updatePlaybackState(isPlaying: true, track: track)
            return
        }
        if currentPlayingTrackID == track.id, homeAudioPlayer != nil, isUserPaused {
            updatePlaybackState(isPlaying: false, track: track)
            return
        }

        stopBundledGardenMusic()
        currentPlayingTrackID = track.id

        do {
            activatePlaybackSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.numberOfLoops = CouplePlaylistStore.repeatEnabled ? -1 : 0
            player.volume = 0.3
            player.prepareToPlay()
            homeAudioPlayer = player
            if isUserPaused {
                updatePlaybackState(isPlaying: false, track: track)
            } else {
                player.play()
                updatePlaybackState(isPlaying: true, track: track)
            }
        } catch {
            print("Error playing imported garden music: \(error.localizedDescription)")
            currentPlayingTrackID = nil
            stopGardenMusicForEmptyPlaylist()
        }
    }

    private func resolvedNowPlayingTrack() -> CouplePlaylistTrack? {
        CouplePlaylistStore.nowPlayingTrack
    }

    private func stopGardenMusicForEmptyPlaylist() {
        currentPlayingTrackID = nil
        stopBundledGardenMusic()
        updatePlaybackState(isPlaying: false, track: nil)
    }

    func stopGardenMusic() {
        stopBundledGardenMusic()
        currentPlayingTrackID = nil
        updatePlaybackState(isPlaying: false, track: CouplePlaylistStore.nowPlayingTrack)
    }

    private func stopBundledGardenMusic() {
        if let player = homeAudioPlayer, player.isPlaying {
            player.stop()
        }
        homeAudioPlayer = nil
    }

    private func advanceToNextTrack() {
        guard CouplePlaylistStore.hasTracks else {
            stopGardenMusicForEmptyPlaylist()
            return
        }

        if CouplePlaylistStore.repeatEnabled {
            playCurrentPlaylistTrack()
            return
        }

        guard let nextID = nextTrackID() else {
            stopGardenMusicForEmptyPlaylist()
            return
        }

        CouplePlaylistStore.setNowPlaying(id: nextID)
        resetShuffleQueueIfNeeded()
        playCurrentPlaylistTrack()
    }

    private func nextTrackID() -> UUID? {
        let ordered = CouplePlaylistStore.tracks
        guard !ordered.isEmpty else { return nil }

        if CouplePlaylistStore.shuffleEnabled {
            if shuffleQueue.isEmpty {
                rebuildShuffleQueue(avoidingFirst: nil)
            }
            let current = currentPlayingTrackID ?? CouplePlaylistStore.nowPlayingID
            if let current, let idx = shuffleQueue.firstIndex(of: current) {
                let nextIdx = idx + 1
                if nextIdx < shuffleQueue.count {
                    return shuffleQueue[nextIdx]
                }
                rebuildShuffleQueue(avoidingFirst: current)
                return shuffleQueue.first
            }
            return shuffleQueue.first ?? ordered.first?.id
        }

        guard let current = currentPlayingTrackID ?? CouplePlaylistStore.nowPlayingID,
              let currentIndex = ordered.firstIndex(where: { $0.id == current }) else {
            return ordered.first?.id
        }
        let nextIndex = (currentIndex + 1) % ordered.count
        return ordered[nextIndex].id
    }

    private func previousTrackID() -> UUID? {
        let ordered = CouplePlaylistStore.tracks
        guard !ordered.isEmpty else { return nil }

        if CouplePlaylistStore.shuffleEnabled {
            if shuffleQueue.isEmpty {
                rebuildShuffleQueue(avoidingFirst: nil)
            }
            let current = currentPlayingTrackID ?? CouplePlaylistStore.nowPlayingID
            if let current, let idx = shuffleQueue.firstIndex(of: current), idx > 0 {
                return shuffleQueue[idx - 1]
            }
            return shuffleQueue.last ?? ordered.last?.id
        }

        guard let current = currentPlayingTrackID ?? CouplePlaylistStore.nowPlayingID,
              let currentIndex = ordered.firstIndex(where: { $0.id == current }) else {
            return ordered.last?.id
        }
        let previousIndex = (currentIndex - 1 + ordered.count) % ordered.count
        return ordered[previousIndex].id
    }

    private func rebuildShuffleQueue(avoidingFirst avoidID: UUID?) {
        var ids = CouplePlaylistStore.tracks.map(\.id)
        guard !ids.isEmpty else {
            shuffleQueue = []
            return
        }
        ids.shuffle()
        if let avoidID, ids.count > 1, ids[0] == avoidID, let swapIndex = ids.indices.dropFirst().first {
            ids.swapAt(0, swapIndex)
        }
        shuffleQueue = ids
        shuffleQueueIndex = 0
    }

    private func resetShuffleQueue() {
        shuffleQueue = []
        shuffleQueueIndex = 0
    }

    private func resetShuffleQueueIfNeeded() {
        if CouplePlaylistStore.shuffleEnabled, shuffleQueue.isEmpty {
            rebuildShuffleQueue(avoidingFirst: nil)
        }
    }

    private func updatePlaybackState(isPlaying: Bool, track: CouplePlaylistTrack?) {
        Task { @MainActor in
            CoupleMusicPlaybackState.shared.setPlaying(isPlaying)
            CoupleMusicPlaybackState.shared.refreshFromStore()
        }
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

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === homeAudioPlayer, flag else { return }
        guard !CouplePlaylistStore.repeatEnabled else { return }
        advanceToNextTrack()
    }
}
