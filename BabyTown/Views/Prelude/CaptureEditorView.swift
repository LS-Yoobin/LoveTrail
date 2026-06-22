import SwiftUI
import PhotosUI

/// Sheet payload so capture type and edit context are passed atomically (avoids
/// `isPresented` reading stale `editorType` on first presentation).
struct CaptureEditorPresentation: Identifiable {
    let id: UUID
    let type: PreludeCapture.CaptureType
    let existing: PreludeCapture?

    static func new(_ type: PreludeCapture.CaptureType) -> CaptureEditorPresentation {
        CaptureEditorPresentation(id: UUID(), type: type, existing: nil)
    }

    static func edit(_ capture: PreludeCapture) -> CaptureEditorPresentation {
        CaptureEditorPresentation(id: capture.id, type: capture.type, existing: capture)
    }
}

struct CaptureEditorView: View {

    private enum FirstEditorStep {
        case details
        case photo
    }

    let type: PreludeCapture.CaptureType
    let existing: PreludeCapture?
    @ObservedObject var viewModel: PreludeViewModel
    var onSave: () -> Void
    var onCancel: () -> Void

    @State private var noteText: String = ""
    @State private var noteMood: ProfileNoteMood?
    @State private var firstLabel: String = ""
    @State private var customFirstLabel: String = ""
    @State private var reasonText: String = ""
    @State private var isGiftIncluded: Bool = true
    @State private var savedVoiceMemoFileId: String?
    @State private var promptIndex: Int = 0
    @State private var showNotePrompt: Bool = false
    @State private var voicePromptIndex: Int = 0
    @State private var showVoicePrompt: Bool = false
    @State private var firstDate: Date = Date()
    @State private var isDatePickerExpanded: Bool = false
    @State private var firstEditorStep: FirstEditorStep = .details
    @State private var firstPhotoImage: UIImage?
    @State private var firstPhotoId: UUID?
    @State private var showFirstPhotoPicker = false
    @State private var firstOptionsPage: Int = 0
    @FocusState private var isEditorFocused: Bool

    private var displayedFirstOptions: [String] {
        let pages = PreludeViewModel.firstOptionPages
        guard !pages.isEmpty else { return [] }
        return pages[firstOptionsPage % pages.count]
    }

