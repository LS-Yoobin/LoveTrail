import SwiftUI
import PhotosUI

struct FirstMemoriesView: View {

    @StateObject private var viewModel = FirstMemoriesViewModel()

    var onFinished: (_ firstMet: UIImage?, _ official: UIImage) -> Void

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                titleSection
                heroSection
                cardsSection
                Spacer()
                doneButton
            }
        }
        .onChange(of: viewModel.firstMetItem) { _, _ in
            Task { await viewModel.handleFirstMetSelection() }
        }
        .onChange(of: viewModel.officialItem) { _, _ in
            Task { await viewModel.handleOfficialSelection() }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [.white, Color.pink.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 6) {
            Text("Your First Memories")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(.white)

            Text("Choose the photos that mean the most")
                .font(.system(size: 14))
                .foregroundStyle(.white)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    // MARK: - Hero Preview

    private var heroSection: some View {
        HeroPhotoPreview(image: viewModel.heroImage)
            .padding(.bottom, 28)
    }

    // MARK: - Memory Cards

    private var cardsSection: some View {
        let firstMetImage = viewModel.firstMetImage
        let officialImage = viewModel.officialImage
        
        return VStack(spacing: 12) {
            PhotosPicker(
                selection: $viewModel.firstMetItem,
                matching: .images
            ) {
                MemorySelectionCard(
                    title: "When we first met",
                    subtitle: "The moment it all started",
                    image: firstMetImage,
                    isOptional: true
                )
            }
            .buttonStyle(.plain)

            PhotosPicker(
                selection: $viewModel.officialItem,
                matching: .images
            ) {
                MemorySelectionCard(
                    title: "When we became official",
                    subtitle: "The day you said yes",
                    image: officialImage
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button { [viewModel] in
            guard let official = viewModel.officialImage else { return }
            onFinished(viewModel.firstMetImage, official)
        } label: {
            Text("Done")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            viewModel.canFinish
                                ? LinearGradient(
                                    colors: [.pink, .pink.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                  )
                                : LinearGradient(
                                    colors: [
                                        Color(.systemGray4),
                                        Color(.systemGray4).opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                  )
                        )
                        .shadow(
                            color: viewModel.canFinish
                                ? .pink.opacity(0.3)
                                : .clear,
                            radius: 12, y: 6
                        )
                )
        }
        .disabled(!viewModel.canFinish)
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
        .animation(.easeInOut(duration: 0.3), value: viewModel.canFinish)
    }
}

#Preview {
    FirstMemoriesView { firstMet, official in
        print("Done — firstMet: \(firstMet != nil), official: \(official)")
    }
}
