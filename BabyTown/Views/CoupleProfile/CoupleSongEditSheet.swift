import SwiftUI

/// Edit an existing playlist track: rename and optionally re-trim audio.
struct CoupleSongEditSheet: View {
    let track: CouplePlaylistTrack
    var onCancel: () -> Void
    var onSaved: () -> Void

    @State private var nameInput = ""
    @State private var startSeconds: TimeInterval = 0
    @State private var endSeconds: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isLoadingDuration = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didPauseHomeMusic = false
    @FocusState private var isNameFocused: Bool

    private var audioURL: URL {
        CouplePlaylistStore.audioURL(for: track)
    }

    private var trimmedName: String {
        nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
            && endSeconds - startSeconds >= BackgroundMusicTrimmer.minimumSelectionDuration
            && !isSaving
    }

    private var needsTrimExport: Bool {
        !BackgroundMusicTrimmer.isFullClipSelection(
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            duration: duration
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoadingDuration {
                    ProgressView("Loading audio…")
                } else {
                    editContent
                }
            }
            .navigationTitle("Edit song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { Task { await saveChanges() } }) {
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
                nameInput = track.displayName
                pauseHomeMusicIfNeeded()
            }
            .task {
                await loadDuration()
            }
            .onDisappear {
                resumeHomeMusicIfNeeded()
            }
            .alert(
                "Couldn't save",
                isPresented: errorPresented,
                actions: {
                    Button("OK") { errorMessage = nil }
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving || isLoadingDuration)
    }

    private var editContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                TextField(
                    "",
                    text: $nameInput,
                    prompt: Text(track.displayName).foregroundStyle(Color.secondary)
                )
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isNameFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trim audio")
                        .font(.subheadline.weight(.semibold))
                    Text("Adjust the start or end of this clip.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                AudioTrimControls(
                    audioURL: audioURL,
                    duration: duration,
                    startSeconds: $startSeconds,
                    endSeconds: $endSeconds
                )
                .padding(.horizontal)

                if isSaving {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Saving…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func loadDuration() async {
        isLoadingDuration = true
        defer { isLoadingDuration = false }

        do {
            let loaded = try await BackgroundMusicTrimmer.duration(of: audioURL)
            duration = loaded
            startSeconds = 0
            endSeconds = loaded
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func saveChanges() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            if trimmedName != track.displayName {
                CouplePlaylistStore.updateDisplayName(id: track.id, displayName: trimmedName)
            }

            if needsTrimExport {
                let trimmedURL = try await BackgroundMusicTrimmer.exportTrimmed(
                    sourceURL: audioURL,
                    startSeconds: startSeconds,
                    endSeconds: endSeconds
                )
                defer { try? FileManager.default.removeItem(at: trimmedURL) }
                try CouplePlaylistStore.replaceAudio(for: track.id, from: trimmedURL)
            }

            if CouplePlaylistStore.nowPlayingID == track.id, AudioManager.shared.gardenIsActive {
                AudioManager.shared.reloadGardenMusic()
            }
            CoupleMusicPlaybackState.shared.refreshFromStore()
            onSaved()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
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
