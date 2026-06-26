import SwiftUI

struct NoteEditorSheet: View {
    let initialText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String
    @FocusState private var isFocused: Bool

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        _draftText = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftText)
                    .font(.body)
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .padding(12)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16))

                if draftText.isEmpty {
                    Text("Add notes, vibes, or anything you're excited about")
                        .font(.body)
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draftText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(BabyTownTheme.accent)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }
}

#Preview {
    NoteEditorSheet(initialText: "", onSave: { _ in })
}
