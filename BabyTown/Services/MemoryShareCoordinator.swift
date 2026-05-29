import Combine
import SwiftUI
import UIKit

@MainActor
final class MemoryShareCoordinator: ObservableObject {

    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorMessage: String?

    func share(_ payload: MemorySharePayload) {
        guard !isGenerating else { return }

        let unlocked = payload.unlockedPhotoSources
        guard !unlocked.isEmpty else {
            errorMessage = "This memory has no photos available to share."
            showError = true
            return
        }

        isGenerating = true

        Task {
            let sources = Array(unlocked.prefix(MemorySharePhotoCollage.maxPhotos))
            let images = await MemoryShareImageLoader.loadImages(for: sources)
            guard !images.isEmpty else {
                isGenerating = false
                errorMessage = "Couldn't load photos for sharing."
                showError = true
                return
            }

            guard let rendered = MemoryShareRenderer.render(payload: payload, images: images) else {
                isGenerating = false
                errorMessage = "Couldn't create the share image."
                showError = true
                return
            }

            isGenerating = false
            ActivitySharePresenter.present(image: rendered)
        }
    }
}

struct MemorySharePresentationModifier: ViewModifier {

    @ObservedObject var coordinator: MemoryShareCoordinator

    func body(content: Content) -> some View {
        content
            .overlay {
                if coordinator.isGenerating {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                            Text("Creating share image…")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                    }
                }
            }
            .alert("Couldn't Share", isPresented: $coordinator.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(coordinator.errorMessage ?? "Something went wrong.")
            }
    }
}

extension View {
    func memorySharePresentation(coordinator: MemoryShareCoordinator) -> some View {
        modifier(MemorySharePresentationModifier(coordinator: coordinator))
    }
}
