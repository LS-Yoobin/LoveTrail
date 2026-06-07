import AVFoundation
import SwiftUI

/// Manage the couple playlist (Change): select now playing, remove tracks.
struct CouplePlaylistEditorSheet: View {
    var dismissOnSelect = true

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playbackState = CoupleMusicPlaybackState.shared

    @State private var tracks: [CouplePlaylistTrack] = []
    @State private var nowPlayingID: UUID?
    @State private var trackToEdit: CouplePlaylistTrack?
    @State private var showRemoveAllConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if tracks.isEmpty {
                    ContentUnavailableView(
                        "No songs yet",
                        systemImage: "music.note.list",
                        description: Text("Import your first song from Settings or Secret Garden → Our Song.")
                    )
                } else {
                    List {
                        ForEach(tracks) { track in
                            trackRow(track)
                        }
                        .onDelete(perform: deleteTracks)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !tracks.isEmpty {
                    Button("Remove all songs", role: .destructive) {
                        showRemoveAllConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
            .navigationTitle("Couple Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: reload)
            .sheet(item: $trackToEdit) { track in
                CoupleSongEditSheet(
                    track: track,
                    onCancel: { trackToEdit = nil },
                    onSaved: {
                        trackToEdit = nil
                        reload()
                        playbackState.refreshFromStore()
                    }
                )
            }
            .confirmationDialog(
                "Remove all songs?",
                isPresented: $showRemoveAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove all songs", role: .destructive) {
                    removeAllSongs()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every imported song from your couple playlist. This can't be undone.")
            }
        }
    }

    private func trackRow(_ track: CouplePlaylistTrack) -> some View {
        HStack(spacing: 12) {
            Button {
                selectTrack(track)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let duration = formattedDuration(for: track) {
                            Text(duration)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if nowPlayingID == track.id {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(BabyTownTheme.accent)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                trackToEdit = track
            } label: {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(track.displayName)")
        }
    }

    private func formattedDuration(for track: CouplePlaylistTrack) -> String? {
        let url = CouplePlaylistStore.audioURL(for: track)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        let seconds = Int(player.duration.rounded())
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func reload() {
        tracks = CouplePlaylistStore.tracks
        nowPlayingID = CouplePlaylistStore.nowPlayingID ?? tracks.first?.id
    }

    private func selectTrack(_ track: CouplePlaylistTrack) {
        CouplePlaylistStore.setNowPlaying(id: track.id)
        nowPlayingID = track.id
        AudioManager.shared.reloadHomeMusic()
        playbackState.refreshFromStore()
        if dismissOnSelect {
            dismiss()
        }
    }

    private func deleteTracks(at offsets: IndexSet) {
        let sorted = tracks
        for index in offsets {
            let track = sorted[index]
            CouplePlaylistStore.removeTrack(id: track.id)
        }
        reload()
        AudioManager.shared.reloadHomeMusic()
        playbackState.refreshFromStore()
    }

    private func removeAllSongs() {
        CouplePlaylistStore.clearAll()
        AudioManager.shared.stopHomeMusic()
        playbackState.refreshFromStore()
        dismiss()
    }
}
