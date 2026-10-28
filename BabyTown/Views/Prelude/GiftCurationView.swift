import PhotosUI
import SwiftUI
import AVFoundation

/// Gift step one, opened from the home screen's invite banner. A month strip
/// picks which month's captures are listed; every tile has its own include
/// toggle and opens that capture's editor when tapped. Create opens the
/// page-flip preview of everything included, oldest first.
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
    /// Set when Add a song sends the user to Spotify; the song sheet opens
    /// when they come back so they can import their recording.
    @State private var awaitingSpotifyReturn = false
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var editorPresentation: CaptureEditorPresentation?
    @State private var selectedMonth = GiftMonth(date: Date())
    @State private var monthWindowStart = 0

    /// Side gutter shared by the header, the strip and the tiles (mock: 23pt).
    private static let gutter: CGFloat = 23
    private static let monthsVisible = 4

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Self.gutter)
                .padding(.top, 14)

            Text("Toggle what to include in your gift. Private captures stay private forever.")
                .font(.system(size: 11))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Self.gutter)
                .padding(.top, 30)

            if ownCaptures.isEmpty {
                emptyState
            } else {
                monthStrip
                    .padding(.top, 26)
                captureList
            }

            giftSongCard
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if let progress = viewModel.invitePrepProgress {
                Text("Uploading your gift… \(progress.completed)/\(progress.total)")
                    .font(.system(size: 13))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
            }

            sendButton
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .padding(.top, 12)
        }
        .background(BabyTownTheme.background.ignoresSafeArea())
        .onAppear {
            giftSong = DataPersistenceManager.shared.loadPreludeGiftSong()
            selectInitialMonth()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, awaitingSpotifyReturn else { return }
            awaitingSpotifyReturn = false
            showGiftSongSheet = true
        }
        .sheet(item: $editorPresentation) { presentation in
            CaptureEditorView(
                type: presentation.type,
                existing: presentation.existing,
                destination: .prelude(viewModel),
                onSave: { editorPresentation = nil },
                onCancel: { editorPresentation = nil }
            )
        }
        .fullScreenCover(isPresented: $showPreview) {
            GiftPageFlipPreview(
                captures: chronologicalGift,
                giftSong: giftSong,
                onDone: { showPreview = false }
            )
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

    // MARK: - Data

    /// The partner's retroactive captures are theirs, not part of this gift.
    private var ownCaptures: [PreludeCapture] {
        viewModel.captures.filter { !$0.isPartnerRetroactive }
    }

    /// Everything included, oldest first: the order the pages are read in.
    private var chronologicalGift: [PreludeCapture] {
        viewModel.giftCaptures.sorted {
            if $0.timelineDate != $1.timelineDate { return $0.timelineDate < $1.timelineDate }
            return $0.createdAt < $1.createdAt
        }
    }

    private var canCreate: Bool { !viewModel.giftCaptures.isEmpty }

    private var monthCaptures: [PreludeCapture] {
        ownCaptures
            .filter { GiftMonth(date: $0.timelineDate) == selectedMonth }
            .sorted { $0.timelineDate < $1.timelineDate }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Your Gift")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PreludePalette.promptBrown)

            HStack {
                Button(action: onDone) {
                    Text("Cancel")
                        .font(.system(size: 15))
                        .foregroundStyle(.black)
                        .frame(width: 94, height: 39)
                        .background(Capsule().fill(PreludePalette.generateFill))
                }
                .buttonStyle(.plain)

                Spacer()

                Button { showPreview = true } label: {
                    Text("Create")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 94, height: 39)
                        .background(
                            Capsule().fill(
                                canCreate
                                    ? AnyShapeStyle(BabyTownTheme.savePillFill)
                                    : AnyShapeStyle(Color.gray.opacity(0.35))
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
        }
    }

    // MARK: - Month strip

    /// Every month that has a capture, plus this month.
    private var availableMonths: [GiftMonth] {
        var months = Set(ownCaptures.map { GiftMonth(date: $0.timelineDate) })
        months.insert(GiftMonth(date: Date()))
        return months.sorted()
    }

    private var windowUpperBound: Int { max(0, availableMonths.count - Self.monthsVisible) }

    private var visibleMonths: [GiftMonth] {
        let all = availableMonths
        let start = min(max(0, monthWindowStart), windowUpperBound)
        return Array(all[start..<min(all.count, start + Self.monthsVisible)])
    }

    /// Opens on the month of the newest capture, with that month at the right
    /// end of the window.
    private func selectInitialMonth() {
        let newest = ownCaptures.map(\.timelineDate).max() ?? Date()
        selectedMonth = GiftMonth(date: newest)
        let position = availableMonths.firstIndex(of: selectedMonth) ?? 0
        monthWindowStart = min(max(0, position - Self.monthsVisible + 1), windowUpperBound)
    }

    private var monthStrip: some View {
        HStack(spacing: 4) {
            chevron("chevron.left", disabled: monthWindowStart <= 0) {
                monthWindowStart = max(0, monthWindowStart - 1)
            }

            HStack(spacing: 4) {
                ForEach(visibleMonths) { month in
                    monthPill(month)
                }
            }
            .frame(maxWidth: .infinity)

            chevron("chevron.right", disabled: monthWindowStart >= windowUpperBound) {
                monthWindowStart = min(windowUpperBound, monthWindowStart + 1)
            }
        }
        .padding(.horizontal, Self.gutter)
    }

    private func chevron(_ name: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { action() }
        } label: {
            Image(systemName: name)
                .font(.system(size: 18))
                .foregroundStyle(PreludePalette.monthPink)
                .opacity(disabled ? 0.25 : 1)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func monthPill(_ month: GiftMonth) -> some View {
        let isActive = month == selectedMonth
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedMonth = month }
        } label: {
            Text(month.shortName)
                .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : PreludePalette.monthPink)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(isActive ? PreludePalette.monthSelected : Color.clear))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(month.accessibilityName)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Tiles

    private var captureList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 22) {
                if monthCaptures.isEmpty {
                    Text("Nothing saved in \(selectedMonth.fullName) yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(PreludePalette.giftTileSubtitle)
                        .padding(.top, 40)
                } else {
                    ForEach(monthCaptures) { capture in
                        GiftToggleTile(
                            capture: capture,
                            onOpen: { editorPresentation = .edit(capture) },
                            onToggle: { viewModel.toggleGiftInclusion(for: capture) }
                        )
                    }
                }
            }
            .padding(.horizontal, Self.gutter)
            .padding(.top, 17)
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

    // MARK: - Song and invite (original Covela controls)

    /// Opens the Spotify app, or Spotify on the web when the app isn't installed.
    private func openSpotify() {
        awaitingSpotifyReturn = true
        openURL(GiftSpotify.appURL) { accepted in
            if !accepted {
                openURL(GiftSpotify.webURL) { opened in
                    if !opened {
                        awaitingSpotifyReturn = false
                        showGiftSongSheet = true
                    }
                }
            }
        }
    }

    /// No song yet: Add a song opens Spotify. With a song: opens the song
    /// sheet to change or remove it.
    private var giftSongCard: some View {
        Button {
            if giftSong == nil {
                openSpotify()
            } else {
                showGiftSongSheet = true
            }
        } label: {
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
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Uploading…")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
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
}

// MARK: - GiftMonth

/// A calendar month in a specific year, for the gift's month strip.
struct GiftMonth: Hashable, Comparable, Identifiable {
    let year: Int
    let month: Int  // 1...12

    init(date: Date, calendar: Calendar = .current) {
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
    }

    var id: Int { year * 100 + month }

    static func < (lhs: GiftMonth, rhs: GiftMonth) -> Bool { lhs.id < rhs.id }

    private static let shortNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    var shortName: String { Self.shortNames[month - 1] }

    var fullName: String { Calendar.current.monthSymbols[month - 1] }

    var accessibilityName: String { "\(fullName) \(year)" }
}

// MARK: - GiftToggleTile

/// One capture in the gift list: icon, uppercase type, a one-line preview and
/// the include toggle. Tapping anywhere but the toggle opens the editor.
struct GiftToggleTile: View {
    let capture: PreludeCapture
    var onOpen: () -> Void
    var onToggle: () -> Void

    private var label: String {
        switch capture.type {
        case .reason: return "Reason"
        case .voiceMemo: return "Voice Memo"
        case .first: return "First"
        case .note: return "Note"
        }
    }

    private var iconName: String {
        if capture.type == .note, let mood = capture.noteMood { return mood.iconName }
        return capture.typeIcon
    }

    private var subtitle: String {
        let text: String?
        switch capture.type {
        case .reason: text = capture.reasonText
        case .voiceMemo: text = "Voice memo"
        case .first: text = capture.firstLabel
        case .note: text = capture.noteText
        }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? label : trimmed
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 20)
                        Text(label.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    Text(subtitle)
                        .font(.system(size: 17))
                        .foregroundStyle(PreludePalette.giftTileSubtitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the editor")

            Toggle("Include \(label.lowercased()) in gift", isOn: Binding(
                get: { capture.isIncludedInGift },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(PreludePalette.recordRed)
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.vertical, 11)
        .frame(minHeight: 70)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PreludePalette.sheetBackground)
        )
    }
}

// MARK: - GiftCardView (public — also used by GiftRevealView)

struct GiftCardView: View {
    let capture: PreludeCapture
    var isCurrentPage: Bool = true

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false

    private var hasPhoto: Bool {
        capture.firstPhotoId != nil || capture.notePhotoId != nil || capture.remotePhotoPath != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            if hasPhoto {
                PreludeCapturePhotoView(capture: capture, height: 200, cornerRadius: 16)
            } else {
                Image(systemName: isPlaying ? "waveform" : capture.typeIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(BabyTownTheme.accent)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            }

            Text(capture.typeLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)
                .textCase(.uppercase)

            if capture.type != .voiceMemo || capture.voiceMemoFileId == nil {
                Text(capture.displayTitle)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .multilineTextAlignment(.center)
            }

            if capture.type == .voiceMemo, capture.voiceMemoFileId != nil {
                Button(action: toggleVoiceMemoPlayback) {
                    HStack(spacing: 8) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        Text(isPlaying ? "Playing…" : "Play voice memo")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accent.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }

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

    private func toggleVoiceMemoPlayback() {
        if isPlaying {
            stopVoiceMemo()
        } else {
            playVoiceMemoIfNeeded()
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

enum GiftSpotify {
    static let appURL = URL(string: "spotify:")!
    static let webURL = URL(string: "https://open.spotify.com")!
}

private struct PreludeGiftSongSheet: View {
    @Binding var giftSong: PreludeGiftSong?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
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

                Text("Screen-record your song in Spotify, then import the recording here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    openURL(GiftSpotify.appURL) { accepted in
                        if !accepted { openURL(GiftSpotify.webURL) }
                    }
                } label: {
                    Label("Open Spotify", systemImage: "arrow.up.forward.app")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.black)

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
