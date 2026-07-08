import SwiftUI

struct PreludeHomeView: View {

    var onReturnToOnboarding: () -> Void = {}
    var onSwitchToOfficial: () -> Void = {}
    var onSimulatePartnerInvite: () -> Void = {}

    @StateObject private var viewModel = PreludeViewModel()
    @StateObject private var nightModeManager = NightModeManager()
    @State private var editorPresentation: CaptureEditorPresentation?
    @State private var firstDetailCapture: PreludeCapture?
    @State private var firstEditCapture: PreludeCapture?
    @State private var showGiftCuration = false
    @State private var captureToDelete: PreludeCapture?
    @State private var showSettings = false
    @State private var showInviteCode = false

    private var displayName: String {
        DataPersistenceManager.shared.loadCoupleProfile().displayName ?? "them"
    }

    private let bottomChromeHeight: CGFloat = 180

    var body: some View {
        ZStack {
            Group {
                if nightModeManager.isNightMode {
                    HomeBackgroundView(isNightMode: true)
                } else {
                    BabyTownTheme.background
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: nightModeManager.isNightMode)

            VStack(spacing: 0) {
                BabyTownHeader(
                    onSettingsTap: { showSettings = true },
                    isNightMode: nightModeManager.isNightMode
                )

                ZStack(alignment: .bottom) {
                    if viewModel.captures.isEmpty {
                        emptyState
                    } else {
                        captureList
                    }

                    bottomChrome
                }
            }
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
        .sheet(item: $firstDetailCapture) { capture in
            PreludeFirstDetailSheet(capture: capture) {
                firstEditCapture = capture
            }
        }
        .sheet(item: $firstEditCapture) { capture in
            PreludeFirstEditSheet(capture: capture, viewModel: viewModel) {
                firstEditCapture = nil
            }
        }
        .fullScreenCover(isPresented: $showGiftCuration) {
            GiftCurationView(viewModel: viewModel, onDone: { showGiftCuration = false })
        }
        .sheet(isPresented: $showInviteCode) {
            if let code = DataPersistenceManager.shared.loadPendingInviteCode() {
                InviteCodeSheet(code: code, onDone: { showInviteCode = false })
            }
        }
        .sheet(isPresented: $showSettings) {
            PreludeSettingsSheet(
                onReturnToOnboarding: onReturnToOnboarding,
                onSwitchToOfficial: onSwitchToOfficial,
                onSimulatePartnerInvite: onSimulatePartnerInvite
            )
        }
    }

    // MARK: - Bottom Chrome

    private var bottomChrome: some View {
        VStack(spacing: 10) {
            inviteBanner
                .padding(.horizontal, 20)

            quickAddBar
        }
        .padding(.bottom, 28)
    }

    // MARK: - Invite Banner

    private var inviteBanner: some View {
        Button {
            if viewModel.inviteSent, DataPersistenceManager.shared.loadPendingInviteCode() != nil {
                showInviteCode = true
            } else {
                showGiftCuration = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BabyTownTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.inviteSent {
                        Text("Waiting for them to accept…")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.inviteBannerText)
                    } else {
                        Text("Invite partner")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.inviteBannerText)
                        Text("Share your Prelude when you're ready")
                            .font(.system(size: 12))
                            .foregroundStyle(BabyTownTheme.inviteBannerSubtext)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BabyTownTheme.inviteBannerText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BabyTownTheme.inviteBannerFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(BabyTownTheme.inviteBannerBorder, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Capture List

    private var captureList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.captures) { capture in
                    CaptureRowCard(
                        capture: capture,
                        isNightMode: nightModeManager.isNightMode,
                        onDelete: { captureToDelete = capture }
                    )
                        .onTapGesture {
                            if capture.type == .first {
                                firstDetailCapture = capture
                            } else {
                                editorPresentation = .edit(capture)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation { viewModel.deleteCapture(capture) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, bottomChromeHeight)
        }
        .alert(
            "Delete capture?",
            isPresented: Binding(
                get: { captureToDelete != nil },
                set: { if !$0 { captureToDelete = nil } }
            ),
            presenting: captureToDelete
        ) { capture in
            Button("Delete", role: .destructive) {
                withAnimation { viewModel.deleteCapture(capture) }
                captureToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                captureToDelete = nil
            }
        } message: { _ in }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 80)

                Image(systemName: "heart.text.square")
                    .font(.system(size: 48))
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.4))
                Text("Start capturing your story")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(nightModeManager.isNightMode ? .white : BabyTownTheme.textPrimary)
                Text("Notes, firsts, voice memos, and reasons —\nall private until you choose to share.")
                    .font(.system(size: 14))
                    .foregroundStyle(nightModeManager.isNightMode ? .white.opacity(0.75) : .black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Spacer(minLength: bottomChromeHeight)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        HStack(spacing: 0) {
            ForEach(quickAddButtons, id: \.label) { btn in
                Button {
                    editorPresentation = .new(btn.type)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: btn.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                        Text(btn.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(
            Capsule()
                .fill(BabyTownTheme.accentGradient)
                .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 12, y: 4)
        )
        .padding(.horizontal, 24)
    }

    private struct QuickAddButton {
        let type: PreludeCapture.CaptureType
        let icon: String
        let label: String
    }

    private let quickAddButtons: [QuickAddButton] = [
        .init(type: .note, icon: "pencil.and.scribble", label: "Note"),
        .init(type: .first, icon: "star.fill", label: "First"),
        .init(type: .voiceMemo, icon: "mic.fill", label: "Voice"),
        .init(type: .reason, icon: "heart.fill", label: "Reason")
    ]
}

// MARK: - CaptureRowCard

private struct CaptureRowCard: View {
    let capture: PreludeCapture
    var isNightMode: Bool = false
    let onDelete: () -> Void

    private var secondaryTextColor: Color { .black }

    private var hasPhoto: Bool {
        capture.firstPhotoId != nil || capture.notePhotoId != nil || capture.remotePhotoPath != nil
    }

    private static let lightTrashTint = Color(red: 0.94, green: 0.58, blue: 0.58)

    private var headerDate: Date {
        capture.timelineDate
    }

    private var cardBackground: Color {
        if capture.type == .note, let mood = capture.noteMood {
            return mood.fieldBackgroundColor
        }
        return BabyTownTheme.cardBackground
    }

    private var leadingIconName: String {
        if capture.type == .note, let mood = capture.noteMood {
            return mood.iconName
        }
        return capture.typeIcon
    }

    private var leadingIconColor: Color {
        if capture.type == .note, let mood = capture.noteMood {
            return mood.tintColor
        }
        return BabyTownTheme.accent
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: leadingIconName)
                    .font(.system(size: capture.noteMood != nil && capture.type == .note ? 16 : 14, weight: .semibold))
                    .foregroundStyle(leadingIconColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(capture.noteMood != nil && capture.type == .note
                                  ? Color.white.opacity(0.72)
                                  : BabyTownTheme.cardBackground)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(capture.typeLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(capture.noteMood != nil && capture.type == .note
                                             ? leadingIconColor
                                             : BabyTownTheme.accent)
                            .textCase(.uppercase)

                        Text("·")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.textSecondary)

                        Text(headerDate, style: .date)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(secondaryTextColor)
                    }

                    if capture.type == .note, capture.noteMood != nil {
                        Text(capture.displayTitle)
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                            .lineLimit(2)
                    } else {
                        Text(capture.displayTitle)
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(Self.relativeFormatter.localizedString(for: capture.createdAt, relativeTo: context.date))
                        .font(.system(size: 12))
                        .foregroundStyle(secondaryTextColor)
                }
            }

            if hasPhoto {
                PreludeCapturePhotoView(capture: capture, height: 190, cornerRadius: 12)
            }

            HStack {
                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Self.lightTrashTint)
                        .padding(8)
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
    }
}

#Preview {
    PreludeHomeView()
}