    var body: some View {
        NavigationStack {
            Group {
                if type == .first {
                    switch firstEditorStep {
                    case .details:
                        firstEditor
                    case .photo:
                        firstPhotoEditor
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            if existing != nil {
                                giftToggle
                            }
                            editorContent
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if type == .first, firstEditorStep == .photo {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                firstEditorStep = .details
                            }
                        }
                    } else {
                        Button("Cancel", action: onCancel)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if type == .first, firstEditorStep == .details {
                        Button(action: advanceFirstToPhotoStep) {
                            SavePillLabel(title: "Next", isEnabled: canAdvanceFirstStep)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdvanceFirstStep)
                    } else {
                        Button(action: save) {
                            SavePillLabel(title: "Save", isEnabled: canSave)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                }
            }
        }
        .sheet(isPresented: $showFirstPhotoPicker) {
            PhotoPickerView(
                selectedImages: .constant([]),
                selectionLimit: 1,
                onFinish: { results in
                    showFirstPhotoPicker = false
                    guard let result = results.first else { return }
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        guard let image = object as? UIImage else { return }
                        DispatchQueue.main.async {
                            firstPhotoImage = image
                        }
                    }
                }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            loadExisting()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isEditorFocused = true
            }
        }
    }

    private var navigationTitle: String {
        switch type {
        case .note: return "Note"
        case .first: return "Our First"
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
            EmptyView()
        case .voiceMemo:
            voiceMemoEditor
        case .reason:
            reasonEditor
        }
    }

    // MARK: - First Editor

    private var firstEditor: some View {
        VStack(spacing: 0) {
            // Fixed zone
            VStack(alignment: .leading, spacing: 12) {
                if existing != nil {
                    giftToggle
                        .padding(.bottom, 4)
                }

                Text("📅 WHEN WAS THIS?")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.top, 4)

                dateBanner

                if isDatePickerExpanded {
                    DatePicker("", selection: $firstDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(BabyTownTheme.accent)
                        .colorScheme(.light)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onChange(of: firstDate) { _, _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDatePickerExpanded = false
                            }
                        }
                }

                firstSectionDivider

                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                    TextField(
                        "",
                        text: $customFirstLabel,
                        prompt: Text("Write your own first…").foregroundStyle(Color.black.opacity(0.5))
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
                    .focused($isEditorFocused)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isEditorFocused ? BabyTownTheme.savePillFill : Color.black,
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isEditorFocused)
                .onChange(of: customFirstLabel) { _, val in
                    if !val.isEmpty { firstLabel = val }
                }

                Text("or pick one")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .animation(.easeInOut(duration: 0.2), value: isDatePickerExpanded)

            // Scrollable zone
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(displayedFirstOptions, id: \.self) { option in
                        Button {
                            isEditorFocused = false
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

                    generateMoreFirstOptionsButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxHeight: .infinity)
        }
    }

    private var dateBanner: some View {
        Button {
            isEditorFocused = false
            withAnimation(.easeInOut(duration: 0.2)) {
                isDatePickerExpanded.toggle()
            }
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(firstDate, format: .dateTime.month(.wide).day())
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                    Text(firstDate, format: .dateTime.year())
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.65))
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("📅")
                        .font(.system(size: 20))
                    Text("tap to change")
                        .font(.system(size: 11))
                        .foregroundStyle(.black.opacity(0.65))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 253 / 255, green: 240 / 255, blue: 234 / 255),
                                Color(red: 252 / 255, green: 232 / 255, blue: 222 / 255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var generateMoreFirstOptionsButton: some View {
        Button {
            isEditorFocused = false
            let pageCount = PreludeViewModel.firstOptionPages.count
            guard pageCount > 1 else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                firstOptionsPage = (firstOptionsPage + 1) % pageCount
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                Text("Generate More")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BabyTownTheme.accent)
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BabyTownTheme.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(BabyTownTheme.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var firstSectionDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(BabyTownTheme.accent.opacity(0.3))
                .frame(height: 1)
            Text("What was the first?")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.accent)
                .lineLimit(1)
                .fixedSize()
            Rectangle()
                .fill(BabyTownTheme.accent.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - First Photo Step

    private var firstPhotoEditor: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if existing != nil {
                    giftToggle
                }

                Text("📅 WHEN WAS THIS?")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)

                firstDateSummaryBanner

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your first")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.55))
                        .textCase(.uppercase)

                    Text(firstLabel)
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 14))
                            .foregroundStyle(BabyTownTheme.accent)
                        Text("Add a photo?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                        Spacer()
                        Text(firstPhotoImage == nil ? "Optional" : "1")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.accent)
                    }

