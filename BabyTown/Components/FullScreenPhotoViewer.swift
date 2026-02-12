import SwiftUI
import Photos

struct FullScreenPhotoViewer: View {

    let assets: [PHAsset]
    let initialIndex: Int
    let imageManager: PHCachingImageManager
    var onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var loadedImages: [String: UIImage] = [:]

    init(
        assets: [PHAsset],
        initialIndex: Int,
        imageManager: PHCachingImageManager,
        onDismiss: @escaping () -> Void
    ) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.imageManager = imageManager
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(
                    Array(assets.enumerated()),
                    id: \.element.localIdentifier
                ) { index, asset in
                    pageView(for: asset)
                        .tag(index)
                        .onAppear { loadFullImage(for: asset) }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            closeButton
        }
        .statusBarHidden(true)
    }

    // MARK: - Page

    @ViewBuilder
    private func pageView(for asset: PHAsset) -> some View {
        if let image = loadedImages[asset.localIdentifier] {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .transition(.opacity)
        } else {
            ProgressView()
                .tint(.white.opacity(0.6))
                .scaleEffect(1.2)
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.top, 12)
        .padding(.trailing, 20)
    }

    // MARK: - Loading

    private func loadFullImage(for asset: PHAsset) {
        let id = asset.localIdentifier
        guard loadedImages[id] == nil else { return }

        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true

        let target = CGSize(width: 2000, height: 2000)

        imageManager.requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFit,
            options: opts
        ) { image, _ in
            guard let image else { return }
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.2)) {
                    loadedImages[id] = image
                }
            }
        }
    }
}
