import SwiftUI
import PhotosUI
import UIKit

struct ComposeLetterView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var letterTitle = ""
    @State private var letterBody = ""
    @State private var letterBlocks: [LetterBlock] = []
    @State private var stickerImages: [UUID: UIImage] = [:]
    @State private var photoImages: [UUID: UIImage] = [:]
    @State private var selectedStickerID: UUID?
    @State private var selectedPhotoID: UUID?
    @State private var showLetter = false
    @State private var showScheduleSheet = false
    @State private var scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var blockEditorPresentation: LetterBlockEditorPresentation?
    @State private var photoPickerPurpose: LetterPhotoPickerPurpose?
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case body
    }

    private enum QuickAddAction {
        case voice
        case photo
        case sticker

        var icon: String {
            switch self {
            case .voice: return "mic.fill"
            case .photo: return "photo.on.rectangle.angled"
            case .sticker: return "square.on.square.dashed"
            }
        }

        var label: String {
            switch self {
            case .voice: return "Voice"
            case .photo: return "Photo"
            case .sticker: return "Sticker"
            }
        }
    }

    private let quickAddButtons: [QuickAddAction] = [.voice, .photo, .sticker]

    private var inlineBlocks: [LetterBlock] {
        letterBlocks.filter { $0.type == .voiceMemo }
    }

    private var photoBlocks: [LetterBlock] {
        letterBlocks.filter { $0.type == .photo }
    }

    private var stickerBlocks: [LetterBlock] {
        letterBlocks.filter { $0.type == .sticker }
    }

    private var hasLetterContent: Bool {
        !letterBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !inlineBlocks.isEmpty
    }

    private var letterContentWidth: CGFloat {
        BabyTownLetterCardStyle.referenceCanvasWidth - 56
    }

    var body: some View {
        ZStack {
            BabyTownTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        letterCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        Image("First Page Cat")
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 40)
                            .padding(.top, 8)
                            .padding(.bottom, 100)
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture { resignKeyboard() }
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollDisabled(selectedStickerID != nil || selectedPhotoID != nil)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            quickAddBar
                .padding(.bottom, 8)
                .background(
                    BabyTownTheme.backgroundGradient
                        .opacity(0.95)
                        .ignoresSafeArea(edges: .bottom)
                )
        }
        .sheet(isPresented: $showScheduleSheet) {
            scheduleSheet
        }
        .sheet(item: $blockEditorPresentation) { presentation in
            CaptureEditorView(
                type: presentation.type.captureType ?? .voiceMemo,
                existing: nil,
                destination: .letter { block in
                    letterBlocks.append(block)
                },
                onSave: { blockEditorPresentation = nil },
                onCancel: { blockEditorPresentation = nil }
            )
        }
        .sheet(item: $photoPickerPurpose) { purpose in
            LetterLibraryPhotoPicker(purpose: purpose) { image in
                switch purpose {
                case .sticker:
                    addSticker(from: image)
                case .photo:
                    addPhoto(from: image)
                }
            }
        }
        .onChange(of: selectedStickerID) { _, newValue in
            if newValue != nil {
                selectedPhotoID = nil
                resignKeyboard()
            }
        }
        .onChange(of: selectedPhotoID) { _, newValue in
            if newValue != nil {
                selectedStickerID = nil
                resignKeyboard()
            }
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue != nil {
                selectedStickerID = nil
                selectedPhotoID = nil
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showLetter = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = .title
            }
        }
        .presentationBackground {
            BabyTownTheme.backgroundGradient
                .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.3))
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    showScheduleSheet = true
                } label: {
                    Text("Schedule")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.55))
                        )
                }
                .disabled(!canSaveLetter)
                .opacity(canSaveLetter ? 1 : 0.45)

                Button {
                    sendLetter(scheduledFor: nil)
                } label: {
                    Text("Send")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(BabyTownTheme.accentGradient)
                        )
                }
                .disabled(!canSaveLetter)
                .opacity(canSaveLetter ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { resignKeyboard() }
    }

    // MARK: - Letter Card

    private var letterCard: some View {
        BabyTownLetterCardStyle.letterChrome(
            cornerRadius: 20,
            canvasWidth: BabyTownLetterCardStyle.referenceCanvasWidth
        ) {
            ZStack {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .leading) {
                        if letterTitle.isEmpty {
                            Text("Letter Title")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.48))
                        }

                        TextField("", text: $letterTitle)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .body
                            }
                    }

                    Rectangle()
                        .fill(BabyTownTheme.accent.opacity(0.3))
                        .frame(height: 1)

                    ZStack(alignment: .topLeading) {
                        if !hasLetterContent {
                            Text("Start writing your letter...")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.35))
                                .padding(.top, 8)
                        }

                        TextEditor(text: $letterBody)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.8))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: hasLetterContent ? 140 : 220)
                            .focused($focusedField, equals: .body)
                    }

                    if !inlineBlocks.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(inlineBlocks) { block in
                                inlineBlockView(block, contentWidth: letterContentWidth)
                            }
                        }
                    }
                }
                .padding(28)

                if !photoBlocks.isEmpty {
                    LetterPhotosOverlay(
                        photoBlocks: photoBlocks,
                        images: photoImages,
                        contentWidth: letterContentWidth,
                        isEditing: true,
                        selectedID: $selectedPhotoID,
                        onPositionChanged: updatePhotoPosition,
                        onScaleChanged: updatePhotoScale,
                        onRotationChanged: updatePhotoRotation,
                        onDelete: removePhotoBlock
                    )
                }

                if !stickerBlocks.isEmpty {
                    LetterStickersOverlay(
                        stickerBlocks: stickerBlocks,
                        images: stickerImages,
                        isEditing: true,
                        selectedID: $selectedStickerID,
                        onPositionChanged: updateStickerPosition,
                        onScaleChanged: updateStickerScale,
                        onRotationChanged: updateStickerRotation,
                        onDelete: removeStickerBlock
                    )
                }
            }
        }
        .scaleEffect(showLetter ? 1.0 : 0.9)
        .opacity(showLetter ? 1.0 : 0.0)
    }

    @ViewBuilder
    private func inlineBlockView(_ block: LetterBlock, contentWidth: CGFloat) -> some View {
        switch block.type {
        case .voiceMemo:
            LetterBlockPreviewCard(block: block) {
                removeBlock(block)
            }

        case .photo, .sticker:
            EmptyView()
        }
    }

    // MARK: - Quick Add

    private var quickAddBar: some View {
        HStack(spacing: 0) {
            ForEach(quickAddButtons, id: \.label) { action in
                Button {
                    resignKeyboard()
                    clearSelection()
                    switch action {
                    case .voice:
                        blockEditorPresentation = .new(.voiceMemo)
                    case .photo:
                        photoPickerPurpose = .photo
                    case .sticker:
                        photoPickerPurpose = .sticker
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: action.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                        Text(action.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(
            Capsule()
                .fill(BabyTownTheme.accentGradient)
                .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 12, y: 4)
        )
        .padding(.horizontal, 20)
    }

    private var scheduleSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Deliver on",
                    selection: $scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Schedule Letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showScheduleSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        sendLetter(scheduledFor: scheduledDate)
                        showScheduleSheet = false
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSaveLetter)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSaveLetter: Bool {
        let hasBody = !letterBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasBody || !letterBlocks.isEmpty
    }

    private func resignKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func clearSelection() {
        resignKeyboard()
        deselectCanvasItems()
    }

    private func deselectCanvasItems() {
        selectedStickerID = nil
        selectedPhotoID = nil
    }

    // MARK: - Photos

    private func addPhoto(from sourceImage: UIImage) {
        let blockID = UUID()
        let imageID = UUID()

        DataPersistenceManager.shared.saveLetterPhotoImage(sourceImage, id: imageID)

        let block = LetterBlock(
            id: blockID,
            type: .photo,
            photoImageId: imageID,
            photoPosition: nextPhotoPosition(),
            photoRotation: Double.random(in: -4...4),
            photoScale: LetterPhotoLayout.defaultScale
        )

        letterBlocks.append(block)
        photoImages[blockID] = sourceImage
    }

    private func removePhotoBlock(_ id: UUID) {
        guard let block = letterBlocks.first(where: { $0.id == id }) else { return }
        if let imageID = block.photoImageId {
            DataPersistenceManager.shared.deleteLetterPhotoImage(id: imageID)
        }
        photoImages[id] = nil
        if selectedPhotoID == id { selectedPhotoID = nil }
        letterBlocks.removeAll { $0.id == id }
    }

    private func nextPhotoPosition() -> NormalizedPoint {
        let existing = photoBlocks.compactMap(\.photoPosition)
        let minDistance: CGFloat = 0.16
        let candidates: [NormalizedPoint] = [
            NormalizedPoint(x: 0.40, y: 0.58),
            NormalizedPoint(x: 0.60, y: 0.62),
            NormalizedPoint(x: 0.50, y: 0.70),
            NormalizedPoint(x: 0.35, y: 0.68),
            NormalizedPoint(x: 0.65, y: 0.55)
        ]

        for candidate in candidates {
            let isClear = existing.allSatisfy {
                hypot($0.x - candidate.x, $0.y - candidate.y) > minDistance
            }
            if isClear { return candidate }
        }

        return NormalizedPoint(
            x: .random(in: 0.30...0.70),
            y: .random(in: 0.50...0.78)
        )
    }

    private func updatePhotoPosition(id: UUID, position: NormalizedPoint) {
        guard let idx = letterBlocks.firstIndex(where: { $0.id == id }) else { return }
        letterBlocks[idx].photoPosition = position
    }

    private func updatePhotoScale(id: UUID, scale: CGFloat) {
        guard let idx = letterBlocks.firstIndex(where: { $0.id == id }) else { return }
        letterBlocks[idx].photoScale = scale
    }

    private func updatePhotoRotation(id: UUID, rotation: Double) {
        guard let idx = letterBlocks.firstIndex(where: { $0.id == id }) else { return }
        letterBlocks[idx].photoRotation = rotation
    }

    // MARK: - Stickers

    private func addSticker(from sourceImage: UIImage) {
        let processed = SubjectLiftService.stickerImage(from: sourceImage)
        let blockID = UUID()
        let imageID = UUID()

        DataPersistenceManager.shared.saveLetterStickerImage(processed.image, id: imageID)

        let position = nextStickerPosition()
        let block = LetterBlock(
            id: blockID,
            type: .sticker,
            stickerImageId: imageID,
            stickerPosition: position,
            stickerRotation: Double.random(in: -12...12),
            stickerScale: LetterPhotoLayout.defaultStickerScale,
            usedSubjectLift: processed.usedSubjectLift
        )

        letterBlocks.append(block)
        stickerImages[blockID] = processed.image
    }

    private func nextStickerPosition() -> NormalizedPoint {
        let existing = stickerBlocks.compactMap(\.stickerPosition)
        let minDistance: CGFloat = 0.14
        let candidates: [NormalizedPoint] = [
            NormalizedPoint(x: 0.35, y: 0.45),
            NormalizedPoint(x: 0.65, y: 0.50),
            NormalizedPoint(x: 0.50, y: 0.60),
            NormalizedPoint(x: 0.30, y: 0.65),
            NormalizedPoint(x: 0.70, y: 0.40),
            NormalizedPoint(x: 0.45, y: 0.75)
        ]

        for candidate in candidates {
            let isClear = existing.allSatisfy {
                hypot($0.x - candidate.x, $0.y - candidate.y) > minDistance
            }
            if isClear { return candidate }
        }

        return NormalizedPoint(
            x: .random(in: 0.25...0.75),
            y: .random(in: 0.35...0.80)
        )
    }

    private func updateStickerPosition(id: UUID, position: NormalizedPoint) {
        guard let idx = letterBlocks.firstIndex(where: { $0.id == id }) else { return }
        letterBlocks[idx].stickerPosition = position
    }

    private func updateStickerScale(id: UUID, scale: CGFloat) {
        guard let idx = letterBlocks.firstIndex(where: { $0.id == id }) else { return }
        letterBlocks[idx].stickerScale = scale
    }

    private func updateStickerRotation(id: UUID, rotation: Double) {
        guard let idx = letterBlocks.firstIndex(where: { $0.id == id }) else { return }
        letterBlocks[idx].stickerRotation = rotation
    }

    private func removeStickerBlock(_ id: UUID) {
        guard let block = letterBlocks.first(where: { $0.id == id }) else { return }
        if let imageID = block.stickerImageId {
            DataPersistenceManager.shared.deleteLetterStickerImage(id: imageID)
        }
        stickerImages[id] = nil
        if selectedStickerID == id { selectedStickerID = nil }
        letterBlocks.removeAll { $0.id == id }
    }

    private func removeBlock(_ block: LetterBlock) {
        switch block.type {
        case .sticker:
            removeStickerBlock(block.id)
        case .photo:
            removePhotoBlock(block.id)
        case .voiceMemo:
            if let fileId = block.voiceMemoFileId {
                DataPersistenceManager.shared.deleteLetterVoiceMemo(fileId: fileId)
            }
            letterBlocks.removeAll { $0.id == block.id }
        }
    }

    private func sendLetter(scheduledFor: Date?) {
        guard canSaveLetter else { return }

        let letter = UserLetter(
            id: UUID(),
            title: letterTitle,
            body: letterBody.trimmingCharacters(in: .whitespacesAndNewlines),
            blocks: letterBlocks,
            createdAt: Date(),
            scheduledFor: scheduledFor,
            sentAt: scheduledFor == nil ? Date() : nil
        )
        DataPersistenceManager.shared.appendUserLetter(letter)
        dismiss()
    }
}

// MARK: - Photo Picker

private enum LetterPhotoPickerPurpose: Identifiable {
    case sticker
    case photo

    var id: Self { self }
}

private struct LetterLibraryPhotoPicker: UIViewControllerRepresentable {
    let purpose: LetterPhotoPickerPurpose
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LetterLibraryPhotoPicker

        init(_ parent: LetterLibraryPhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let result = results.first else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.onImagePicked(image)
                    }
                }
            }
        }
    }
}

#Preview {
    ComposeLetterView()
}
