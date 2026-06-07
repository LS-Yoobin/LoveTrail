import SwiftUI
import UIKit

/// Layout constants for the scrapbook note asset (`profile_garden_note`).
enum ProfileGardenNoteLayout {
    static let assetName = "profile_garden_note"
    static let aspectRatio: CGFloat = 3 / 4
    static let maxCanvasWidth: CGFloat = 240
    static let canvasWidthFraction: CGFloat = 0.52

    static func noteWidth(for canvasWidth: CGFloat) -> CGFloat {
        min(canvasWidth * canvasWidthFraction, maxCanvasWidth)
    }

    static func noteHeight(for noteWidth: CGFloat) -> CGFloat {
        noteWidth / aspectRatio
    }

    /// Note PNG with export matte keyed to transparency (same treatment as shop frame art).
    static func noteArtImage() -> UIImage? {
        PetShopCatalog.frameArtImage(named: assetName)
    }

    /// Insets that keep text inside the dashed inner border on the PNG.
    static let textHorizontalInsetFraction: CGFloat = 0.14
    static let textTopInsetFraction: CGFloat = 0.24
    static let textBottomInsetFraction: CGFloat = 0.22
    /// Maximum visible lines inside the note text area (no scrolling).
    static let maxTextLines = 7
    /// Nudges editor text down to match the placeholder baseline in the note sheet.
    static let editorTextTopOffset: CGFloat = 6

    static func textAreaWidth(noteWidth: CGFloat) -> CGFloat {
        noteWidth * (1 - 2 * textHorizontalInsetFraction)
    }

    static func noteUIFont() -> UIFont {
        UIFont.systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .medium
        )
    }

    static func lineCount(for text: String, noteWidth: CGFloat) -> Int {
        guard !text.isEmpty else { return 0 }
        let width = textAreaWidth(noteWidth: noteWidth)
        let font = noteUIFont()
        let storage = NSTextStorage(string: text, attributes: [.font: font])
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        layoutManager.ensureLayout(for: container)
        var lines = 0
        layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(for: container)) { _, _, _, _, _ in
            lines += 1
        }
        return lines
    }

    static func clampedNoteText(
        _ text: String,
        noteWidth: CGFloat,
        maxLines: Int = maxTextLines,
        maxLength: Int = ProfileNoteEditorSheet.maxLength
    ) -> String {
        var result = text
        if result.count > maxLength {
            result = String(result.prefix(maxLength))
        }
        while !result.isEmpty && lineCount(for: result, noteWidth: noteWidth) > maxLines {
            result = String(result.dropLast())
        }
        return result
    }

    private static let noteDragBounds = (
        minX: CGFloat(0.08),
        maxX: CGFloat(0.92),
        minY: CGFloat(0.12),
        maxY: CGFloat(0.90)
    )

    /// Default note center from avatar sticker layout (normalized canvas coords).
    static func defaultNormalizedPosition(stickers: [ProfileSticker]) -> NormalizedPoint {
        let profileStickers = stickers.filter {
            $0.kind == .userAvatar || $0.kind == .partnerInvite
        }
        guard !profileStickers.isEmpty else {
            return NormalizedPoint(x: 0.5, y: ProfileGardenLayout.profileSlotNormalizedY + 0.12)
        }

        let xs = profileStickers.map { CGFloat($0.position.x) }
        let ys = profileStickers.map { CGFloat($0.position.y) }
        let centerX = (xs.min()! + xs.max()!) / 2
        let belowAvatars = (ys.max() ?? 0.5) + 0.14
        return NormalizedPoint(x: centerX, y: min(belowAvatars, 0.88))
    }

    static func defaultPosition(
        stickers: [ProfileSticker],
        canvasSize: CGSize
    ) -> NormalizedPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return defaultNormalizedPosition(stickers: stickers)
        }

        var point = defaultNormalizedPosition(stickers: stickers)
        let noteH = noteHeight(for: noteWidth(for: canvasSize.width))
        let minY = (noteH / 2 + 8) / canvasSize.height
        point.y = max(point.y, minY)

        return positionAvoidingStickers(
            preferred: point,
            stickers: stickers,
            canvasSize: canvasSize
        )
    }

    private struct NormalizedRect {
        let centerX: CGFloat
        let centerY: CGFloat
        let halfWidth: CGFloat
        let halfHeight: CGFloat

        func intersects(_ other: NormalizedRect, gap: CGFloat) -> Bool {
            abs(centerX - other.centerX) < (halfWidth + other.halfWidth + gap)
                && abs(centerY - other.centerY) < (halfHeight + other.halfHeight + gap)
        }
    }

    private static func stickerIncludesLabel(_ sticker: ProfileSticker) -> Bool {
        sticker.kind == .userAvatar || sticker.kind == .partnerInvite
    }

    private static func stickerLayoutBounds(
        _ sticker: ProfileSticker,
        canvasSize: CGSize
    ) -> NormalizedRect {
        let side = ProfileSticker.renderedSize(scale: sticker.scale)
        let includesLabel = stickerIncludesLabel(sticker)
        let labelBlock: CGFloat = includesLabel ? 46 : 0
        let width = includesLabel ? max(side, 120) : side
        let totalHeight = side + labelBlock
        return NormalizedRect(
            centerX: CGFloat(sticker.position.x),
            centerY: CGFloat(sticker.position.y),
            halfWidth: (width / 2) / canvasSize.width,
            halfHeight: (totalHeight / 2) / canvasSize.height
        )
    }

    private static func noteLayoutBounds(
        at position: NormalizedPoint,
        canvasSize: CGSize
    ) -> NormalizedRect {
        let width = noteWidth(for: canvasSize.width)
        let height = noteHeight(for: width)
        return NormalizedRect(
            centerX: CGFloat(position.x),
            centerY: CGFloat(position.y),
            halfWidth: (width / 2) / canvasSize.width,
            halfHeight: (height / 2) / canvasSize.height
        )
    }

    private static func positionAvoidingStickers(
        preferred: NormalizedPoint,
        stickers: [ProfileSticker],
        canvasSize: CGSize,
        gap: CGFloat = 0.02
    ) -> NormalizedPoint {
        let stickerRects = stickers.map { stickerLayoutBounds($0, canvasSize: canvasSize) }
        let bounds = noteDragBounds

        func fits(_ point: NormalizedPoint) -> Bool {
            guard CGFloat(point.x) >= bounds.minX,
                  CGFloat(point.x) <= bounds.maxX,
                  CGFloat(point.y) >= bounds.minY,
                  CGFloat(point.y) <= bounds.maxY else {
                return false
            }
            let noteRect = noteLayoutBounds(at: point, canvasSize: canvasSize)
            return !stickerRects.contains { noteRect.intersects($0, gap: gap) }
        }

        if fits(preferred) { return preferred }

        let xOffsets: [CGFloat] = [0, 0.14, -0.14, 0.28, -0.28, 0.42, -0.42]
        let yStep: CGFloat = 0.05
        let maxY = min(CGFloat(preferred.y) + 0.45, bounds.maxY)
        var y = CGFloat(preferred.y)

        while y <= maxY {
            for xOffset in xOffsets {
                let candidate = NormalizedPoint(
                    x: Double(min(max(CGFloat(preferred.x) + xOffset, bounds.minX), bounds.maxX)),
                    y: Double(y)
                )
                if fits(candidate) { return candidate }
            }
            y += yStep
        }

        return preferred
    }
}

