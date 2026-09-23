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

struct LetterBlockEditorPresentation: Identifiable {
    let id: UUID
    let type: LetterBlockType

    static func new(_ type: LetterBlockType) -> LetterBlockEditorPresentation {
        LetterBlockEditorPresentation(id: UUID(), type: type)
    }
}

enum CaptureEditorDestination {
    case prelude(PreludeViewModel)
    case letter(onSave: (LetterBlock) -> Void)

    var isLetterMode: Bool {
        if case .letter = self { return true }
        return false
    }
}

struct CaptureEditorView: View {

    let type: PreludeCapture.CaptureType
    let existing: PreludeCapture?
    let destination: CaptureEditorDestination
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
    @State private var calendarMonth: Int = Calendar.current.component(.month, from: Date()) - 1
    @State private var calendarYear: Int = Calendar.current.component(.year, from: Date())
    @State private var firstPhotoImage: UIImage?
    @State private var firstPhotoId: UUID?
    @State private var showFirstPhotoPicker = false
    @State private var notePhotoImage: UIImage?
    @State private var notePhotoId: UUID?
    @State private var showNotePhotoPicker = false
    @State private var firstOptionsPage: Int = 0
    @FocusState private var isEditorFocused: Bool

    /// The prototype shows three options per page.
    private var displayedFirstOptions: [String] {
        let pages = PreludeViewModel.firstOptionPages
        guard !pages.isEmpty else { return [] }
        return Array(pages[firstOptionsPage % pages.count].prefix(3))
    }

    private var showsGiftToggle: Bool {
        !destination.isLetterMode && existing != nil
    }

    private var voiceMemoStorage: VoiceMemoStorage {
        destination.isLetterMode ? .letter : .prelude
    }

    private var saveButtonTitle: String {
        destination.isLetterMode ? "Add" : "Save"
    }

    private var notePrompts: [String] {
        PreludeViewModel.notePrompts
    }

    private var voicePrompts: [String] {
        destination.isLetterMode ? LetterPrompts.voicePrompts : PreludeViewModel.voicePrompts
    }

    private var reasonPrompt: String {
        PreludeViewModel.reasonPrompt
    }

    var body: some View {
        NavigationStack {
            Group {
                if type == .first {
                    firstEditor
                } else if type == .voiceMemo {
                    voiceMemoEditor
                } else if type == .reason {
                    reasonEditor
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            if showsGiftToggle {
                                giftToggle
                            }
                            editorContent
                        }
                        .padding(.horizontal, type == .note ? 18 : 24)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(
                editorBackground
                    .ignoresSafeArea()
            )
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        SavePillLabel(title: saveButtonTitle, isEnabled: canSave)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
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
        .sheet(isPresented: $showNotePhotoPicker) {
            PhotoPickerView(
                selectedImages: .constant([]),
                selectionLimit: 1,
                onFinish: { results in
                    showNotePhotoPicker = false
                    guard let result = results.first else { return }
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        guard let image = object as? UIImage else { return }
                        DispatchQueue.main.async {
                            notePhotoImage = image
                        }
                    }
                }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            loadExisting()
            guard type != .first else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isEditorFocused = true
            }
        }
    }

    /// Note and First use the prototype's paper tones; the other editors keep the app default.
    private var editorBackground: Color {
        switch type {
        case .note: return PreludePalette.noteBackground
        case .first, .voiceMemo, .reason: return PreludePalette.sheetBackground
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
        case .voiceMemo, .reason:
            EmptyView()   // both are full-sheet editors, routed in `body`
        }
    }

    // MARK: - First Editor

    private var firstEditor: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                if showsGiftToggle {
                    giftToggle
                        .padding(.bottom, 20)
                }

                Text("What was the first?")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PreludePalette.sectionLabel)
                    .padding(.bottom, 17)

                ownFirstField
                    .padding(.bottom, 18)

                Text("or pick one")
                    .font(.system(size: 11))
                    .foregroundStyle(PreludePalette.orPickInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 23)

                ForEach(displayedFirstOptions, id: \.self) { option in
                    firstOptionCard(option)
                        .padding(.bottom, 21)
                }

                generateMoreFirstOptionsButton
                    .padding(.bottom, 32)

