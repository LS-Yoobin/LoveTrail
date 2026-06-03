import SwiftUI

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

    /// Default note center from avatar sticker layout (normalized canvas coords).
    static func defaultNormalizedPosition(stickers: [ProfileSticker]) -> NormalizedPoint {
        let profileStickers = stickers.filter {
            $0.kind == .userAvatar || $0.kind == .partnerInvite
        }
        guard !profileStickers.isEmpty else {
            return NormalizedPoint(x: 0.5, y: 0.62)
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
        return point
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
    var onSelect: (() -> Void)?
    var onDelete: (() -> Void)?
    let onPositionChanged: (NormalizedPoint) -> Void
    var onTap: (() -> Void)?

    @State private var dragOrigin: NormalizedPoint?

    private var noteWidth: CGFloat {
        ProfileGardenNoteLayout.noteWidth(for: canvasSize.width)
    }

    private var resolvedPosition: NormalizedPoint {
        position ?? ProfileGardenNoteLayout.defaultPosition(stickers: stickers, canvasSize: canvasSize)
    }

    private var center: CGPoint {
        CGPoint(
            x: resolvedPosition.x * canvasSize.width,
            y: resolvedPosition.y * canvasSize.height
        )
    }

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { EmptyView() } else {
            Group {
                if let onTap, !isCustomizing {
                    Button(action: onTap) { noteBody(trimmed) }
                        .buttonStyle(.plain)
                } else {
                    noteBody(trimmed)
                }
            }
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if isCustomizing, isSelected, let onDelete {
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
            .gesture(isCustomizing ? dragGesture : nil)
            .onTapGesture {
                if isCustomizing {
                    onSelect?()
                }
            }
            .allowsHitTesting(isCustomizing || onTap != nil)
        }
    }

    private func noteBody(_ trimmed: String) -> some View {
        ProfileGardenNoteChrome(text: trimmed, noteWidth: noteWidth)
            .overlay {
                if isCustomizing {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Color.white,
                            style: StrokeStyle(
                                lineWidth: isSelected ? 3 : 2,
                                dash: isSelected ? [] : [6, 4]
                            )
                        )
                        .padding(4)
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let origin = dragOrigin ?? resolvedPosition
                if dragOrigin == nil { dragOrigin = resolvedPosition }
                let nx = min(max(origin.x + value.translation.width / canvasSize.width, 0.08), 0.92)
                let ny = min(max(origin.y + value.translation.height / canvasSize.height, 0.12), 0.90)
                onPositionChanged(NormalizedPoint(x: nx, y: ny))
            }
            .onEnded { _ in dragOrigin = nil }
    }
}