/// Non-scrollable note input capped at a fixed number of wrapped lines.
struct FixedLineNoteTextEditor: UIViewRepresentable {
    @Binding var text: String
    let noteWidth: CGFloat
    var isFocused: FocusState<Bool>.Binding

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, noteWidth: noteWidth, isFocused: isFocused)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textAlignment = .center
        textView.font = ProfileGardenNoteLayout.noteUIFont()
        textView.textColor = UIColor(red: 0.38, green: 0.30, blue: 0.24, alpha: 1)
        textView.textContainerInset = UIEdgeInsets(
            top: ProfileGardenNoteLayout.editorTextTopOffset,
            left: 0,
            bottom: 0,
            right: 0
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = ProfileGardenNoteLayout.maxTextLines
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if !textView.isFirstResponder {
            let clamped = ProfileGardenNoteLayout.clampedNoteText(text, noteWidth: noteWidth)
            if textView.text != clamped {
                textView.text = clamped
            }
        }

        if isFocused.wrappedValue, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isFocused.wrappedValue, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let noteWidth: CGFloat
        var isFocused: FocusState<Bool>.Binding

        init(text: Binding<String>, noteWidth: CGFloat, isFocused: FocusState<Bool>.Binding) {
            _text = text
            self.noteWidth = noteWidth
            self.isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            let clamped = ProfileGardenNoteLayout.clampedNoteText(textView.text, noteWidth: noteWidth)
            if textView.text != clamped {
                textView.text = clamped
            }
            if text != clamped {
                text = clamped
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            let current = textView.text ?? ""
            let proposed = (current as NSString).replacingCharacters(in: range, with: replacement)
            if proposed.count > ProfileNoteEditorSheet.maxLength { return false }
            return ProfileGardenNoteLayout.lineCount(for: proposed, noteWidth: noteWidth) <= ProfileGardenNoteLayout.maxTextLines
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            // SwiftUI re-renders on each keystroke can briefly end editing; reclaim focus
            // when the parent still intends the keyboard to stay open.
            DispatchQueue.main.async {
                guard self.isFocused.wrappedValue, textView.window != nil else { return }
                if !textView.isFirstResponder {
                    textView.becomeFirstResponder()
                }
            }
        }
    }
}

