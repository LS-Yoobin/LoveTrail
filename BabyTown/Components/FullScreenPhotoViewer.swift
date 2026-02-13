import SwiftUI
import Photos

struct FullScreenPhotoViewer: View {

    let assets: [PHAsset]
    let initialIndex: Int
    let imageManager: PHCachingImageManager
    var selectedAssets: Set<String>
    var onToggleSelection: ((PHAsset) -> Void)?
    var onDismiss: () -> Void
    var promptText: String?

    @State private var currentIndex: Int
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var showSelectButton = true
    @State private var thumbnails: [String: UIImage] = [:]

    init(
        assets: [PHAsset],
        initialIndex: Int,
        imageManager: PHCachingImageManager,
        selectedAssets: Set<String> = [],
        onToggleSelection: ((PHAsset) -> Void)? = nil,
        onDismiss: @escaping () -> Void,
        promptText: String? = nil
    ) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.imageManager = imageManager
        self.selectedAssets = selectedAssets
        self.onToggleSelection = onToggleSelection
        self.onDismiss = onDismiss
        self.promptText = promptText
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
                HStack {
                    closeButton
                    Spacer()
                    if onToggleSelection != nil {
                        topSelectButton
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .opacity(showSelectButton ? 1 : 0)
                
                Spacer()
                
                photoPreviewStrip
                    .opacity(showSelectButton ? 1 : 0)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            loadAllThumbnails()
        }
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
    }
    
    private var topSelectButton: some View {
        Button {
            if let asset = currentAsset {
                onToggleSelection?(asset)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCurrentPhotoSelected ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                Text(isCurrentPhotoSelected ? "Selected" : "Select")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isCurrentPhotoSelected ? BabyTownTheme.accent : Color.blue)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
            )
        }
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
    
    // MARK: - Photo Preview Strip
    
    private var photoPreviewStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentIndex = index
                            }
                        } label: {
                            ZStack {
                                if let thumbnail = thumbnails[asset.localIdentifier] {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                }
                                
                                if currentIndex == index {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(BabyTownTheme.accent, lineWidth: 3)
                                        .frame(width: 60, height: 60)
                                }
                            }
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .ignoresSafeArea(edges: .bottom)
            )
            .onChange(of: currentIndex) { _, newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func loadAllThumbnails() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        
        for asset in assets {
            let id = asset.localIdentifier
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: opts
            ) { image, _ in
                guard let image else { return }
                DispatchQueue.main.async {
                    thumbnails[id] = image
                }
            }
        }
    }
    
    // MARK: - Prompt Display
    
    private func promptDisplay(prompt: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)
            
            Text(prompt)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.15))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
    }
}
