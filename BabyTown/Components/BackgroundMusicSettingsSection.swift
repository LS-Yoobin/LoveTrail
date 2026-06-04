import PhotosUI
import SwiftUI

struct BackgroundMusicSettingsSection: View {

    @StateObject private var importCoordinator = BackgroundMusicImportCoordinator()

    private var trackSummary: String {
        let count = CouplePlaylistStore.tracks.count
        if count == 0 { return "Default song" }
        if count == 1, let name = CouplePlaylistStore.nowPlayingTrack?.displayName {
            return name
        }
        return "\(count) songs in playlist"
    }

    var body: some View {
        Section {
            PhotosPicker(selection: $importCoordinator.pickerItem, matching: .videos) {
                HStack {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 16))
                    Text("Import song from screen recording")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .disabled(importCoordinator.isImporting || !CouplePlaylistStore.canAddTrack)

            if importCoordinator.isImporting {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Extracting audio…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Current")
                Spacer()
                Text(trackSummary)
                    .foregroundStyle(.secondary)
            }

            if CouplePlaylistStore.hasTracks {
                Button("Use default song") {
                    useDefaultSong()
                }
            }

            if let statusMessage = importCoordinator.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Background Music")
        } footer: {
            Text("Screen-record a song in Spotify, Apple Music, or YouTube, then import the recording here. You can manage up to 10 songs in Secret Garden → Our Song.")
        }
        .onChange(of: importCoordinator.pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await importCoordinator.importPickedVideo(newItem) }
        }
        .sheet(item: $importCoordinator.trackAwaitingName) { track in
            CoupleSongNameSheet(
                title: "Name your song",
                subtitle: "Give this track a name for your couple playlist.",
                initialName: track.displayName,
                confirmTitle: "Save & play",
                onCancel: { importCoordinator.dismissNamingPrompt() },
                onConfirm: { name in
                    importCoordinator.finishNamingTrack(id: track.id, displayName: name)
                }
            )
        }
    }

    private func useDefaultSong() {
        importCoordinator.clearStatus()
        CouplePlaylistStore.clearAll()
        AudioManager.shared.reloadHomeMusic()
        importCoordinator.statusMessage = "Using the default Baby Town song."
    }
}
