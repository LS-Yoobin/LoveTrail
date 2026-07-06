import SwiftUI
import PhotosUI

struct PreludeFirstEditSheet: View {

    let capture: PreludeCapture
    @ObservedObject var viewModel: PreludeViewModel
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var label: String
    @State private var date: Date
    @State private var photoImage: UIImage?
    @State private var photoId: UUID?
    @State private var isDatePickerExpanded = false
    @State private var showPhotoPicker = false
    @FocusState private var isLabelFocused: Bool

    init(capture: PreludeCapture, viewModel: PreludeViewModel, onDone: @escaping () -> Void) {
        self.capture = capture
        self.viewModel = viewModel
        self.onDone = onDone
        _label = State(initialValue: capture.firstLabel ?? "")
        _date = State(initialValue: capture.firstDate ?? capture.createdAt)
        _photoId = State(initialValue: capture.firstPhotoId)
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    photoSection
                    formSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle("Edit First")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        SavePillLabel(title: "Save", isEnabled: canSave)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if let id = capture.firstPhotoId {
                photoImage = DataPersistenceManager.shared.loadPreludePhoto(photoId: id)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView(
                selectedImages: .constant([]),
                selectionLimit: 1,
                onFinish: { results in
                    showPhotoPicker = false
                    guard let result = results.first else { return }
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        guard let image = object as? UIImage else { return }
                        DispatchQueue.main.async {
                            photoImage = image
                        }
                    }
                }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoSection: some View {
        if let photoImage {
            ZStack(alignment: .bottomTrailing) {
                Button { showPhotoPicker = true } label: {
                    Image(uiImage: photoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Button { showPhotoPicker = true } label: {
                        Label("Change", systemImage: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.photoImage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.black.opacity(0.45)).frame(width: 22, height: 22))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
        } else {
            Button { showPhotoPicker = true } label: {
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                    Text("Add a photo")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(BabyTownTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(BabyTownTheme.accent.opacity(0.07))
                        .overlay(
                            Rectangle()
                                .strokeBorder(
                                    BabyTownTheme.accent.opacity(0.25),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 5])
                                )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            labelField
            datePicker
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    private var labelField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT WAS THE FIRST?")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)

            TextField(
                "",
                text: $label,
                prompt: Text("First text conversation").foregroundStyle(Color.black.opacity(0.4))
            )
            .font(.system(size: 17))
            .foregroundStyle(BabyTownTheme.textPrimary)
            .focused($isLabelFocused)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BabyTownTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isLabelFocused ? BabyTownTheme.accent.opacity(0.5) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isLabelFocused)
        }
    }

    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHEN WAS THIS?")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)

            Button {
                isLabelFocused = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDatePickerExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(BabyTownTheme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(date, format: .dateTime.month(.wide).day())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                        Text(date, format: .dateTime.year())
                            .font(.system(size: 13))
                            .foregroundStyle(.black)
                    }
                    Spacer()
                    Image(systemName: isDatePickerExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BabyTownTheme.cardBackground)
                )
            }
            .buttonStyle(.plain)

            if isDatePickerExpanded {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(BabyTownTheme.accent)
                    .colorScheme(.light)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onChange(of: date) { _, _ in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDatePickerExpanded = false
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDatePickerExpanded)
    }

    // MARK: - Save

    private func resolvePhotoId() -> UUID? {
        guard let img = photoImage else {
            if let old = capture.firstPhotoId {
                DataPersistenceManager.shared.deletePreludePhoto(photoId: old)
            }
            return nil
        }
        let id = photoId ?? UUID()
        DataPersistenceManager.shared.savePreludePhoto(img, photoId: id)
        return id
    }

    private func save() {
        var updated = capture
        updated.firstLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.firstDate = date
        let newPhotoId = resolvePhotoId()
        if newPhotoId != capture.firstPhotoId {
            // Photo attachment changed — force a re-upload next sync.
            updated.remotePhotoPath = nil
        }
        updated.firstPhotoId = newPhotoId
        viewModel.updateCapture(updated)
        dismiss()
        onDone()
    }
}