                    firstPhotoPickerArea
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var firstDateSummaryBanner: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(firstDate, format: .dateTime.month(.wide).day())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                Text(firstDate, format: .dateTime.year())
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.65))
            }
            Spacer()
            Text("📅")
                .font(.system(size: 20))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 253 / 255, green: 240 / 255, blue: 234 / 255),
                            Color(red: 252 / 255, green: 232 / 255, blue: 222 / 255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var firstPhotoPickerArea: some View {
        Group {
            if let firstPhotoImage {
                ZStack(alignment: .topTrailing) {
                    Button {
                        showFirstPhotoPicker = true
                    } label: {
                        Image(uiImage: firstPhotoImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        self.firstPhotoImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.5))
                                    .frame(width: 24, height: 24)
                            )
                    }
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                    .accessibilityLabel("Remove photo")
                }
            } else {
                Button {
                    showFirstPhotoPicker = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 32, weight: .thin))
                        Text("Tap to add a photo")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(BabyTownTheme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                BabyTownTheme.accent,
                                style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(BabyTownTheme.accent.opacity(0.08))
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func advanceFirstToPhotoStep() {
        isEditorFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            firstEditorStep = .photo
        }
    }

    // MARK: - Other Editors

    private var currentNotePrompt: String {
        PreludeViewModel.notePrompts[promptIndex % PreludeViewModel.notePrompts.count]
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileNoteMoodPickerBar(selectedMood: $noteMood)

            Button(showNotePrompt ? "Different prompt" : "Generate Prompt") {
                if showNotePrompt {
                    promptIndex += 1
                } else {
                    showNotePrompt = true
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(BabyTownTheme.accent)

            if showNotePrompt {
                promptChip(currentNotePrompt)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $noteText)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.black)
                    .frame(minHeight: 160)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(noteMood?.fieldBackgroundColor ?? BabyTownTheme.cardBackground)
                    )
                    .animation(.easeInOut(duration: 0.2), value: noteMood)
                    .font(.system(size: 16))
                    .focused($isEditorFocused)
                if noteText.isEmpty, showNotePrompt {
                    Text(currentNotePrompt)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(uiColor: .darkGray).opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showNotePrompt)
    }

    private var currentVoicePrompt: String {
        PreludeViewModel.voicePrompts[voicePromptIndex % PreludeViewModel.voicePrompts.count]
    }

    private var voiceMemoEditor: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Say what you can't write")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Your voice carries what text sometimes can't — the pause, the laugh, the way you mean it. Speak freely. They'll hear you, not just your words.")
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(showVoicePrompt ? "Different idea" : "Need an idea?") {
                if showVoicePrompt {
                    voicePromptIndex += 1
                } else {
                    showVoicePrompt = true
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(BabyTownTheme.accent)

            if showVoicePrompt {
                promptChip(currentVoicePrompt)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VoiceMemoRecorderView(
                existingFileId: existing?.voiceMemoFileId,
                onSaved: { fileId in
                    savedVoiceMemoFileId = fileId
                }
            )
        }
        .animation(.easeInOut(duration: 0.2), value: showVoicePrompt)
    }

    private var reasonEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            promptChip(PreludeViewModel.reasonPrompt)

            TextField(
                "", text: $reasonText,
                prompt: Text("One reason I'm falling for you…").foregroundStyle(Color(uiColor: .darkGray).opacity(0.55)),
                axis: .vertical
            )
            .foregroundStyle(.black)
            .lineLimit(3, reservesSpace: true)
            .font(.system(size: 16))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BabyTownTheme.cardBackground)
            )
            .focused($isEditorFocused)
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

    // MARK: - Save / Load

    private var canAdvanceFirstStep: Bool {
        !firstLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        switch type {
        case .note: return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .first: return firstEditorStep == .photo
        case .voiceMemo: return savedVoiceMemoFileId != nil || existing?.voiceMemoFileId != nil
        case .reason: return !reasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func loadExisting() {
        guard let c = existing else { return }
        isGiftIncluded = c.isIncludedInGift
        noteText = c.noteText ?? ""
        noteMood = c.noteMood
        firstLabel = c.firstLabel ?? ""
        reasonText = c.reasonText ?? ""
        savedVoiceMemoFileId = c.voiceMemoFileId
        firstDate = c.firstDate ?? Date()
        firstPhotoId = c.firstPhotoId
        if let photoId = c.firstPhotoId {
            firstPhotoImage = DataPersistenceManager.shared.loadPreludePhoto(photoId: photoId)
        }
    }

    private func resolvedFirstPhotoId() -> UUID? {
        if firstPhotoImage != nil {
            return firstPhotoId ?? existing?.firstPhotoId ?? UUID()
        }
        if let existingPhotoId = existing?.firstPhotoId {
            DataPersistenceManager.shared.deletePreludePhoto(photoId: existingPhotoId)
        }
        return nil
    }

    private func save() {
        let resolvedFileId: String?
        switch type {
        case .voiceMemo:
            resolvedFileId = savedVoiceMemoFileId ?? existing?.voiceMemoFileId
        default:
            resolvedFileId = nil
        }

        var savedFirstPhotoId: UUID?
        if type == .first {
            savedFirstPhotoId = resolvedFirstPhotoId()
            if let photoId = savedFirstPhotoId, let image = firstPhotoImage {
                DataPersistenceManager.shared.savePreludePhoto(image, photoId: photoId)
            }
        }

        let capture = PreludeCapture(
            id: existing?.id ?? UUID(),
            createdAt: existing?.createdAt ?? Date(),
            type: type,
            isIncludedInGift: isGiftIncluded,
            isPartnerRetroactive: existing?.isPartnerRetroactive ?? false,
            noteText: type == .note ? noteText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            noteMood: type == .note ? noteMood : nil,
            firstLabel: type == .first ? firstLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            firstPhotoId: type == .first ? savedFirstPhotoId : nil,
            voiceMemoFileId: resolvedFileId,
            reasonText: type == .reason ? reasonText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            firstDate: type == .first ? firstDate : nil
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
        type: .first,
        existing: nil,
        viewModel: PreludeViewModel(),
        onSave: {},
        onCancel: {}
    )
}
