import SwiftUI
import Photos

struct FullScreenPhotoViewer: View {

    let assets: [PHAsset]
    let initialIndex: Int
    let imageManager: PHCachingImageManager
    var selectedAssets: Set<String>
    var onToggleSelection: ((PHAsset) -> Void)?
    var onSave: (() -> Void)?
    var isSaving: Bool = false
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
        onSave: (() -> Void)? = nil,
        isSaving: Bool = false,
        onDismiss: @escaping () -> Void,
        promptText: String? = nil
    ) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.imageManager = imageManager
        self.selectedAssets = selectedAssets
        self.onToggleSelection = onToggleSelection
        self.onSave = onSave
        self.isSaving = isSaving
        self.onDismiss = onDismiss
        self.promptText = promptText
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
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
            .ignoresSafeArea()

            viewerChromeOverlay
        }
        .statusBarHidden(true)
        .onAppear {
            loadAllThumbnails()
        }
    }

    // MARK: - Page

    private var isSelectionMode: Bool { onToggleSelection != nil }

    @ViewBuilder
    private func pageView(for asset: PHAsset) -> some View {
        let selected = isSelected(asset)

        ZStack {
            Group {
                if let image = loadedImages[asset.localIdentifier] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                        .scaleEffect(1.2)
                }
            }

            if isSelectionMode && selected {
                Color.black.opacity(0.25)
                    .allowsHitTesting(false)

                photoSelectionBadge
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: selected)
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection?(asset)
            } else if !showSelectButton {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSelectButton = true
                }
            }
        }
    }

    private var viewerChromeOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton
                Spacer()
                if onSave != nil {
                    topSaveButton
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)

            Spacer()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isSelectionMode, showSelectButton else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSelectButton = false
                    }
                }

            photoPreviewStrip
        }
        .opacity(isSelectionMode || showSelectButton ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showSelectButton)
        .allowsHitTesting(isSelectionMode || showSelectButton)
        .background(alignment: .top) {
            if showSelectButton || isSelectionMode {
                PhotoViewerTopScrim()
            }
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        CircleBackdropCloseButton(action: onDismiss)
    }
    
    private var topSaveButton: some View {
        Button {
            onSave?()
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BabyTownTheme.savePillFill)
                    }
                }

                Text(saveButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(BabyTownTheme.savePillFill)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
            )
        }
        .disabled(selectedAssets.isEmpty || isSaving)
        .opacity(selectedAssets.isEmpty ? 0.5 : 1)
    }

    private var saveButtonTitle: String {
        let count = selectedAssets.count
        return count > 0 ? "Save (\(count))" : "Save"
    }

    private var photoSelectionBadge: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BabyTownTheme.savePillFill)
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Selected")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(BabyTownTheme.savePillFill))
        }
    }

    private func isSelected(_ asset: PHAsset) -> Bool {
        selectedAssets.contains(asset.localIdentifier)
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
    
    @ViewBuilder
    private func previewThumbnail(for asset: PHAsset, isCurrent: Bool) -> some View {
        ZStack {
            if let thumbnail = thumbnails[asset.localIdentifier] {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.2)
            }

            if isCurrent {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(BabyTownTheme.accent, lineWidth: 3)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            previewThumbnail(for: asset, isCurrent: currentIndex == index)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 60, height: 60)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
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
            .onAppear {
                scrollPreviewStrip(to: currentIndex, proxy: proxy, animated: false)
            }
            .onChange(of: currentIndex) { _, newIndex in
                scrollPreviewStrip(to: newIndex, proxy: proxy, animated: true)
            }
        }
    }

    private func scrollPreviewStrip(to index: Int, proxy: ScrollViewProxy, animated: Bool) {
        let scroll = {
            proxy.scrollTo(index, anchor: .center)
        }
        let performScroll = {
            if animated {
                withAnimation { scroll() }
            } else {
                scroll()
            }
        }
        // Defer until layout is ready so ScrollViewReader can resolve the target id.
        DispatchQueue.main.async(execute: performScroll)
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
