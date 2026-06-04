import AVFoundation
import SwiftUI

/// Manage the couple playlist (Change): select now playing, remove tracks.
struct CouplePlaylistEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playbackState = CoupleMusicPlaybackState.shared

    @State private var tracks: [CouplePlaylistTrack] = []
    @State private var nowPlayingID: UUID?
    @State private var trackToRename: CouplePlaylistTrack?

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
            .navigationTitle("Couple Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: reload)
            .sheet(item: $trackToRename) { track in
                CoupleSongNameSheet(
                    title: "Rename song",
                    subtitle: "Update how this track appears in your playlist.",
                    initialName: track.displayName,
                    onCancel: { trackToRename = nil },
                    onConfirm: { name in
                        CouplePlaylistStore.updateDisplayName(id: track.id, displayName: name)
                        trackToRename = nil
                        reload()
                        playbackState.refreshFromStore()
                    }
                )
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
                trackToRename = track
            } label: {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename \(track.displayName)")
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
        dismiss()
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
}
