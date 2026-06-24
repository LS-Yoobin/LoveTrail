import Combine
import PhotosUI
import SwiftUI

struct PreludeGiftSongDraft: Identifiable {
    let id: UUID = UUID()
    var initialName: String
    var audioData: Data
}

@MainActor
final class PreludeGiftSongImportCoordinator: ObservableObject {
    @Published var pickerItem: PhotosPickerItem?
    @Published var draftAwaitingTrim: AudioTrimDraft?
    @Published var trackAwaitingName: PreludeGiftSongDraft?
    @Published var isImporting: Bool = false
    @Published var isTrimming: Bool = false
    @Published var statusMessage: String?

    var onSongSaved: (PreludeGiftSong) -> Void = { _ in }

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
            draftAwaitingTrim = AudioTrimDraft(
                id: UUID(),
                sourceURL: tempURL,
                duration: duration,
                proposedName: "Our song"
            )
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
            let audioData = try Data(contentsOf: trimmedURL)
            BackgroundMusicImporter.discardExtractedAudio(at: draft.sourceURL)
            try? FileManager.default.removeItem(at: trimmedURL)
            draftAwaitingTrim = nil
            trackAwaitingName = PreludeGiftSongDraft(
                initialName: draft.proposedName,
                audioData: audioData
            )
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func cancelTrim(draft: AudioTrimDraft) {
        BackgroundMusicImporter.discardExtractedAudio(at: draft.sourceURL)
        draftAwaitingTrim = nil
    }

    func finishNamingTrack(displayName: String) {
        guard let draft = trackAwaitingName else { return }
        let song = PreludeGiftSong(fileName: "audio.m4a", displayName: displayName)
        DataPersistenceManager.shared.savePreludeGiftSong(song, audioData: draft.audioData)
        trackAwaitingName = nil
        onSongSaved(song)
    }

    func dismissNamingPrompt() {
        trackAwaitingName = nil
    }
}
