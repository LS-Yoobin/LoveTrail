import Combine
import PhotosUI
import SwiftUI

@MainActor
final class BackgroundMusicImportCoordinator: ObservableObject {
    @Published var pickerItem: PhotosPickerItem?
    @Published var isImporting = false
    @Published var statusMessage: String?
    /// Set after a successful import so the host can prompt for a display name.
    @Published var trackAwaitingName: CouplePlaylistTrack?

    func importPickedVideo(_ item: PhotosPickerItem) async {
        isImporting = true
        statusMessage = nil
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
            let track = try await BackgroundMusicImporter.importFromVideo(at: picked.url)
            trackAwaitingName = track
            statusMessage = nil
            beginPlayback(for: track)
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func finishNamingTrack(id: UUID, displayName: String) {
        CouplePlaylistStore.updateDisplayName(id: id, displayName: displayName)
        trackAwaitingName = nil
        CoupleMusicPlaybackState.shared.refreshFromStore()
    }

    func dismissNamingPrompt() {
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
