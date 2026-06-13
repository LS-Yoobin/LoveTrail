import SwiftUI
import PhotosUI

/// Sheet payload so add vs edit context is passed atomically (avoids `isPresented`
/// reading stale `editing` state on first presentation).
struct SpecialDateEditorPresentation: Identifiable {
    let id: UUID
    let editing: SpecialDate?
    let initialImage: UIImage?

    static func add() -> SpecialDateEditorPresentation {
        SpecialDateEditorPresentation(id: UUID(), editing: nil, initialImage: nil)
    }

    static func edit(_ date: SpecialDate, image: UIImage?) -> SpecialDateEditorPresentation {
        SpecialDateEditorPresentation(id: date.id, editing: date, initialImage: image)
    }
}

/// Add or edit a special date: title, date, optional photo. `onSave` receives the
/// edited `SpecialDate` and the chosen image (nil = no change requested by the
/// caller's convention: see CoupleProfileView). `onDelete` is nil when adding.
struct SpecialDateEditorSheet: View {
    let editing: SpecialDate?
    let initialImage: UIImage?
    let onSave: (SpecialDate, UIImage?) -> Void
    let onDelete: ((SpecialDate) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?

    init(editing: SpecialDate?,
         initialImage: UIImage?,
         onSave: @escaping (SpecialDate, UIImage?) -> Void,
         onDelete: ((SpecialDate) -> Void)?) {
        self.editing = editing
        self.initialImage = initialImage
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: editing?.title ?? "")
        _date = State(initialValue: editing?.date ?? Date())
        _image = State(initialValue: initialImage)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. Anniversary)", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Photo (optional)") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(height: 160).frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Label("Choose a photo", systemImage: "photo")
                        }
                    }
                }
                if let editing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete(editing)
                            dismiss()
                        } label: {
                            Label("Delete date", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Add Special Date" : "Edit Special Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let result = SpecialDate(
                            id: editing?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: date,
                            isPinned: editing?.isPinned ?? false,
                            pinnedAt: editing?.pinnedAt
                        )
                        onSave(result, image)
                        dismiss()
                    } label: {
                        SavePillLabel(title: "Save", isEnabled: canSave)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        image = ui
                    }
                }
            }
        }
    }
}