                Text("When was this?")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PreludePalette.sectionLabel)
                    .padding(.bottom, 17)

                dateBanner
                    .padding(.bottom, isDatePickerExpanded ? 25 : 37)

                // In the normal layout flow: opening the calendar pushes the
                // photo section down instead of covering it.
                if isDatePickerExpanded {
                    PreludeInlineCalendar(
                        month: $calendarMonth,
                        year: $calendarYear,
                        selection: $firstDate
                    )
                    .padding(.bottom, 37)
                    .transition(.opacity)
                }

                HStack(spacing: 5) {
                    Text("Add a photo?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PreludePalette.sectionLabel)
                    Text("— optional")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(PreludePalette.optionalItalic)
                }
                .padding(.bottom, 17)

                PolaroidPhotoWell(
                    image: firstPhotoImage,
                    onTap: { showFirstPhotoPicker = true },
                    onRemove: { firstPhotoImage = nil }
                )
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 27)
            .padding(.top, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.easeInOut(duration: 0.2), value: isDatePickerExpanded)
    }

    /// Dashed "write your own" field. Once it holds text it fills in and gets pinned.
    private var ownFirstField: some View {
        let isFilled = !customFirstLabel.trimmingCharacters(in: .whitespaces).isEmpty
        return ZStack(alignment: .topTrailing) {
            HStack(spacing: 11) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black)
                TextField(
                    "",
                    text: $customFirstLabel,
                    prompt: Text("Write your own first…")
                        .foregroundStyle(Color(red: 0.60, green: 0.60, blue: 0.60))
                        .italic()
                )
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 0.17, green: 0.15, blue: 0.14))
                .focused($isEditorFocused)
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isFilled ? PreludePalette.textAreaFill : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        isFilled ? Color.clear
                                 : (isEditorFocused ? PreludePalette.focusBlue : PreludePalette.dashedBorder),
                        style: StrokeStyle(lineWidth: 1, dash: isFilled ? [] : [2, 2])
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isEditorFocused)

            if isFilled {
                Text("📌")
                    .font(.system(size: 25))
                    .offset(x: -17, y: -13)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: customFirstLabel) { _, val in
            if !val.trimmingCharacters(in: .whitespaces).isEmpty {
                firstLabel = val
            } else if !displayedFirstOptions.contains(firstLabel) {
                // typed text was cleared and no option is pinned
                firstLabel = ""
            }
        }
    }

    /// One tape-topped option. Picking it pins it and clears anything typed.
    private func firstOptionCard(_ option: String) -> some View {
        let isPicked = firstLabel == option && customFirstLabel.isEmpty
        return ZStack(alignment: .top) {
            Button {
                isEditorFocused = false
                customFirstLabel = ""
                firstLabel = isPicked ? "" : option
            } label: {
                Text(option)
                    .font(.system(size: 14))
                    .foregroundStyle(isPicked ? PreludePalette.optionPickedInk : PreludePalette.optionInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 31)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isPicked ? PreludePalette.optionPicked : PreludePalette.optionFill)
                    )
            }
            .buttonStyle(.plain)

            WashiTapeStrip(width: 57)
                .offset(y: -9)

            if isPicked {
                Text("📌")
                    .font(.system(size: 25))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
                    .offset(y: -8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var dateBanner: some View {
        Button {
            isEditorFocused = false
            if !isDatePickerExpanded {
                calendarMonth = Calendar.current.component(.month, from: firstDate) - 1
                calendarYear = Calendar.current.component(.year, from: firstDate)
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                isDatePickerExpanded.toggle()
            }
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(firstDate, format: .dateTime.month(.wide).day())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PreludePalette.dateInk)
                    Text(firstDate, format: .dateTime.year())
                        .font(.system(size: 16))
                        .foregroundStyle(PreludePalette.dateYearInk)
                }
                Spacer()
                HStack(spacing: 9) {
                    Image(systemName: "calendar")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.black)
                    Text("tap to change")
                        .font(.system(size: 11.5))
                        .foregroundStyle(PreludePalette.dateHintInk)
                }
            }
            .padding(.horizontal, 21)
            .frame(height: 59)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(PreludePalette.textAreaFill)
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
                firstLabel = customFirstLabel        // only the wording changes
            }
        } label: {
            Text("Generate more options")
                .font(.system(size: 11))
                .foregroundStyle(PreludePalette.generateInk)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(
                    Capsule()
                        .fill(PreludePalette.generateFill)
                        .overlay(Capsule().strokeBorder(PreludePalette.generateBorder, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Other Editors

    private var currentNotePrompt: String {
        notePrompts[promptIndex % notePrompts.count]
    }

    // MARK: - Note Editor

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Prompt generation button
            Button {
                if showNotePrompt {
                    promptIndex += 1
                } else {
                    showNotePrompt = true
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "star")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.notePromptFill)
                    Text(showNotePrompt ? "Different prompt" : "Generate a prompt")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PreludePalette.promptChipText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .overlay(
                    Capsule()
                        .strokeBorder(PreludePalette.promptChipBorder, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)

            // Prompt chip (dark mocha bar)
            if showNotePrompt {
                notePromptChip(currentNotePrompt)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Text entry area
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PreludePalette.textAreaFill)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isEditorFocused ? BabyTownTheme.notePromptFill : .clear, lineWidth: 1.5)
                    .animation(.easeInOut(duration: 0.15), value: isEditorFocused)

                TextEditor(text: $noteText)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(PreludePalette.bodyText)
                    .frame(minHeight: 136)
                    .padding(9)
                    .font(.system(size: 15))
                    .focused($isEditorFocused)

                // Placeholder never mirrors the prompt — it always reads the same.
                if noteText.isEmpty {
                    Text("Enter your thoughts...")
                        .font(.system(size: 15))
                        .foregroundStyle(PreludePalette.placeholderInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 164)
            .padding(.bottom, 22)

            // Mood stamp carousel
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 5) {
                    Text("How are you feeling?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PreludePalette.bodyText)
                    Text("— optional")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(PreludePalette.optionalItalic)
                }
                StampCarouselView(selectedMood: $noteMood)
            }
            .padding(.bottom, 22)

            // Photo section
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 5) {
                    Text("Add a photo?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PreludePalette.bodyText)
                    Text("— optional")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(PreludePalette.optionalItalic)
                }
                notePolaroidPhoto
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showNotePrompt)
    }

    /// Warm mocha prompt bar with the washi-tape strip layered in front of it.
    private func notePromptChip(_ text: String) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(BabyTownTheme.notePromptFill)
                .frame(height: 44)
                .overlay(alignment: .leading) {
                    Text(text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 14)
                }
                .padding(.top, 9)

            WashiTapeStrip(width: 86)
        }
    }

    /// Polaroid-framed note photo area (frame artwork carries the "+" placeholder).
    private var notePolaroidPhoto: some View {
        PolaroidPhotoWell(
            image: notePhotoImage,
            onTap: { showNotePhotoPicker = true },
            onRemove: { notePhotoImage = nil }
        )
    }

    private var currentVoicePrompt: String {
        voicePrompts[voicePromptIndex % voicePrompts.count]
    }

    private var voiceMemoHeadline: String {
        destination.isLetterMode ? "Say it out loud" : "Say what you can't write"
    }

    private var voiceMemoDescription: String {
        destination.isLetterMode
            ? "Your voice carries warmth and meaning that text sometimes can't. Record a message they'll hear in your own words."
            : "Your voice carries what text sometimes can't — the pause, the laugh, the way you mean it. Speak freely. They'll hear you, not just your words."
    }

    private var voiceMemoEditor: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                if showsGiftToggle {
                    giftToggle
                        .padding(.bottom, 20)
                }

                Text(voiceMemoHeadline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PreludePalette.voiceHeading)
                    .padding(.bottom, 20)

                Text(voiceMemoDescription)
                    .font(.system(size: 13))
                    .lineSpacing(2.5)
                    .foregroundStyle(PreludePalette.voiceCopy)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 29)

                Button(showVoicePrompt ? "Different prompt" : "Generate a prompt") {
                    if showVoicePrompt {
                        voicePromptIndex += 1
                    } else {
                        showVoicePrompt = true
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(PreludePalette.generateInk)
                .padding(.horizontal, 13)
                .frame(height: 28)
                .overlay(
                    Capsule().strokeBorder(PreludePalette.generateBorder, lineWidth: 1)
                )
                .buttonStyle(.plain)

                if showVoicePrompt {
                    PreludeTapedPromptBar(text: currentVoicePrompt)
                        .padding(.top, 7)
                        .transition(.opacity)
                }

                VoiceMemoRecorderView(
                    existingFileId: existing?.voiceMemoFileId,
                    storage: voiceMemoStorage,
                    onSaved: { fileId in
                        savedVoiceMemoFileId = fileId
                    }
                )
                .padding(.top, 83)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 27)
            .padding(.top, 37)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeInOut(duration: 0.2), value: showVoicePrompt)
    }

    private var reasonPlaceholder: String {
        destination.isLetterMode ? "One reason I love you…" : "One reason I'm falling for you…"
    }

    private var reasonEditor: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                if showsGiftToggle {
                    giftToggle
                        .padding(.bottom, 20)
                }

                // Fixed prompt — this sheet never offers a different one.
                PreludeTapedPromptBar(text: reasonPrompt)
                    .padding(.bottom, 28)

                // Thought field with the paperclip over its top-left corner.
                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PreludePalette.textAreaFill)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isEditorFocused ? PreludePalette.promptBrown : .clear,
                                lineWidth: 1.5
                            )

                        TextEditor(text: $reasonText)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(PreludePalette.reasonInk)
                            .font(.system(size: 15))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .focused($isEditorFocused)

                        if reasonText.isEmpty {
                            Text("Enter your thoughts...")
                                .font(.system(size: 15))
                                .italic()
                                .foregroundStyle(PreludePalette.reasonPlaceholder)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 135)

                    PreludePaperclip()
                        .offset(x: -7, y: -9)
                }
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 27)
            .padding(.top, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.easeInOut(duration: 0.15), value: isEditorFocused)
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
        noteMood = c.noteMood
        firstLabel = c.firstLabel ?? ""
        reasonText = c.reasonText ?? ""
        savedVoiceMemoFileId = c.voiceMemoFileId
        firstDate = c.firstDate ?? Date()
        calendarMonth = Calendar.current.component(.month, from: firstDate) - 1
        calendarYear = Calendar.current.component(.year, from: firstDate)
        firstPhotoId = c.firstPhotoId
        if let photoId = c.firstPhotoId {
            firstPhotoImage = DataPersistenceManager.shared.loadPreludePhoto(photoId: photoId)
        }
        notePhotoId = c.notePhotoId
        if let photoId = c.notePhotoId {
            notePhotoImage = DataPersistenceManager.shared.loadPreludePhoto(photoId: photoId)
        }
    }

    private func resolvedNotePhotoId() -> UUID? {
        if notePhotoImage != nil {
            return notePhotoId ?? existing?.notePhotoId ?? UUID()
        }
        if let existingPhotoId = existing?.notePhotoId {
            DataPersistenceManager.shared.deletePreludePhoto(photoId: existingPhotoId)
        }
        return nil
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
        switch destination {
        case .prelude(let viewModel):
            saveToPrelude(viewModel: viewModel)
        case .letter(let onSave):
            saveToLetter(onSave: onSave)
        }
        onSave()
    }

    private func saveToLetter(onSave: (LetterBlock) -> Void) {
        guard type == .voiceMemo else { return }

        let block = LetterBlock(
            type: .voiceMemo,
            voiceMemoFileId: savedVoiceMemoFileId
        )
        onSave(block)
    }

    private func saveToPrelude(viewModel: PreludeViewModel) {
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

        var savedNotePhotoId: UUID?
        if type == .note {
            savedNotePhotoId = resolvedNotePhotoId()
            if let photoId = savedNotePhotoId, let image = notePhotoImage {
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
            notePhotoId: type == .note ? savedNotePhotoId : nil,
            firstLabel: type == .first ? firstLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            firstPhotoId: type == .first ? savedFirstPhotoId : nil,
            voiceMemoFileId: resolvedFileId,
            reasonText: type == .reason ? reasonText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            firstDate: type == .first ? firstDate : nil,
            serverId: existing?.serverId,
            remotePhotoPath: type == .first && savedFirstPhotoId == existing?.firstPhotoId ? existing?.remotePhotoPath : nil,
            remoteVoiceMemoPath: resolvedFileId == existing?.voiceMemoFileId ? existing?.remoteVoiceMemoPath : nil
        )

        if existing != nil {
            viewModel.updateCapture(capture)
        } else {
            viewModel.addCapture(capture)
        }
    }
}

#Preview {
    CaptureEditorView(
        type: .first,
        existing: nil,
        destination: .prelude(PreludeViewModel()),
        onSave: {},
        onCancel: {}
    )
}
