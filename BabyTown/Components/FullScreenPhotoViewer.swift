import SwiftUI
import Photos

struct FullScreenPhotoViewer: View {

    let assets: [PHAsset]
    let initialIndex: Int
    let imageManager: PHCachingImageManager
    var selectedAssets: Set<String>
    var onToggleSelection: ((PHAsset) -> Void)?
    var onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var showSelectButton = true

    init(
        assets: [PHAsset],
        initialIndex: Int,
        imageManager: PHCachingImageManager,
        selectedAssets: Set<String> = [],
        onToggleSelection: ((PHAsset) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.imageManager = imageManager
        self.selectedAssets = selectedAssets
        self.onToggleSelection = onToggleSelection
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
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSelectButton.toggle()
                }
            }

            VStack {
                closeButton
                Spacer()
                if showSelectButton, onToggleSelection != nil {
                    selectButton
                }
            }
            
            if isCurrentPhotoSelected {
                heartIndicator
            }
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
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.top, 12)
        .padding(.trailing, 20)
        .opacity(showSelectButton ? 1 : 0)
    }
    
    private var selectButton: some View {
        Button {
            if let asset = currentAsset {
                onToggleSelection?(asset)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isCurrentPhotoSelected ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                Text(isCurrentPhotoSelected ? "Deselect" : "Select")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(isCurrentPhotoSelected ? BabyTownTheme.accent : Color.white.opacity(0.2))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            )
        }
        .padding(.bottom, 40)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var heartIndicator: some View {
        VStack {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(BabyTownTheme.accent)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .padding(16)
                Spacer()
            }
            Spacer()
        }
    }
    
    private var currentAsset: PHAsset? {
        guard currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }
    
    private var isCurrentPhotoSelected: Bool {
        guard let asset = currentAsset else { return false }
        return selectedAssets.contains(asset.localIdentifier)
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
