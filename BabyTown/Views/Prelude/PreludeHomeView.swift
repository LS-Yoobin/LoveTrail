import SwiftUI

struct PreludeHomeView: View {

    var onReturnToOnboarding: () -> Void = {}
    var onSwitchToOfficial: () -> Void = {}

    @StateObject private var viewModel = PreludeViewModel()
    @State private var editorPresentation: CaptureEditorPresentation?
    @State private var showGiftCuration = false
    @State private var captureToDelete: PreludeCapture?
    @State private var showSettings = false

    private var displayName: String {
        DataPersistenceManager.shared.loadCoupleProfile().displayName ?? "them"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BabyTownTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                inviteBanner
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                if viewModel.captures.isEmpty {
                    emptyState
                } else {
                    captureList
                }
            }

            quickAddBar
                .padding(.bottom, 28)
        }
        .sheet(item: $editorPresentation) { presentation in
            CaptureEditorView(
                type: presentation.type,
                existing: presentation.existing,
                viewModel: viewModel,
                onSave: { editorPresentation = nil },
                onCancel: { editorPresentation = nil }
            )
        }
        .fullScreenCover(isPresented: $showGiftCuration) {
            GiftCurationView(viewModel: viewModel, onDone: { showGiftCuration = false })
        }
        .overlay(alignment: .topLeading) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.top, 4)
        }
        .sheet(isPresented: $showSettings) {
            PreludeSettingsSheet(
                onReturnToOnboarding: onReturnToOnboarding,
                onSwitchToOfficial: onSwitchToOfficial
            )
        }
    }

    // MARK: - Invite Banner

    private var inviteBanner: some View {
        Button {
            showGiftCuration = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BabyTownTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.inviteSent {
                        Text("Waiting for them to accept…")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                    } else {
                        Text("Invite \(displayName)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                        Text("Share your Prelude when you're ready")
                            .font(.system(size: 12))
                            .foregroundStyle(.black)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BabyTownTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Capture List

    private var captureList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.captures) { capture in
                    CaptureRowCard(capture: capture, onDelete: { captureToDelete = capture })
                        .onTapGesture {
                            editorPresentation = .edit(capture)
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
            .padding(.bottom, 120)
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
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.4))
            Text("Start capturing your story")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)
            Text("Notes, firsts, voice memos, and reasons —\nall private until you choose to share.")
                .font(.system(size: 14))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer()
        }
        .padding(.horizontal, 32)
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
    let onDelete: () -> Void

    private static let lightTrashTint = Color(red: 0.94, green: 0.58, blue: 0.58)

    private var headerDate: Date {
        capture.type == .first ? (capture.firstDate ?? capture.createdAt) : capture.createdAt
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
                            .foregroundStyle(.black)
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
                        .foregroundStyle(.black)
                }
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
