import SwiftUI

/// Full-screen editor for the garden profile note. Save/Cancel in the top bar;
/// writing happens on the scrapbook note PNG so the preview matches the garden.
struct ProfileNoteEditorSheet: View {
    static let maxLength = 500

    let initialText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String
    @FocusState private var isNoteFocused: Bool

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        let noteWidth: CGFloat = 280
        let clamped = ProfileGardenNoteLayout.clampedNoteText(initialText, noteWidth: noteWidth)
        _draftText = State(initialValue: clamped)
    }

    private var trimmedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.90, blue: 0.98),
                    Color(red: 0.66, green: 0.80, blue: 0.55),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                noteComposer
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isNoteFocused = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button("Save") {
                onSave(trimmedDraft)
                dismiss()
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(BabyTownTheme.savePillFill, in: Capsule())
            .buttonStyle(.plain)
        }
    }

    private var noteComposer: some View {
        let noteWidth: CGFloat = 280
        let noteHeight = ProfileGardenNoteLayout.noteHeight(for: noteWidth)

        return ZStack {
            noteArt
                .resizable()
                .scaledToFit()
                .frame(width: noteWidth, height: noteHeight)
                .shadow(color: .black.opacity(0.14), radius: 12, y: 6)

            ZStack(alignment: .topLeading) {
                if draftText.isEmpty, !isNoteFocused {
                    Text("Write something for your garden…")
                        .font(.body)
                        .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.42).opacity(0.55))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                }

                FixedLineNoteTextEditor(
                    text: $draftText,
                    noteWidth: noteWidth,
                    isFocused: $isNoteFocused
                )
            }
            .padding(.horizontal, noteWidth * ProfileGardenNoteLayout.textHorizontalInsetFraction)
            .padding(.top, noteHeight * ProfileGardenNoteLayout.textTopInsetFraction)
            .padding(.bottom, noteHeight * ProfileGardenNoteLayout.textBottomInsetFraction)
            .frame(width: noteWidth, height: noteHeight, alignment: .top)
        }
        .frame(width: noteWidth, height: noteHeight)
    }

    private var noteArt: Image {
        if let uiImage = ProfileGardenNoteLayout.noteArtImage()
            ?? UIImage(named: ProfileGardenNoteLayout.assetName) {
            return Image(uiImage: uiImage)
        }
        return Image(ProfileGardenNoteLayout.assetName)
    }
}
