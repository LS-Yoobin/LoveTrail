import SwiftUI

/// Entry point for the "Adopt a Pet" feature. Shows the cat selection screen
/// until a cat is adopted, then the living-room scene.
struct AdoptAPetRootView: View {
    @StateObject private var viewModel = PetViewModel()
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            if let skin = viewModel.adoptedSkin {
                PetRoomView(
                    skin: skin,
                    viewModel: viewModel,
                    onChangePet: { viewModel.releasePet() },
                    onDismiss: onDismiss
                )
                .transition(.opacity)
                .zIndex(1)
            } else {
                CatSelectionView(
                    viewModel: viewModel,
                    onDismiss: dismissCatSelection
                ) { skin in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.visit(skin)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.adoptedSkin)
    }

    private func dismissCatSelection() {
        if viewModel.canCancelPetSelection {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.cancelPetSelection()
            }
        } else {
            onDismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AdoptAPetRootView(onDismiss: {})
    }
}
