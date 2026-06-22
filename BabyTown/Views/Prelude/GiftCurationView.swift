import SwiftUI
import AVFoundation

struct GiftCurationView: View {

    @ObservedObject var viewModel: PreludeViewModel
    var onDone: () -> Void

    @State private var showPreview = false
    @State private var showInviteSent = false
    @State private var showAccountSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.captures.isEmpty {
                    emptyState
                } else {
                    captureList
                }

                sendButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .padding(.top, 12)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
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
        .alert("Invite sent!", isPresented: $showInviteSent) {
            Button("Got it") { onDone() }
        } message: {
            Text("Your partner will receive your Prelude when they download the app. You can still add captures and update your gift until they accept.")
        }
        .fullScreenCover(isPresented: $showAccountSetup) {
            AccountSetupFlow(
                onComplete: { result in
                    DataPersistenceManager.shared.saveUserEmail(result.email)
                    if let img = result.avatarImage {
                        DataPersistenceManager.shared.saveUserAvatar(img)
                    }
                    showAccountSetup = false
                    viewModel.sendInvite()
                    showInviteSent = true
                },
                onCancel: { showAccountSetup = false }
            )
        }
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

    private var sendButton: some View {
        Button {
            if DataPersistenceManager.shared.loadUserEmail() != nil {
                viewModel.sendInvite()
                showInviteSent = true
            } else {
                showAccountSetup = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                Text(viewModel.inviteSent ? "Resend Invite" : "Send Invite")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(AnyShapeStyle(BabyTownTheme.accentGradient))
            )
        }
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

#Preview {
    GiftCurationView(
        viewModel: PreludeViewModel(),
        onDone: {}
    )
}
