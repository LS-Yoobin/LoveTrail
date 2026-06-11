import PhotosUI
import SwiftUI

struct BackgroundMusicSettingsSection: View {

    var onManagePlaylist: () -> Void = {}

    @ObservedObject private var playbackState = CoupleMusicPlaybackState.shared
    @StateObject private var importCoordinator = BackgroundMusicImportCoordinator()

    private var trackSummary: String {
        guard CouplePlaylistStore.hasTracks else {
            return CoupleMusicPlaybackState.emptyPlaylistTitle
        }
        return playbackState.currentTrackTitle
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
                    .multilineTextAlignment(.trailing)
            }

            if CouplePlaylistStore.hasTracks {
                Button("Manage playlist") {
                    onManagePlaylist()
                }
            }
        } header: {
            Text("Background Music")
        } footer: {
            Text("Screen-record a song in Spotify, Apple Music, or YouTube, then import the recording here. Songs play in Secret Garden → Our Song when you open your couple space.")
        }
        .onAppear {
            importCoordinator.clearStatus()
            playbackState.refreshFromStore()
        }
        .onChange(of: importCoordinator.pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await importCoordinator.importPickedVideo(newItem) }
        }
        .sheet(item: $importCoordinator.draftAwaitingTrim) { draft in
            CoupleSongTrimSheet(
                draft: draft,
                isSaving: importCoordinator.isTrimming,
                onCancel: { importCoordinator.cancelTrim(draft: draft) },
                onSave: { start, end in
                    Task {
                        await importCoordinator.confirmTrim(
                            draft: draft,
                            startSeconds: start,
                            endSeconds: end
                        )
                    }
                }
            )
        }
        .sheet(item: $importCoordinator.trackAwaitingName) { track in
            CoupleSongNameSheet(
                title: "Name your song",
                subtitle: "Give this track a name for your couple playlist.",
                initialName: track.displayName,
                onCancel: { importCoordinator.dismissNamingPrompt() },
                onConfirm: { name in
                    importCoordinator.finishNamingTrack(id: track.id, displayName: name)
                }
            )
        }
        .alert(
            "Couldn't import",
            isPresented: importErrorPresented,
            actions: {
                Button("OK") { importCoordinator.clearStatus() }
            },
            message: {
                Text(importCoordinator.statusMessage ?? "")
            }
        )
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { importCoordinator.statusMessage != nil },
            set: { if !$0 { importCoordinator.clearStatus() } }
        )
    }

}
