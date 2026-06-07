import PhotosUI
import SwiftUI

struct OurSongSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playbackState = CoupleMusicPlaybackState.shared
    @StateObject private var importCoordinator = BackgroundMusicImportCoordinator()

    @State private var showPlaylistEditor = false
    @State private var repeatEnabled = CouplePlaylistStore.repeatEnabled
    @State private var shuffleEnabled = CouplePlaylistStore.shuffleEnabled

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
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

                HStack(spacing: 32) {
                    transportToggle(
                        title: "Repeat",
                        systemImage: repeatEnabled ? "repeat.1" : "repeat",
                        isOn: repeatEnabled
                    ) {
                        repeatEnabled.toggle()
                        CouplePlaylistStore.repeatEnabled = repeatEnabled
                        AudioManager.shared.reloadHomeMusic()
                    }

                    transportToggle(
                        title: "Shuffle",
                        systemImage: "shuffle",
                        isOn: shuffleEnabled
                    ) {
                        shuffleEnabled.toggle()
                        CouplePlaylistStore.shuffleEnabled = shuffleEnabled
                        AudioManager.shared.reloadHomeMusic()
                    }
                }

                HStack(spacing: 12) {
                    ctaButton(title: "Change") {
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
                playbackState.refreshFromStore()
                AudioManager.shared.playHomeMusic()
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
}
