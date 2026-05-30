import SwiftUI

/// Entry point for the "Adopt a Pet" feature. Shows the cat selection screen
/// until a cat is adopted, then the living-room scene.
struct AdoptAPetRootView: View {
    @StateObject private var viewModel = PetViewModel()

    var body: some View {
        Group {
            if let skin = viewModel.adoptedSkin {
                PetRoomView(skin: skin, viewModel: viewModel, onChangePet: { viewModel.releasePet() })
            } else {
                CatSelectionView { skin in
                    withAnimation(.easeInOut) { viewModel.adopt(skin) }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdoptAPetRootView()
    }
}
