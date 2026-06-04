import PhotosUI
import SwiftUI

struct BackgroundMusicSettingsSection: View {

    @State private var pickerItem: PhotosPickerItem?
    @State private var statusMessage: String?
    @State private var isImporting = false

    var body: some View {
        Section {
            PhotosPicker(selection: $pickerItem, matching: .videos) {
                HStack {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 16))
                    Text("Import song from screen recording")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .disabled(isImporting)

            if isImporting {
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
                Text(BackgroundMusicImporter.hasImportedSong ? "Your imported song" : "Default song")
                    .foregroundStyle(.secondary)
            }

            if BackgroundMusicImporter.hasImportedSong {
                Button("Use default song") {
                    useDefaultSong()
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Background Music")
        } footer: {
            Text("Screen-record a song in Spotify, Apple Music, or YouTube, then import the recording here. Baby Town saves only the audio on your device and loops it on the home screen.")
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await importPickedVideo(newItem) }
        }
    }

    @MainActor
    private func importPickedVideo(_ item: PhotosPickerItem) async {
        isImporting = true
        statusMessage = nil
        defer {
            isImporting = false
            pickerItem = nil
        }

        do {
            guard let picked = try await item.loadTransferable(type: PickedBackgroundMusicVideo.self) else {
                statusMessage = BackgroundMusicImporter.ImportError.unreadableVideo.errorDescription
                return
            }
            try await BackgroundMusicImporter.importFromVideo(at: picked.url)
            statusMessage = "Imported — your song will loop on the home screen."
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func useDefaultSong() {
        statusMessage = nil
        BackgroundMusicImporter.clearImportedSong()
        statusMessage = "Using the default Baby Town song."
    }
}
