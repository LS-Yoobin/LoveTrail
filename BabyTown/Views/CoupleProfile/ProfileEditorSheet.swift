import SwiftUI
import PhotosUI

/// Sheet for editing your couple-profile identity: photo, display name, and garden mood.
/// Calls `onSave` with the chosen image (nil = no photo selected), trimmed name, and mood.
struct ProfileEditorSheet: View {
    private static let maxNameLength = 24

    let initialName: String
    let initialImage: UIImage?
    let initialMood: ProfileNoteMood?
    let onSave: (UIImage?, String, ProfileNoteMood?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var image: UIImage?
    @State private var selectedMood: ProfileNoteMood?
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var isNameFocused: Bool

    init(
        initialName: String,
        initialImage: UIImage?,
        initialMood: ProfileNoteMood? = nil,
        onSave: @escaping (UIImage?, String, ProfileNoteMood?) -> Void
    ) {
        self.initialName = initialName
        self.initialImage = initialImage
        self.initialMood = initialMood
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _image = State(initialValue: initialImage)
        _selectedMood = State(initialValue: initialMood)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName.count <= Self.maxNameLength
    }

    private var panelBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(white: 0.93),
                Color(white: 0.88),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 20)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    photoSection
                    nameSection
                    moodSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            bottomActions
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { panelBackground }
        .presentationCornerRadius(24)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run { image = ui }
                }
            }
        }
        .onChange(of: name) { _, newValue in
            if newValue.count > Self.maxNameLength {
                name = String(newValue.prefix(Self.maxNameLength))
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            Text("Your Profile")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.88))

            Text("Your photo becomes a sticker in the garden. Your name appears under your avatar.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
        }
    }

    private var photoSection: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(BabyTownTheme.accentIconBackdropGradient)
                            .frame(width: 132, height: 132)

                        Group {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 52))
                                    .foregroundStyle(BabyTownTheme.accent.opacity(0.45))
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    }
                    .overlay(
                        Circle()
                            .strokeBorder(BabyTownTheme.accentGradient, lineWidth: 3)
                            .frame(width: 132, height: 132)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: 126, height: 126)
                    )
                    .shadow(color: BabyTownTheme.cardShadow, radius: 12, y: 6)

                    editBadge
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            Text(image == nil ? "Add a photo" : "Tap to change photo")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accentDeep)

            if image != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        image = nil
                        pickerItem = nil
                    }
                } label: {
                    Text("Remove photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var editBadge: some View {
        ZStack {
            Circle()
                .fill(BabyTownTheme.accentGradient)
                .frame(width: 36, height: 36)
            Image(systemName: "camera.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
        .shadow(color: BabyTownTheme.buttonShadow, radius: 4, y: 2)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Display name")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.5))
                .padding(.leading, 6)

            TextField("", text: $name, prompt: Text("Your name").foregroundStyle(Color.black.opacity(0.35)))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.88))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isNameFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isNameFocused
                                        ? BabyTownTheme.accent.opacity(0.55)
                                        : BabyTownTheme.accent.opacity(0.25),
                                    lineWidth: isNameFocused ? 2 : 1.5
                                )
                        )
                )

            Text("\(name.count)/\(Self.maxNameLength)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Mood")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.5))
                .padding(.leading, 6)

            Text("Pick a mood to fill the garden with its energy.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.45))
                .padding(.leading, 6)

            ProfileNoteMoodGrid(selectedMood: $selectedMood)
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .strokeBorder(BabyTownTheme.accent.opacity(0.35), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Button {
                onSave(image, trimmedName, selectedMood)
                dismiss()
            } label: {
                SavePillLabel(
                    title: "Save",
                    isEnabled: canSave,
                    font: .system(size: 16, weight: .semibold),
                    verticalPadding: 14,
                    fillsWidth: true
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
    }
}
