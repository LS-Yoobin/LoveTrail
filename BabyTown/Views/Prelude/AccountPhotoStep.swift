import SwiftUI
import PhotosUI
import UIKit

struct AccountPhotoStep: View {
    @Binding var avatarImage: UIImage?
    var onComplete: () -> Void
    var onCancel: () -> Void

    @State private var showSourcePicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var showLibrary: Bool = false

    // Scratch binding used by pickers before committing to avatarImage
    @State private var pendingImage: UIImage?
    @State private var libraryImages: [UIImage] = []

    private var ctaLabel: String {
        avatarImage != nil ? "Looks good" : "Continue"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            BabyTownTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: cancel + progress
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Avatar circle with camera badge
                        avatarSection
                            .padding(.top, 40)

                        // Title
                        Text("Add your photo")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)
                            .padding(.horizontal, 32)

                        // Subtitle
                        Text("This will appear in your shared garden when your partner connects.")
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .padding(.horizontal, 32)

                        Spacer(minLength: 32)
                    }
                }

                // Bottom: CTA + skip
                bottomSection
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                    .padding(.top, 8)
                    .background(BabyTownTheme.background)
            }
        }
        .confirmationDialog("Choose a photo source", isPresented: $showSourcePicker, titleVisibility: .hidden) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Choose from Library") {
                showLibrary = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(image: $pendingImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            SinglePhotoLibraryPicker(selectedImage: $pendingImage)
                .ignoresSafeArea()
        }
        .onChange(of: pendingImage) { _, newImage in
            if let newImage {
                avatarImage = newImage
                pendingImage = nil
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(.systemGray6)))
            }
            .buttonStyle(.plain)

            Spacer()

            stepDots
        }
    }

    // MARK: - 2-dot step indicator (step 2 of 2)

    private var stepDots: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(BabyTownTheme.accent.opacity(0.25))
                .frame(width: 8, height: 8)
            Circle()
                .fill(BabyTownTheme.accent)
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Avatar section

    private var avatarSection: some View {
        Button(action: { showSourcePicker = true }) {
            ZStack(alignment: .bottomTrailing) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(BabyTownTheme.accentGradient)
                        .frame(width: 120, height: 120)

                    if let image = avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                // Camera badge
                ZStack {
                    Circle()
                        .fill(BabyTownTheme.background)
                        .frame(width: 36, height: 36)

                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 32, height: 32)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
                .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: avatarImage != nil)
    }

    // MARK: - Bottom section

    private var bottomSection: some View {
        VStack(spacing: 14) {
            continueButton

            Button {
                avatarImage = nil
                onComplete()
            } label: {
                Text("Skip for now")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            onComplete()
        } label: {
            Text(ctaLabel)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background {
                    Capsule()
                        .fill(BabyTownTheme.accentGradient)
                        .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 12, y: 5)
                }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: ctaLabel)
    }
}

// MARK: - Single-image library picker

/// Wraps PHPickerViewController for selecting a single photo from the library.
private struct SinglePhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
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
        let parent: SinglePhotoLibraryPicker

        init(_ parent: SinglePhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let result = results.first else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var avatar: UIImage? = nil
    AccountPhotoStep(
        avatarImage: $avatar,
        onComplete: { print("complete, has photo: \(avatar != nil)") },
        onCancel: { print("cancel") }
    )
}
