import PhotosUI
import SwiftUI
import AVFoundation

struct GiftCurationView: View {

    @ObservedObject var viewModel: PreludeViewModel
    var onDone: () -> Void

    @State private var showPreview = false
    @State private var showAccountSetup = false
    @State private var showGiftSongSheet = false
    @State private var giftSong: PreludeGiftSong?
    @State private var isSendingInvite = false
    @State private var sendInviteError: String?
    @State private var generatedInviteCode: String?
    @State private var showCodeSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.captures.isEmpty {
                    emptyState
                } else {
                    captureList
                }

                giftSongCard
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                sendButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .padding(.top, 12)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .onAppear {
                giftSong = DataPersistenceManager.shared.loadPreludeGiftSong()
            }
            .navigationTitle("Your Gift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                }
                if !viewModel.giftCaptures.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Preview") { showPreview = true }
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            GiftPreviewSheet(captures: viewModel.giftCaptures)
        }
        .alert("Couldn't send invite", isPresented: Binding(
            get: { sendInviteError != nil },
            set: { if !$0 { sendInviteError = nil } }
        )) {
            Button("OK") { sendInviteError = nil }
        } message: {
            Text(sendInviteError ?? "")
        }
        .sheet(isPresented: $showCodeSheet) {
            if let code = generatedInviteCode {
                InviteCodeSheet(code: code, onDone: onDone)
            }
        }
        .fullScreenCover(isPresented: $showAccountSetup) {
            AccountSetupFlow(
                onComplete: { result in
                    DataPersistenceManager.shared.saveUserEmail(result.email)
                    if let img = result.avatarImage {
                        DataPersistenceManager.shared.saveUserAvatar(img)
                    }
                    showAccountSetup = false
                    Task { await sendInviteAndShowCode() }
                },
                onCancel: { showAccountSetup = false }
            )
        }
        .sheet(isPresented: $showGiftSongSheet) {
            PreludeGiftSongSheet(giftSong: $giftSong)
        }
    }

    // MARK: - Actions

    private func sendInviteAndShowCode() async {
        guard !isSendingInvite else { return }
        guard AuthService.shared.isSignedIn else {
            sendInviteError = "Please sign in to send an invite."
            return
        }
        isSendingInvite = true
        do {
            let giftCaptureIds = try await viewModel.syncGiftCapturesForInvite()
            let inviterName = DataPersistenceManager.shared.loadUserNickname() ?? "You"
            let response = try await InviteAPI.client.createInvite(
                inviterName: inviterName,
                giftCaptureIds: giftCaptureIds
            )
            DataPersistenceManager.shared.setPendingPartnerInvite(true)
            DataPersistenceManager.shared.savePendingInviteCode(response.code)
            viewModel.sendInvite()
            generatedInviteCode = response.code
            showCodeSheet = true
        } catch {
            sendInviteError = InviteErrorMapper.message(for: error)
        }
        isSendingInvite = false
    }

    private var captureList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Toggle what to include in your gift. Private captures stay private forever.")
                    .font(.system(size: 13))
                    .foregroundStyle(.black)
                    .padding(.top, 8)

                ForEach(viewModel.captures) { capture in
                    GiftCaptureRow(
                        capture: capture,
                        onToggle: { viewModel.toggleGiftInclusion(for: capture) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No captures yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
            Text("Go back and add notes, firsts, voice memos, or reasons.")
                .font(.system(size: 14))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var giftSongCard: some View {
        Button { showGiftSongSheet = true } label: {
            HStack(spacing: 12) {
                VinylRecordPlayerView(isPlaying: giftSong != nil, scale: 0.5)
                if let song = giftSong {
                    Text(song.displayName)
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .lineLimit(1)
                } else {
                    Text("Add a song")
                        .font(.system(size: 15))
                        .foregroundStyle(.black)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BabyTownTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var sendButton: some View {
        Button {
            if DataPersistenceManager.shared.loadUserEmail() != nil {
                Task { await sendInviteAndShowCode() }
            } else {
                showAccountSetup = true
            }
        } label: {
            Group {
                if isSendingInvite {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                        Text(viewModel.inviteSent ? "Get New Code" : "Get Invite Code")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(AnyShapeStyle(BabyTownTheme.accentGradient))
            )
        }
        .disabled(isSendingInvite)
        .buttonStyle(.plain)
    }
}

// MARK: - GiftCaptureRow

struct GiftCaptureRow: View {
    let capture: PreludeCapture
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: capture.typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(BabyTownTheme.cardBackground))

            VStack(alignment: .leading, spacing: 2) {
                Text(capture.typeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .textCase(.uppercase)
                Text(capture.displayTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: .init(get: { capture.isIncludedInGift }, set: { _ in onToggle() }))
                .tint(BabyTownTheme.accent)
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(capture.isIncludedInGift ? BabyTownTheme.accentSoft : BabyTownTheme.cardBackground)
        )
    }
}

// MARK: - GiftPreviewSheet

private struct GiftPreviewSheet: View {
    let captures: [PreludeCapture]
    @State private var currentIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BabyTownTheme.background.ignoresSafeArea()

                if captures.isEmpty {
                    Text("No captures included in gift yet.")
                        .foregroundStyle(BabyTownTheme.textSecondary)
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(captures.enumerated()), id: \.offset) { idx, capture in
                            GiftCardView(capture: capture, isCurrentPage: currentIndex == idx)
                                .tag(idx)
                                .padding(.horizontal, 28)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .navigationTitle("Preview (\(currentIndex + 1)/\(captures.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - GiftCardView (public — also used by GiftRevealView)

struct GiftCardView: View {
    let capture: PreludeCapture
    var isCurrentPage: Bool = true

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isPlaying ? "waveform" : capture.typeIcon)
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.accent)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)

            Text(capture.typeLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)
                .textCase(.uppercase)

            Text(capture.displayTitle)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(capture.createdAt, style: .date)
                .font(.system(size: 13))
                .foregroundStyle(.black)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
                .shadow(color: BabyTownTheme.cardShadow, radius: 8, y: 4)
        )
        .onAppear { if isCurrentPage { playVoiceMemoIfNeeded() } }
        .onDisappear { stopVoiceMemo() }
        .onChange(of: isCurrentPage) { _, isCurrent in
            if isCurrent { playVoiceMemoIfNeeded() } else { stopVoiceMemo() }
        }
    }

    private func playVoiceMemoIfNeeded() {
        guard capture.type == .voiceMemo, let fileId = capture.voiceMemoFileId else { return }
        let url = DataPersistenceManager.shared.preludeVoiceMemoFileURL(fileId: fileId)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("GiftCardView: failed to play voice memo: \(error)")
        }
    }

    private func stopVoiceMemo() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
}

// MARK: - PreludeGiftSongSheet

private struct PreludeGiftSongSheet: View {
    @Binding var giftSong: PreludeGiftSong?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var importCoordinator = PreludeGiftSongImportCoordinator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Gift Song")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(giftSong?.displayName ?? "No song added yet")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.top, 8)

                VinylRecordPlayerView(isPlaying: giftSong != nil, scale: 1.6)
                    .allowsHitTesting(false)

                HStack(spacing: 12) {
                    if giftSong != nil {
                        Button {
                            DataPersistenceManager.shared.deletePreludeGiftSong()
                            giftSong = nil
                        } label: {
                            Text("Remove")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.75)))
                        }
                        .buttonStyle(.plain)
                    }

                    PhotosPicker(selection: $importCoordinator.pickerItem, matching: .videos) {
                        Text("Import")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.75)))
                    }
                    .disabled(importCoordinator.isImporting)
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
            .onAppear {
                importCoordinator.onSongSaved = { song in giftSong = song }
            }
            .onChange(of: importCoordinator.pickerItem) { _, item in
                guard let item else { return }
                Task { await importCoordinator.importPickedVideo(item) }
            }
            .sheet(item: $importCoordinator.draftAwaitingTrim) { draft in
                CoupleSongTrimSheet(
                    draft: draft,
                    isSaving: importCoordinator.isTrimming,
                    onCancel: { importCoordinator.cancelTrim(draft: draft) },
                    onSave: { start, end in
                        Task { await importCoordinator.confirmTrim(draft: draft, startSeconds: start, endSeconds: end) }
                    }
                )
            }
            .sheet(item: $importCoordinator.trackAwaitingName) { draft in
                CoupleSongNameSheet(
                    title: "Name your song",
                    subtitle: "Give this song a name.",
                    initialName: draft.initialName,
                    onCancel: { importCoordinator.dismissNamingPrompt() },
                    onConfirm: { name in importCoordinator.finishNamingTrack(displayName: name) }
                )
            }
            .alert(
                "Import failed",
                isPresented: Binding(
                    get: { importCoordinator.statusMessage != nil },
                    set: { if !$0 { importCoordinator.statusMessage = nil } }
                )
            ) {
                Button("OK") { importCoordinator.statusMessage = nil }
            } message: {
                Text(importCoordinator.statusMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    GiftCurationView(
        viewModel: PreludeViewModel(),
        onDone: {}
    )
}
