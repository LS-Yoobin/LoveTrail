import SwiftUI

/// Draggable scrapbook note and photo stickers layered over the full memory page.
struct MemoryCanvasLayer: View {
    let stickers: [ProfileSticker]
    let images: [UUID: UIImage]
    let notes: [MemoryPageNote]
    let composingAuthor: MemoryNoteAuthor?
    let composingNotePosition: NormalizedPoint?
    let metadataBottomY: CGFloat
    let isComposingNote: Bool
    let isComposingNoteSelected: Bool
    let isEditingStickers: Bool
    let selectedStickerID: UUID?
    @Binding var noteDraft: String
    var isNoteFocused: FocusState<Bool>.Binding
    let onSelectComposingNote: () -> Void
    let onDeselectComposingNote: () -> Void
    let onDeleteComposingNote: () -> Void
    let onNotePositionChanged: (MemoryNoteAuthor, NormalizedPoint) -> Void
    let onStickerPositionChanged: (UUID, NormalizedPoint) -> Void
    let onStickerScaleChanged: (UUID, CGFloat) -> Void
    let onStickerRotationChanged: (UUID, Double) -> Void
    let onSelectSticker: (UUID?) -> Void
    let onDeleteSticker: (UUID) -> Void
    var onCanvasDragEnded: (() -> Void)? = nil
    var onCanvasDragActiveChanged: ((Bool) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let isArrangingOnCanvas = isComposingNote && !isNoteFocused.wrappedValue
            let stickerCustomize = isEditingStickers || isArrangingOnCanvas
            let stickerBounds = MemoryPageLayout.stickerDragBounds(
                metadataBottomY: metadataBottomY,
                contentHeight: geo.size.height
            )
            let noteFallback: (CGSize) -> NormalizedPoint = { size in
                let defaults = MemoryPageLayout.defaultNotePosition(
                    metadataBottomY: metadataBottomY,
                    contentHeight: size.height,
                    canvasWidth: size.width
                )
                return MemoryPageLayout.clampNotePosition(
                    defaults,
                    metadataBottomY: metadataBottomY,
                    contentHeight: size.height,
                    canvasWidth: size.width
                )
            }
            let noteBounds = MemoryPageLayout.noteDragBounds(
                metadataBottomY: metadataBottomY,
                contentHeight: geo.size.height,
                canvasWidth: geo.size.width
            )
            let clampNote: (NormalizedPoint) -> NormalizedPoint = { point in
                MemoryPageLayout.clampNotePosition(
                    point,
                    metadataBottomY: metadataBottomY,
                    contentHeight: geo.size.height,
                    canvasWidth: geo.size.width
                )
            }

            ZStack {
                if isEditingStickers || isArrangingOnCanvas {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectSticker(nil)
                            if isArrangingOnCanvas {
                                onDeselectComposingNote()
                            }
                        }
                }

                ForEach(notes.filter(\.hasContent)) { note in
                    if isComposingNote, composingAuthor == note.author {
                        memoryPageNoteComposer(
                            text: $noteDraft,
                            author: note.author,
                            position: composingNotePosition ?? note.position,
                            canvasSize: geo.size,
                            clampNote: clampNote
                        )
                    } else {
                        ProfileGardenNoteView(
                            text: note.text,
                            position: note.position.map(clampNote),
                            stickers: [],
                            canvasSize: geo.size,
                            isCustomizing: isEditingStickers,
                            fallbackPosition: noteFallback,
                            dragBounds: noteBounds,
                            onSelect: nil,
                            onDelete: nil,
                            onPositionChanged: { onNotePositionChanged(note.author, clampNote($0)) },
                            onDragEnded: onCanvasDragEnded,
                            onDragActiveChanged: onCanvasDragActiveChanged,
                            onTap: nil
                        )
                    }
                }

                if isComposingNote,
                   composingAuthor == .localUser,
                   !notes.contains(where: { $0.author == .localUser && $0.hasContent }) {
                    memoryPageNoteComposer(
                        text: $noteDraft,
                        author: .localUser,
                        position: composingNotePosition,
                        canvasSize: geo.size,
                        clampNote: clampNote
                    )
                }

                ForEach(stickers) { sticker in
                    ProfileStickerView(
                        sticker: sticker,
                        image: images[sticker.id],
                        label: nil,
                        canvasSize: geo.size,
                        isCustomizing: stickerCustomize,
                        isSelected: selectedStickerID == sticker.id,
                        showsArrangementChrome: stickerCustomize,
                        dragBounds: stickerBounds,
                        onSelect: { onSelectSticker(sticker.id) },
                        onDelete: isEditingStickers ? { onDeleteSticker(sticker.id) } : nil,
                        onPositionChanged: { onStickerPositionChanged(sticker.id, $0) },
                        onScaleChanged: { onStickerScaleChanged(sticker.id, $0) },
                        onDragEnded: onCanvasDragEnded,
                        onDragActiveChanged: onCanvasDragActiveChanged,
                        onRotationChanged: { onStickerRotationChanged(sticker.id, $0) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func memoryPageNoteComposer(
        text: Binding<String>,
        author: MemoryNoteAuthor,
        position: NormalizedPoint?,
        canvasSize: CGSize,
        clampNote: @escaping (NormalizedPoint) -> NormalizedPoint
    ) -> some View {
        MemoryPageNoteComposer(
            text: text,
            position: position,
            canvasSize: canvasSize,
            metadataBottomY: metadataBottomY,
            existingNotes: notes,
            author: author,
            isFocused: isNoteFocused,
            isSelected: isComposingNoteSelected,
            onSelect: onSelectComposingNote,
            onDeselect: onDeselectComposingNote,
            onDelete: onDeleteComposingNote,
            onPositionChanged: { onNotePositionChanged(author, clampNote($0)) },
            onDragEnded: onCanvasDragEnded,
            onDragActiveChanged: onCanvasDragActiveChanged
        )
    }
}

/// Inline note composer positioned on the memory page canvas.
private struct MemoryPageNoteComposer: View {
    @Binding var text: String
    let position: NormalizedPoint?
    let canvasSize: CGSize
    let metadataBottomY: CGFloat
    let existingNotes: [MemoryPageNote]
    let author: MemoryNoteAuthor
    var isFocused: FocusState<Bool>.Binding
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var onDeselect: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    let onPositionChanged: (NormalizedPoint) -> Void
    var onDragEnded: (() -> Void)? = nil
    var onDragActiveChanged: ((Bool) -> Void)? = nil

    @State private var dragOrigin: NormalizedPoint?

    private var noteWidth: CGFloat {
        ProfileGardenNoteLayout.noteWidth(for: canvasSize.width)
    }

    private var noteHeight: CGFloat {
        ProfileGardenNoteLayout.noteHeight(for: noteWidth)
    }

    private var resolvedPosition: NormalizedPoint {
        let raw = position ?? MemoryPageLayout.defaultNotePosition(
            for: author,
            existingNotes: existingNotes,
            metadataBottomY: metadataBottomY,
            contentHeight: canvasSize.height,
            canvasWidth: canvasSize.width
        )
        return MemoryPageLayout.clampNotePosition(
            raw,
            metadataBottomY: metadataBottomY,
            contentHeight: canvasSize.height,
            canvasWidth: canvasSize.width
        )
    }

    private var center: CGPoint {
        CGPoint(
            x: resolvedPosition.x * canvasSize.width,
            y: resolvedPosition.y * canvasSize.height
        )
    }

    private var dragBounds: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        MemoryPageLayout.noteDragBounds(
            metadataBottomY: metadataBottomY,
            contentHeight: canvasSize.height,
            canvasWidth: canvasSize.width
        )
    }

    var body: some View {
        ZStack {
            noteArt
                .resizable()
                .scaledToFit()
                .frame(width: noteWidth, height: noteHeight)
                .shadow(color: .black.opacity(0.16), radius: 10, y: 5)

            ZStack(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Leave a note for your future self.")
                        .font(.body)
                        .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.42).opacity(0.55))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                }

                FixedLineNoteTextEditor(
                    text: $text,
                    noteWidth: noteWidth,
                    isFocused: isFocused
                )
            }
            .padding(.horizontal, noteWidth * ProfileGardenNoteLayout.textHorizontalInsetFraction)
            .padding(.top, noteHeight * ProfileGardenNoteLayout.textTopInsetFraction)
            .padding(.bottom, noteHeight * ProfileGardenNoteLayout.textBottomInsetFraction)
            .frame(width: noteWidth, height: noteHeight, alignment: .top)
        }
        .frame(width: noteWidth, height: noteHeight)
        .overlay {
            if !isFocused.wrappedValue {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        Color.white,
                        style: StrokeStyle(
                            lineWidth: isSelected ? 3 : 2,
                            dash: isSelected ? [] : [6, 4]
                        )
                    )
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            if isSelected, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.red, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .offset(y: -44)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .position(center)
        .gesture(isFocused.wrappedValue ? nil : dragGesture)
        .modifier(ComposingNoteTapWhenUnfocused(isEnabled: !isFocused.wrappedValue, action: handleComposingNoteTap))
    }

    private func handleComposingNoteTap() {
        if isSelected {
            onDeselect?()
            isFocused.wrappedValue = true
        } else if let onSelect {
            onSelect()
        } else {
            isFocused.wrappedValue = true
        }
    }

    private var noteArt: Image {
        if let uiImage = ProfileGardenNoteLayout.noteArtImage()
            ?? UIImage(named: ProfileGardenNoteLayout.assetName) {
            return Image(uiImage: uiImage)
        }
        return Image(ProfileGardenNoteLayout.assetName)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = resolvedPosition
                    onDragActiveChanged?(true)
                }
                let origin = dragOrigin ?? resolvedPosition
                let limits = dragBounds
                let nx = min(max(origin.x + value.translation.width / canvasSize.width, limits.minX), limits.maxX)
                let ny = min(max(origin.y + value.translation.height / canvasSize.height, limits.minY), limits.maxY)
                onPositionChanged(NormalizedPoint(x: nx, y: ny))
            }
            .onEnded { _ in
                dragOrigin = nil
                onDragActiveChanged?(false)
                onDragEnded?()
            }
    }
}

/// Applies a tap handler only while the note keyboard is dismissed so taps reach the text view and system keyboard.
private struct ComposingNoteTapWhenUnfocused: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.onTapGesture(perform: action)
        } else {
            content
        }
    }
}
