import SwiftUI

struct CaptureEditorView: View {

    let type: PreludeCapture.CaptureType
    let existing: PreludeCapture?
    @ObservedObject var viewModel: PreludeViewModel
    var onSave: () -> Void
    var onCancel: () -> Void

    @State private var noteText: String = ""
    @State private var firstLabel: String = ""
    @State private var customFirstLabel: String = ""
    @State private var reasonText: String = ""
    @State private var isGiftIncluded: Bool = true
    @State private var savedVoiceMemoFileId: String?
    @State private var promptIndex: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    giftToggle
                    editorContent
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: loadExisting)
    }

    private var navigationTitle: String {
        switch type {
        case .note: return "Note"
        case .first: return "A First"
        case .voiceMemo: return "Voice Memo"
        case .reason: return "Reason"
        }
    }

    private var giftToggle: some View {
        Toggle(isOn: $isGiftIncluded) {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(BabyTownTheme.accent)
                Text("Include in gift")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }
        }
        .tint(BabyTownTheme.accent)
    }

    @ViewBuilder
    private var editorContent: some View {
        switch type {
        case .note:
            noteEditor
        case .first:
            firstEditor
        case .voiceMemo:
            voiceMemoEditor
        case .reason:
            reasonEditor
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            promptChip(PreludeViewModel.notePrompts[promptIndex % PreludeViewModel.notePrompts.count])

            TextEditor(text: $noteText)
                .frame(minHeight: 160)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BabyTownTheme.cardBackground)
                )
                .font(.system(size: 16))

            Button("Different prompt") {
                promptIndex += 1
            }
            .font(.system(size: 13))
            .foregroundStyle(BabyTownTheme.accent)
        }
    }

    private var firstEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a first or write your own")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)

            ForEach(PreludeViewModel.firstOptions, id: \.self) { option in
                Button {
                    firstLabel = option
                    customFirstLabel = ""
                } label: {
                    HStack {
                        Text(option)
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if firstLabel == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BabyTownTheme.accent)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(firstLabel == option ? BabyTownTheme.accentSoft : BabyTownTheme.cardBackground)
                    )
                }
                .buttonStyle(.plain)
            }

            TextField("Or write your own first…", text: $customFirstLabel)
                .font(.system(size: 15))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BabyTownTheme.cardBackground)
                )
                .onChange(of: customFirstLabel) { _, val in
                    if !val.isEmpty { firstLabel = val }
                }
        }
    }

    private var voiceMemoEditor: some View {
        VStack(spacing: 16) {
            Text("Record up to 3 minutes. Raw, in the moment.")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VoiceMemoRecorderView(
                existingFileId: existing?.voiceMemoFileId,
                onSaved: { fileId in
                    savedVoiceMemoFileId = fileId
                }
            )
        }
    }

    private var reasonEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            promptChip(PreludeViewModel.reasonPrompt)

            TextField("One reason I'm falling for you…", text: $reasonText, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .font(.system(size: 16))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BabyTownTheme.cardBackground)
                )
        }
    }

    private func promptChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(BabyTownTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(BabyTownTheme.accentSoft)
            )
    }

    private var canSave: Bool {
        switch type {
        case .note: return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .first: return !firstLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .voiceMemo: return savedVoiceMemoFileId != nil || existing?.voiceMemoFileId != nil
        case .reason: return !reasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func loadExisting() {
        guard let c = existing else { return }
        isGiftIncluded = c.isIncludedInGift
        noteText = c.noteText ?? ""
        firstLabel = c.firstLabel ?? ""
        reasonText = c.reasonText ?? ""
        savedVoiceMemoFileId = c.voiceMemoFileId
    }

    private func save() {
        let resolvedFileId: String?
        switch type {
        case .voiceMemo:
            resolvedFileId = savedVoiceMemoFileId ?? existing?.voiceMemoFileId
        default:
            resolvedFileId = nil
        }

        let capture = PreludeCapture(
            id: existing?.id ?? UUID(),
            createdAt: existing?.createdAt ?? Date(),
            type: type,
            isIncludedInGift: isGiftIncluded,
            isPartnerRetroactive: existing?.isPartnerRetroactive ?? false,
            noteText: type == .note ? noteText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            firstLabel: type == .first ? firstLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            voiceMemoFileId: resolvedFileId,
            reasonText: type == .reason ? reasonText.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )

        if existing != nil {
            viewModel.updateCapture(capture)
        } else {
            viewModel.addCapture(capture)
        }
        onSave()
    }
}

#Preview {
    CaptureEditorView(
        type: .note,
        existing: nil,
        viewModel: PreludeViewModel(),
        onSave: {},
        onCancel: {}
    )
}