/// Scrapbook note PNG with optional centered text (read-only on the garden canvas).
struct ProfileGardenNoteChrome: View {
    let text: String
    let noteWidth: CGFloat

    private var noteHeight: CGFloat {
        ProfileGardenNoteLayout.noteHeight(for: noteWidth)
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            noteArt
                .resizable()
                .scaledToFit()
                .frame(width: noteWidth, height: noteHeight)

            if !trimmed.isEmpty {
                Text(trimmed)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.38, green: 0.30, blue: 0.24))
                    .multilineTextAlignment(.center)
                    .lineLimit(ProfileGardenNoteLayout.maxTextLines)
                    .lineSpacing(3)
                    .padding(.horizontal, noteWidth * ProfileGardenNoteLayout.textHorizontalInsetFraction)
                    .padding(.top, noteHeight * ProfileGardenNoteLayout.textTopInsetFraction)
                    .padding(.bottom, noteHeight * ProfileGardenNoteLayout.textBottomInsetFraction)
                    .frame(width: noteWidth, height: noteHeight, alignment: .top)
            }
        }
        .frame(width: noteWidth, height: noteHeight)
        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
    }

    private var noteArt: Image {
        if let uiImage = ProfileGardenNoteLayout.noteArtImage()
            ?? UIImage(named: ProfileGardenNoteLayout.assetName) {
            return Image(uiImage: uiImage)
        }
        return Image(ProfileGardenNoteLayout.assetName)
    }
}

/// Draggable garden note on the sticker canvas.
struct ProfileGardenNoteView: View {
    let text: String
    let position: NormalizedPoint?
    let stickers: [ProfileSticker]
    let canvasSize: CGSize
    let isCustomizing: Bool
    var isSelected: Bool = false
    var allowsEmptyBody: Bool = false
    var fallbackPosition: ((CGSize) -> NormalizedPoint)? = nil
    var isDraggable: Bool? = nil
    var showsArrangementChrome: Bool? = nil
    var dragBounds: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)? = nil
    var onSelect: (() -> Void)?
    var onDelete: (() -> Void)?
    var showsDeleteButton: Bool = true
    let onPositionChanged: (NormalizedPoint) -> Void
    var onDragEnded: (() -> Void)? = nil
    var onDragActiveChanged: ((Bool) -> Void)? = nil
    var onTap: (() -> Void)?
    var onTapWhileCustomizing: (() -> Void)?

    @State private var dragOrigin: NormalizedPoint?

    private var noteWidth: CGFloat {
        ProfileGardenNoteLayout.noteWidth(for: canvasSize.width)
    }

    private var resolvedPosition: NormalizedPoint {
        if let position { return position }
        if let fallbackPosition { return fallbackPosition(canvasSize) }
        return ProfileGardenNoteLayout.defaultPosition(stickers: stickers, canvasSize: canvasSize)
    }

    private var center: CGPoint {
        CGPoint(
            x: resolvedPosition.x * canvasSize.width,
            y: resolvedPosition.y * canvasSize.height
        )
    }

    private var canDrag: Bool { isDraggable ?? isCustomizing }
    private var showChrome: Bool { showsArrangementChrome ?? isCustomizing }
    private var shouldPulse: Bool { showChrome && !isSelected }

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && !allowsEmptyBody { EmptyView() } else {
            Group {
                if let onTap, !isCustomizing {
                    Button(action: onTap) { noteBody(trimmed) }
                        .buttonStyle(.plain)
                } else {
                    noteBody(trimmed)
                }
            }
            .contentShape(Rectangle())
            .editGardenPulse(shouldPulse)
            .overlay(alignment: .top) {
                if showsDeleteButton, showChrome, isSelected, let onDelete {
                    EditGardenTrashButton(action: onDelete)
                        .offset(y: -44)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .position(center)
            .gesture(canDrag && isSelected ? dragGesture : nil)
            .onTapGesture {
                if canDrag {
                    if let onTapWhileCustomizing {
                        onTapWhileCustomizing()
                    } else {
                        onSelect?()
                    }
                }
            }
            .allowsHitTesting(canDrag || onTap != nil)
        }
    }

    private func noteBody(_ trimmed: String) -> some View {
        ProfileGardenNoteChrome(text: trimmed, noteWidth: noteWidth)
            .customizeDottedOutline(showChrome && isSelected, cornerRadius: 8, padding: 4, lineWidth: 3)
    }

    private var dragLimits: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        dragBounds ?? (minX: 0.08, maxX: 0.92, minY: 0.12, maxY: 0.90)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = resolvedPosition
                    onDragActiveChanged?(true)
                }
                let origin = dragOrigin ?? resolvedPosition
                let limits = dragLimits
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
