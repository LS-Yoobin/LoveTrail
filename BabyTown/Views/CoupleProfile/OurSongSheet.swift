import AVFoundation
import PhotosUI
import SwiftUI

struct OurSongSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playbackState = CoupleMusicPlaybackState.shared
    @StateObject private var importCoordinator = BackgroundMusicImportCoordinator()

    @State private var showPlaylistEditor = false
    @State private var repeatEnabled = CouplePlaylistStore.repeatEnabled
    @State private var shuffleEnabled = CouplePlaylistStore.shuffleEnabled
    @State private var tracks: [CouplePlaylistTrack] = []
    @State private var nowPlayingID: UUID?

    private var hasMultipleTracks: Bool { tracks.count > 1 }
    private var hasTracks: Bool { !tracks.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Our Song")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(playbackState.currentTrackTitle)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.top, 8)

                VinylRecordPlayerView(
                    isPlaying: playbackState.isPlaying,
                    scale: 1.6
                )
                .allowsHitTesting(false)

                playbackControls

                if hasMultipleTracks {
                    trackPickerList
                }

                HStack(spacing: 32) {
                    transportToggle(
                        title: "Repeat",
                        systemImage: repeatEnabled ? "repeat.1" : "repeat",
                        isOn: repeatEnabled
                    ) {
                        repeatEnabled.toggle()
                        CouplePlaylistStore.repeatEnabled = repeatEnabled
                        AudioManager.shared.reloadGardenMusic()
                    }

                    transportToggle(
                        title: "Shuffle",
                        systemImage: "shuffle",
                        isOn: shuffleEnabled
                    ) {
                        shuffleEnabled.toggle()
                        CouplePlaylistStore.shuffleEnabled = shuffleEnabled
                        AudioManager.shared.reloadGardenMusic()
                    }
                }

                HStack(spacing: 12) {
                    ctaButton(title: "Manage") {
                        showPlaylistEditor = true
                    }
                    importButton
                }

                if importCoordinator.isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Extracting audio…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPlaylistEditor) {
                CouplePlaylistEditorSheet()
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
            .onAppear {
                importCoordinator.clearStatus()
                repeatEnabled = CouplePlaylistStore.repeatEnabled
                shuffleEnabled = CouplePlaylistStore.shuffleEnabled
                reloadTracks()
                playbackState.refreshFromStore()
            }
            .onReceive(NotificationCenter.default.publisher(for: .backgroundMusicPreferenceChanged)) { _ in
                reloadTracks()
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
            .onChange(of: importCoordinator.pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await importCoordinator.importPickedVideo(newItem) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var playbackControls: some View {
        HStack(spacing: 28) {
            if hasMultipleTracks {
                Button {
                    AudioManager.shared.skipToPreviousTrack()
                    reloadTracks()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(hasTracks ? Color.primary : Color.secondary.opacity(0.4))
                .disabled(!hasTracks)
            }

            Button {
                AudioManager.shared.toggleGardenPlayback()
            } label: {
                Image(systemName: playbackState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52))
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasTracks ? BabyTownTheme.accent : Color.secondary.opacity(0.4))
            .disabled(!hasTracks)
            .accessibilityLabel(playbackState.isPlaying ? "Pause" : "Play")

            if hasMultipleTracks {
                Button {
                    AudioManager.shared.skipToNextTrack()
                    reloadTracks()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(hasTracks ? Color.primary : Color.secondary.opacity(0.4))
                .disabled(!hasTracks)
            }
        }
    }

    private var trackPickerList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(tracks) { track in
                    trackPickerRow(track)
                }
            }
        }
        .frame(maxHeight: 160)
    }

    private func trackPickerRow(_ track: CouplePlaylistTrack) -> some View {
        Button {
            selectTrack(track)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(nowPlayingID == track.id
                          ? BabyTownTheme.accent.opacity(0.12)
                          : Color.black.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { importCoordinator.statusMessage != nil },
            set: { if !$0 { importCoordinator.clearStatus() } }
        )
    }

    private var importButton: some View {
        PhotosPicker(selection: $importCoordinator.pickerItem, matching: .videos) {
            Text("Import")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.75))
                )
        }
        .disabled(importCoordinator.isImporting || !CouplePlaylistStore.canAddTrack)
        .opacity(CouplePlaylistStore.canAddTrack ? 1 : 0.5)
    }

    private func ctaButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.75))
                )
        }
        .buttonStyle(.plain)
    }

    private func transportToggle(
        title: String,
        systemImage: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(isOn ? BabyTownTheme.accent : Color.secondary)
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }

    private func reloadTracks() {
        tracks = CouplePlaylistStore.tracks
        nowPlayingID = CouplePlaylistStore.nowPlayingID ?? tracks.first?.id
    }

    private func selectTrack(_ track: CouplePlaylistTrack) {
        CouplePlaylistStore.setNowPlaying(id: track.id)
        nowPlayingID = track.id
        AudioManager.shared.reloadGardenMusic()
        playbackState.refreshFromStore()
    }

    private func formattedDuration(for track: CouplePlaylistTrack) -> String? {
        let url = CouplePlaylistStore.audioURL(for: track)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        let seconds = Int(player.duration.rounded())
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
