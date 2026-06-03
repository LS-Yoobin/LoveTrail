import SwiftUI

struct BackgroundMusicSettingsSection: View {

    @State private var linkDraft = ""
    @State private var statusMessage: String?
    @State private var isSaving = false

    private var savedLink: BackgroundMusicLink? {
        BackgroundMusicPreferences.parsedLink
    }

    var body: some View {
        Section {
            TextField(
                "Paste Spotify, Apple Music, or YouTube link",
                text: $linkDraft,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)

            if let savedLink {
                HStack {
                    Text("Current")
                    Spacer()
                    Text(savedLink.kind.displayName)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("Current")
                    Spacer()
                    Text("Default song")
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                saveLink()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.85)
                    }
                    Text("Save background song")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .disabled(isSaving || linkDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if savedLink != nil {
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
            Text("YouTube and direct audio links play automatically. Spotify uses Spotify's in-app player — playback starts after you save, but iOS may still block autoplay until you've interacted with the app once.")
        }
        .onAppear {
            linkDraft = BackgroundMusicPreferences.customLinkURL?.absoluteString ?? ""
        }
    }

    private func saveLink() {
        let trimmed = linkDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard BackgroundMusicLinkParser.isValidMusicURL(trimmed) else {
            statusMessage = "Paste a valid Spotify, Apple Music, or YouTube link."
            return
        }

        isSaving = true
        statusMessage = nil
        BackgroundMusicPreferences.customLinkURL = URL(string: trimmed)

        if let kind = BackgroundMusicPreferences.parsedLink?.kind.displayName {
            statusMessage = "Saved — starting \(kind) playback."
        }
        isSaving = false
    }

    private func useDefaultSong() {
        linkDraft = ""
        statusMessage = nil
        BackgroundMusicPreferences.clearCustomLink()
        statusMessage = "Using the default Baby Town song."
    }
}
