import SwiftUI

/// Post-import trim step before a track is saved to the couple playlist.
struct CoupleSongTrimSheet: View {
    let draft: AudioTrimDraft
    var isSaving: Bool
    var onCancel: () -> Void
    var onSave: (_ startSeconds: TimeInterval, _ endSeconds: TimeInterval) -> Void

    @State private var startSeconds: TimeInterval = 0
    @State private var endSeconds: TimeInterval = 0
    @State private var didPauseHomeMusic = false

    private var canSave: Bool {
        endSeconds - startSeconds >= BackgroundMusicTrimmer.minimumSelectionDuration && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Cut silence at the start or end, then preview your clip.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    AudioTrimControls(
                        audioURL: draft.sourceURL,
                        duration: draft.duration,
                        startSeconds: $startSeconds,
                        endSeconds: $endSeconds
                    )
                    .padding(.horizontal)

                    if isSaving {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Saving trim…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Trim your song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) {
                        SavePillLabel(
                            title: "SAVE",
                            isEnabled: canSave,
                            font: .subheadline.weight(.bold),
                            horizontalPadding: 16,
                            verticalPadding: 8
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                startSeconds = 0
                endSeconds = draft.duration
                pauseHomeMusicIfNeeded()
            }
            .onDisappear {
                resumeHomeMusicIfNeeded()
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        guard canSave else { return }
        onSave(startSeconds, endSeconds)
    }

    private func pauseHomeMusicIfNeeded() {
        guard AudioManager.shared.gardenIsActive else { return }
        guard !didPauseHomeMusic else { return }
        didPauseHomeMusic = CoupleMusicPlaybackState.shared.isPlaying
        if didPauseHomeMusic {
            AudioManager.shared.pauseGardenMusic()
        }
    }

    private func resumeHomeMusicIfNeeded() {
        guard AudioManager.shared.gardenIsActive else { return }
        guard didPauseHomeMusic else { return }
        didPauseHomeMusic = false
        AudioManager.shared.resumeGardenMusic()
    }
}
