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

    /// One gutter for everything that runs down the home screen: the month
    /// strip, the capture cards, the invite banner and the quick-add bar.
    private static let outerGutter: CGFloat = 24
    @State private var selectedMonthIndex: Int = Calendar.current.component(.month, from: Date()) - 1
    @State private var monthWindowStart: Int = max(0, min(8, Calendar.current.component(.month, from: Date()) - 3))
    @State private var monthYear: Int = Calendar.current.component(.year, from: Date())

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
                .padding(.horizontal, Self.outerGutter)

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

    // MARK: - Month Filter Helpers

    private var filteredCaptures: [PreludeCapture] {
        let cal = Calendar.current
        return viewModel.captures.filter {
            cal.component(.month, from: $0.timelineDate) - 1 == selectedMonthIndex
                && cal.component(.year, from: $0.timelineDate) == monthYear
        }
    }

    // MARK: - Capture List

    private var captureList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Month strip
                monthFilterBar
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                LazyVStack(spacing: 14) {
                    ForEach(filteredCaptures) { capture in
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
                .padding(.horizontal, Self.outerGutter)
                .padding(.bottom, bottomChromeHeight)
            }
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

    private static let monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let monthsVisible = 4

    // MARK: - Month window

    /// The strip starts at the month of the earliest saved capture in this
    /// year — there is nothing to look at before it. Falls back to the current
    /// month while nothing is saved.
    private var firstCaptureMonth: Int {
        let cal = Calendar.current
        let months = viewModel.captures
            .filter { cal.component(.year, from: $0.timelineDate) == monthYear }
            .map { cal.component(.month, from: $0.timelineDate) - 1 }
        return months.min() ?? (cal.component(.month, from: Date()) - 1)
    }

    /// The last month you can actually have saved anything in: this month in
    /// the current year, December in any year already past.
    private var lastSelectableMonth: Int {
        let cal = Calendar.current
        let thisYear = cal.component(.year, from: Date())
        if monthYear < thisYear { return 11 }
        if monthYear > thisYear { return firstCaptureMonth }
        return cal.component(.month, from: Date()) - 1
    }

    private func isFutureMonth(_ index: Int) -> Bool {
        index > lastSelectableMonth
    }

    /// Months the strip can scroll across: the first captured month through
    /// December. Future ones stay visible but greyed out.
    private var monthRange: ClosedRange<Int> {
        let lower = min(firstCaptureMonth, 11)
        return lower...11
    }

    private var windowStartLowerBound: Int { monthRange.lowerBound }

    private var windowStartUpperBound: Int {
        max(monthRange.lowerBound, monthRange.upperBound - Self.monthsVisible + 1)
    }

    /// Clamped so the window can never run past either end of the range, and
    /// shrinks when fewer than `monthsVisible` months are available.
    private var visibleMonths: [Int] {
        let start = min(max(monthWindowStart, windowStartLowerBound), windowStartUpperBound)
        let end = min(start + Self.monthsVisible - 1, monthRange.upperBound)
        return Array(start...end)
    }

    /// Captures load after the initial @State values are set, so pull the
    /// window and the selection back into range whenever they change.
    private func syncMonthWindow() {
        monthWindowStart = min(max(monthWindowStart, windowStartLowerBound), windowStartUpperBound)
        selectedMonthIndex = min(max(selectedMonthIndex, monthRange.lowerBound), lastSelectableMonth)
    }

    /// Sliding window with arrows, as in the notes-v4 prototype.
    private var monthFilterBar: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    monthWindowStart = max(windowStartLowerBound, monthWindowStart - 1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18))
                    .foregroundStyle(PreludePalette.monthPink)
                    .opacity(monthWindowStart <= windowStartLowerBound ? 0.25 : 1)
            }
            .buttonStyle(.plain)
            .disabled(monthWindowStart <= windowStartLowerBound)
            .padding(.horizontal, 4)

            HStack(spacing: 4) {
                ForEach(visibleMonths, id: \.self) { index in
                    monthPill(index: index)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    monthWindowStart = min(windowStartUpperBound, monthWindowStart + 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18))
                    .foregroundStyle(PreludePalette.monthPink)
                    .opacity(monthWindowStart >= windowStartUpperBound ? 0.25 : 1)
            }
            .buttonStyle(.plain)
            .disabled(monthWindowStart >= windowStartUpperBound)
            .padding(.horizontal, 4)
        }
        // Same outer gutter as the quick-add bar so the strip, the cards and
        // the bar all line up down the screen.
        .padding(.horizontal, Self.outerGutter)
        .onAppear { syncMonthWindow() }
        .onChange(of: viewModel.captures.count) { _, _ in syncMonthWindow() }
        .onChange(of: monthYear) { _, _ in syncMonthWindow() }
    }

    private func monthPill(index: Int) -> some View {
        let isActive = selectedMonthIndex == index
        let isFuture = isFutureMonth(index)
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedMonthIndex = index }
        } label: {
            Text(Self.monthAbbreviations[index])
                .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? .white : PreludePalette.monthPink)
                .opacity(isFuture ? 0.3 : 1)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? PreludePalette.monthSelected : Color.clear)
                )
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
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
        .padding(.horizontal, Self.outerGutter)
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

    private var headerDate: Date { capture.timelineDate }

    // Card background: mood tint for notes, theme card color otherwise
    private var cardBackground: Color {
        if capture.type == .note, let mood = capture.noteMood {
            return mood.fieldBackgroundColor
        }
        return BabyTownTheme.cardBackground
    }

    // Leading icon: mood symbol for notes, type icon otherwise
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

    /// Every element in the card hangs off this one gutter.
    private static let gutter: CGFloat = 14

    private var hasPhoto: Bool {
        capture.firstPhotoId != nil || capture.notePhotoId != nil || capture.remotePhotoPath != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row
            HStack(alignment: .center, spacing: 10) {
                // Mood / type icon
                Image(systemName: leadingIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(leadingIconColor)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.7))
                    )

                // Type label
                Text(capture.typeLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                Spacer()

                // Date
                Text(headerDate, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .padding(.horizontal, Self.gutter)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Text preview
            if !capture.displayTitle.isEmpty {
                Text(capture.displayTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(2)
                    .padding(.horizontal, Self.gutter)
                    .padding(.bottom, hasPhoto ? 10 : 12)
            }

            // Photo — same gutters as the note text, equal on both sides
            if hasPhoto {
                PreludeCapturePhotoView(capture: capture, height: 170, cornerRadius: 14)
                    .padding(.horizontal, Self.gutter)
                    .padding(.bottom, 12)
            }

            // Trash, bottom-trailing
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(.black)
                        // Cancels the SF Symbol's right side bearing so the
                        // glyph's ink, not its box, lines up with the photo.
                        .padding(.trailing, -1.5)
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Self.gutter)
            .padding(.bottom, 14)
        }
        // Without this the VStack shrinks to its widest child, so a card with
        // no photo and a short line of text renders narrower than the rest.
        // Every card is the width of the column, which is the quick-add bar's.
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    PreludeHomeView()
}
