import Combine
import PhotosUI
import SwiftUI

@MainActor
final class BackgroundMusicImportCoordinator: ObservableObject {
    @Published var pickerItem: PhotosPickerItem?
    @Published var isImporting = false
    @Published var isTrimming = false
    @Published var statusMessage: String?
    @Published var draftAwaitingTrim: AudioTrimDraft?
    @Published var trackAwaitingName: CouplePlaylistTrack?

    func importPickedVideo(_ item: PhotosPickerItem) async {
        isImporting = true
        statusMessage = nil
        draftAwaitingTrim = nil
        trackAwaitingName = nil
        defer {
            isImporting = false
            pickerItem = nil
        }

        do {
            guard let picked = try await item.loadTransferable(type: PickedBackgroundMusicVideo.self) else {
                statusMessage = BackgroundMusicImporter.ImportError.unreadableVideo.errorDescription
                return
            }
            let tempURL = try await BackgroundMusicImporter.extractAudioFromVideo(at: picked.url)
            let duration = try await BackgroundMusicTrimmer.duration(of: tempURL)
            let proposedName = "Song \(CouplePlaylistStore.tracks.count + 1)"
            draftAwaitingTrim = AudioTrimDraft(
                id: UUID(),
                sourceURL: tempURL,
                duration: duration,
                proposedName: proposedName
            )
            statusMessage = nil
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func confirmTrim(draft: AudioTrimDraft, startSeconds: TimeInterval, endSeconds: TimeInterval) async {
        isTrimming = true
        statusMessage = nil
        defer { isTrimming = false }

        do {
            let trimmedURL = try await BackgroundMusicTrimmer.exportTrimmed(
                sourceURL: draft.sourceURL,
                startSeconds: startSeconds,
                endSeconds: endSeconds
            )
            defer {
                BackgroundMusicImporter.discardExtractedAudio(at: draft.sourceURL)
                try? FileManager.default.removeItem(at: trimmedURL)
            }

            let track = try CouplePlaylistStore.addTrack(
                fromExportedAudioAt: trimmedURL,
                proposedDisplayName: draft.proposedName
            )
            UserDefaults.standard.removeObject(forKey: "customBackgroundMusicLink")
            draftAwaitingTrim = nil
            trackAwaitingName = track
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func cancelTrim(draft: AudioTrimDraft) {
        BackgroundMusicImporter.discardExtractedAudio(at: draft.sourceURL)
        draftAwaitingTrim = nil
    }

    func finishNamingTrack(id: UUID, displayName: String) {
        CouplePlaylistStore.updateDisplayName(id: id, displayName: displayName)
        trackAwaitingName = nil
        if let track = CouplePlaylistStore.track(withID: id) {
            beginPlayback(for: track)
        } else {
            CoupleMusicPlaybackState.shared.refreshFromStore()
        }
    }

    func dismissNamingPrompt() {
        if let track = trackAwaitingName {
            beginPlayback(for: track)
        }
        trackAwaitingName = nil
    }

    func beginPlayback(for track: CouplePlaylistTrack) {
        CouplePlaylistStore.setNowPlaying(id: track.id)
        AudioManager.shared.reloadHomeMusic()
        CoupleMusicPlaybackState.shared.refreshFromStore()
    }

    func clearStatus() {
        statusMessage = nil
    }
}
