import SwiftUI

struct PreludeHomeView: View {

    @StateObject private var viewModel = PreludeViewModel()
    @State private var showCaptureEditor = false
    @State private var editorType: PreludeCapture.CaptureType = .note
    @State private var editingCapture: PreludeCapture?
    @State private var showGiftCuration = false
    @State private var captureToDelete: PreludeCapture?

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
        .sheet(isPresented: $showCaptureEditor, onDismiss: { editingCapture = nil }) {
            CaptureEditorView(
                type: editorType,
                existing: editingCapture,
                viewModel: viewModel,
                onSave: { showCaptureEditor = false },
                onCancel: { showCaptureEditor = false }
            )
        }
        .fullScreenCover(isPresented: $showGiftCuration) {
            GiftCurationView(viewModel: viewModel, onDone: { showGiftCuration = false })
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
                            .foregroundStyle(BabyTownTheme.textSecondary)
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
                            editingCapture = capture
                            editorType = capture.type
                            showCaptureEditor = true
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
                .foregroundStyle(BabyTownTheme.textSecondary)
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
                    editorType = btn.type
                    editingCapture = nil
                    showCaptureEditor = true
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: capture.typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.accent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(BabyTownTheme.cardBackground)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(capture.typeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .textCase(.uppercase)

                Text(capture.displayTitle)
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(2)

                Text(capture.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .padding(8)
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
        )
    }
}

#Preview {
    PreludeHomeView()
}
